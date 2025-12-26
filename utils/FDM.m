%% FDM光谱测量系统 - 模块化函数库
% 包含时域信号生成、FFT解调、数据读取等核心功能
% 作者: Claude
% 日期: 2024-12
%
% 函数列表:
%   fdm_generate_signal     - 生成FDM时域信号
%   fdm_demodulate          - FFT解调提取各频率幅度
%   fdm_read_csv            - 读取示波器CSV数据
%   fdm_build_system_matrix - 构建系统矩阵A
%   fdm_compute_theory      - 计算理论响应
%   fdm_normalize           - 归一化函数
%   fdm_compare             - 对比分析并可视化

classdef FDM
    properties (Constant)
        % 默认系统参数
        DEFAULT_FREQS_KHZ = [118, 128, 138, 148, 158, 168, 178, 188, 198, 208, 218, 228];
        DEFAULT_WORKING_LEDS = [1, 2, 3, 4, 5, 6, 7, 10, 11, 12];  % 跳过LED8,9
        DEFAULT_FS = 10e6;      % 10MHz采样率
        DEFAULT_N = 1200;       % 采样点数
        DEFAULT_SNR_DB = 40;    % 信噪比
        WAVELENGTHS = linspace(400, 700, 31);
    end
    
    methods (Static)
        %% ==================== 生成FDM时域信号 ====================
        function [v_signal, t, params] = generate_signal(amplitudes, varargin)
            % FDM.generate_signal - 生成FDM调制的时域信号
            %
            % 语法:
            %   [v_signal, t] = FDM.generate_signal(amplitudes)
            %   [v_signal, t, params] = FDM.generate_signal(amplitudes, 'Name', Value, ...)
            %
            % 输入:
            %   amplitudes  - 各LED幅度 [N_led x 1] 或 [1 x N_led]
            %
            % 可选参数 (Name-Value pairs):
            %   'Fs'        - 采样率 (默认: 10MHz)
            %   'N'         - 采样点数 (默认: 1200)
            %   'FreqsHz'   - 各LED调制频率Hz (默认: 118k~228kHz)
            %   'DC'        - 直流偏置 (默认: 0)
            %   'Phases'    - 各LED相位 (默认: 随机)
            %   'SNR_dB'    - 信噪比dB (默认: Inf, 无噪声)
            %   'Seed'      - 随机种子 (默认: 无)
            %
            % 输出:
            %   v_signal    - 时域电压信号 [1 x N]
            %   t           - 时间轴 [1 x N]
            %   params      - 使用的参数结构体
            %
            % 示例:
            %   amps = [0.1, 0.2, 0.15, 0.08];
            %   freqs = [118, 128, 138, 148] * 1000;
            %   [v, t] = FDM.generate_signal(amps, 'FreqsHz', freqs, 'DC', 2.5, 'SNR_dB', 40);
            
            % 解析输入参数
            p = inputParser;
            addRequired(p, 'amplitudes', @isnumeric);
            addParameter(p, 'Fs', FDM.DEFAULT_FS, @isnumeric);
            addParameter(p, 'N', FDM.DEFAULT_N, @isnumeric);
            addParameter(p, 'FreqsHz', FDM.DEFAULT_FREQS_KHZ(FDM.DEFAULT_WORKING_LEDS) * 1000, @isnumeric);
            addParameter(p, 'DC', 0, @isnumeric);
            addParameter(p, 'Phases', [], @isnumeric);
            addParameter(p, 'SNR_dB', Inf, @isnumeric);
            addParameter(p, 'Seed', [], @isnumeric);
            parse(p, amplitudes, varargin{:});
            
            opts = p.Results;
            amplitudes = opts.amplitudes(:)';  % 确保是行向量
            num_led = length(amplitudes);
            
            % 验证频率数量
            if length(opts.FreqsHz) ~= num_led
                error('FreqsHz长度(%d)必须与amplitudes长度(%d)一致', ...
                    length(opts.FreqsHz), num_led);
            end
            
            % 设置随机种子
            if ~isempty(opts.Seed)
                rng(opts.Seed);
            end
            
            % 生成相位
            if isempty(opts.Phases)
                phases = 2 * pi * rand(1, num_led);
            else
                phases = opts.Phases(:)';
            end
            
            % 时间轴
            dt = 1 / opts.Fs;
            t = (0:opts.N-1) * dt;
            
            % 生成信号: v(t) = DC + Σ a_i * sin(2πf_i*t + φ_i)
            v_signal = opts.DC * ones(1, opts.N);
            for i = 1:num_led
                v_signal = v_signal + amplitudes(i) * sin(2*pi*opts.FreqsHz(i)*t + phases(i));
            end
            
            % 添加噪声
            if ~isinf(opts.SNR_dB)
                signal_power = var(v_signal - opts.DC);
                noise_power = signal_power / (10^(opts.SNR_dB/10));
                noise = sqrt(noise_power) * randn(1, opts.N);
                v_signal = v_signal + noise;
            end
            
            % 返回参数
            params.Fs = opts.Fs;
            params.N = opts.N;
            params.dt = dt;
            params.FreqsHz = opts.FreqsHz;
            params.DC = opts.DC;
            params.Phases = phases;
            params.SNR_dB = opts.SNR_dB;
            params.amplitudes = amplitudes;
        end
        
        %% ==================== FFT解调 ====================
        function [amplitudes, f, P, df] = demodulate(voltage, varargin)
            % FDM.demodulate - FFT解调提取各频率分量幅度
            %
            % 语法:
            %   amplitudes = FDM.demodulate(voltage, target_freqs_Hz)
            %   [amplitudes, f, P, df] = FDM.demodulate(voltage, target_freqs_Hz, 'Fs', Fs)
            %
            % 输入:
            %   voltage         - 时域电压信号 [N x 1] 或 [1 x N]
            %   target_freqs_Hz - 目标频率数组 (Hz)
            %
            % 可选参数:
            %   'Fs'            - 采样率 (默认: 10MHz)
            %
            % 输出:
            %   amplitudes      - 各频率幅度
            %   f               - 频率轴
            %   P               - 幅度谱
            %   df              - 频率分辨率
            %
            % 示例:
            %   freqs = [118, 128, 138] * 1000;
            %   amps = FDM.demodulate(voltage, freqs, 'Fs', 10e6);
            
            p = inputParser;
            addRequired(p, 'voltage', @isnumeric);
            addOptional(p, 'target_freqs_Hz', FDM.DEFAULT_FREQS_KHZ(FDM.DEFAULT_WORKING_LEDS) * 1000, @isnumeric);
            addParameter(p, 'Fs', FDM.DEFAULT_FS, @isnumeric);
            parse(p, voltage, varargin{:});
            
            voltage = p.Results.voltage(:);  % 列向量
            target_freqs = p.Results.target_freqs_Hz(:);
            Fs = p.Results.Fs;
            N = length(voltage);
            df = Fs / N;
            
            % 去直流 + FFT
            voltage_ac = voltage - mean(voltage);
            Y = fft(voltage_ac);
            P = 2 * abs(Y(1:floor(N/2)+1)) / N;
            f = Fs * (0:floor(N/2))' / N;
            
            % 提取目标频率幅度
            amplitudes = zeros(length(target_freqs), 1);
            for i = 1:length(target_freqs)
                [~, idx] = min(abs(f - target_freqs(i)));
                amplitudes(i) = P(idx);
            end
        end
        
        %% ==================== 读取示波器CSV ====================
        function [amplitudes, voltage, Fs, f, P] = read_csv(csv_file, varargin)
            % FDM.read_csv - 读取示波器CSV文件并解调
            %
            % 语法:
            %   [amplitudes, voltage, Fs] = FDM.read_csv(csv_file)
            %   [amplitudes, voltage, Fs, f, P] = FDM.read_csv(csv_file, target_freqs_kHz)
            %
            % 输入:
            %   csv_file        - CSV文件路径
            %   target_freqs_kHz- 目标频率数组 (kHz), 默认12个LED频率
            %
            % 输出:
            %   amplitudes      - 各频率幅度
            %   voltage         - 原始电压数据
            %   Fs              - 采样率
            %   f               - 频率轴
            %   P               - 幅度谱
            
            p = inputParser;
            addRequired(p, 'csv_file', @ischar);
            addOptional(p, 'target_freqs_kHz', FDM.DEFAULT_FREQS_KHZ, @isnumeric);
            parse(p, csv_file, varargin{:});
            
            target_freqs_kHz = p.Results.target_freqs_kHz;
            
            % 读取采样参数
            fid = fopen(csv_file, 'r');
            if fid == -1
                error('无法打开文件: %s', csv_file);
            end
            fgetl(fid);  % 跳过第一行
            line2 = fgetl(fid);
            fclose(fid);
            
            parts = strsplit(line2, ',');
            dt = str2double(parts{4});
            Fs = 1 / dt;
            
            % 读取电压数据
            data = readmatrix(csv_file, 'NumHeaderLines', 2);
            voltage = data(:, 2);
            voltage = voltage(~isnan(voltage));
            
            % 解调
            target_freqs_Hz = target_freqs_kHz * 1000;
            [amplitudes, f, P, ~] = FDM.demodulate(voltage, target_freqs_Hz, 'Fs', Fs);
        end
        
        %% ==================== 构建系统矩阵 ====================
        function A = build_system_matrix(A0, y_white, working_leds)
            % FDM.build_system_matrix - 构建系统矩阵 A = diag(y_white) * A0_working
            %
            % 语法:
            %   A = FDM.build_system_matrix(A0, y_white)
            %   A = FDM.build_system_matrix(A0, y_white, working_leds)
            %
            % 输入:
            %   A0           - LED光谱矩阵 [12 x 31] 或 [31 x 12]
            %   y_white      - 白板响应 [N_led x 1]
            %   working_leds - 工作LED索引 (默认: 跳过8,9)
            %
            % 输出:
            %   A            - 系统矩阵 [N_led x 31]
            
            if nargin < 3
                working_leds = FDM.DEFAULT_WORKING_LEDS;
            end
            
            % 确保A0是[12 x 31]
            if size(A0, 1) == 31 && size(A0, 2) == 12
                A0 = A0';
            end
            
            % 提取工作LED
            A0_working = A0(working_leds, :);
            y_white = y_white(:);
            
            % 构建系统矩阵
            A = diag(y_white) * A0_working;
        end
        
        %% ==================== 计算理论响应 ====================
        function y_theory = compute_theory(A, x_spectrum)
            % FDM.compute_theory - 计算理论测量响应 y = A * x
            %
            % 输入:
            %   A          - 系统矩阵 [N_led x 31]
            %   x_spectrum - 目标光谱 [31 x 1]
            %
            % 输出:
            %   y_theory   - 理论响应 [N_led x 1]
            
            x_spectrum = x_spectrum(:);
            y_theory = A * x_spectrum;
        end
        
        %% ==================== 加载光谱数据 ====================
        function [A0, colorchecker] = load_spectra(led_file, cc_file, varargin)
            % FDM.load_spectra - 加载LED光谱和色卡数据
            %
            % 语法:
            %   [A0, colorchecker] = FDM.load_spectra(led_file, cc_file)
            %   [A0, colorchecker] = FDM.load_spectra(led_file, cc_file, 'LoadFunc', @load_mat)
            %
            % 输入:
            %   led_file    - LED光谱文件名
            %   cc_file     - 色卡文件名
            %   'LoadFunc'  - 加载函数句柄 (默认: @(f) load_mat(f, "gt"))
            %
            % 输出:
            %   A0          - LED光谱矩阵 [12 x 31]
            %   colorchecker- 色卡光谱 [24 x 31]
            
            p = inputParser;
            addRequired(p, 'led_file');
            addRequired(p, 'cc_file');
            addParameter(p, 'LoadFunc', @(f) load_mat(f, "gt"), @(x) isa(x, 'function_handle'));
            parse(p, led_file, cc_file, varargin{:});
            
            load_func = p.Results.LoadFunc;
            
            % 加载数据
            A0_raw = load_func(led_file);
            cc_raw = load_func(cc_file);
            
            % 确保维度正确
            if size(A0_raw, 1) == 31 && size(A0_raw, 2) == 12
                A0 = A0_raw';
            else
                A0 = A0_raw;
            end
            
            if size(cc_raw, 1) == 31 && size(cc_raw, 2) == 24
                colorchecker = cc_raw';
            else
                colorchecker = cc_raw;
            end
        end
        
        %% ==================== 归一化 ====================
        function y_norm = normalize(y, method)
            % FDM.normalize - 归一化函数
            %
            % 语法:
            %   y_norm = FDM.normalize(y)           % L1归一化
            %   y_norm = FDM.normalize(y, 'L2')     % L2归一化
            %   y_norm = FDM.normalize(y, 'max')    % 最大值归一化
            %
            % 输入:
            %   y      - 输入向量
            %   method - 'L1', 'L2', 或 'max' (默认: 'L1')
            
            if nargin < 2
                method = 'L1';
            end
            
            y = y(:);
            switch upper(method)
                case 'L1'
                    y_norm = y / sum(abs(y));
                case 'L2'
                    y_norm = y / norm(y);
                case 'MAX'
                    y_norm = y / max(abs(y));
                otherwise
                    error('未知归一化方法: %s', method);
            end
        end
        
        %% ==================== 完整仿真流程 ====================
        function [results] = simulate(A0, colorchecker, y_white, varargin)
            % FDM.simulate - 完整仿真流程
            %
            % 语法:
            %   results = FDM.simulate(A0, colorchecker, y_white)
            %   results = FDM.simulate(A0, colorchecker, y_white, 'ColorIdx', 16, 'SNR_dB', 40)
            %
            % 输入:
            %   A0          - LED光谱矩阵
            %   colorchecker- 色卡光谱
            %   y_white     - 白板响应
            %
            % 可选参数:
            %   'ColorIdx'  - 色卡索引 (默认: 16)
            %   'WorkingLEDs' - 工作LED (默认: 跳过8,9)
            %   'SNR_dB'    - 信噪比 (默认: 40)
            %   'DC'        - 直流偏置 (默认: 2.5)
            %   'Seed'      - 随机种子 (默认: 42)
            %
            % 输出:
            %   results     - 结构体包含所有结果
            
            p = inputParser;
            addRequired(p, 'A0');
            addRequired(p, 'colorchecker');
            addRequired(p, 'y_white');
            addParameter(p, 'ColorIdx', 16, @isnumeric);
            addParameter(p, 'WorkingLEDs', FDM.DEFAULT_WORKING_LEDS, @isnumeric);
            addParameter(p, 'SNR_dB', 40, @isnumeric);
            addParameter(p, 'DC', 2.5, @isnumeric);
            addParameter(p, 'Seed', 42, @isnumeric);
            addParameter(p, 'Fs', FDM.DEFAULT_FS, @isnumeric);
            addParameter(p, 'N', FDM.DEFAULT_N, @isnumeric);
            parse(p, A0, colorchecker, y_white, varargin{:});
            
            opts = p.Results;
            working_leds = opts.WorkingLEDs;
            
            % 确保A0维度正确
            if size(A0, 1) == 31 && size(A0, 2) == 12
                A0 = A0';
            end
            if size(colorchecker, 1) == 31 && size(colorchecker, 2) == 24
                colorchecker = colorchecker';
            end
            
            % 获取目标光谱
            x_gt = colorchecker(opts.ColorIdx, :)';
            
            % 构建系统矩阵
            A = FDM.build_system_matrix(A0, y_white, working_leds);
            
            % 计算理论响应
            y_theory = FDM.compute_theory(A, x_gt);
            
            % 获取工作频率
            freqs_Hz = FDM.DEFAULT_FREQS_KHZ(working_leds) * 1000;
            
            % 生成仿真信号
            [v_sim, t, sig_params] = FDM.generate_signal(y_theory, ...
                'FreqsHz', freqs_Hz, ...
                'DC', opts.DC, ...
                'SNR_dB', opts.SNR_dB, ...
                'Seed', opts.Seed, ...
                'Fs', opts.Fs, ...
                'N', opts.N);
            
            % 解调仿真信号
            y_sim_demod = FDM.demodulate(v_sim, freqs_Hz, 'Fs', opts.Fs);
            
            % 打包结果
            results.A = A;
            results.x_gt = x_gt;
            results.y_theory = y_theory;
            results.y_sim_demod = y_sim_demod;
            results.v_sim = v_sim;
            results.t = t;
            results.freqs_Hz = freqs_Hz;
            results.freqs_kHz = FDM.DEFAULT_FREQS_KHZ(working_leds);
            results.working_leds = working_leds;
            results.params = sig_params;
            results.color_idx = opts.ColorIdx;
            
            % 计算相关系数
            corr_mat = corrcoef(y_theory, y_sim_demod);
            results.correlation = corr_mat(1, 2);
        end
        
        %% ==================== 对比分析与可视化 ====================
        function compare(y_theory, y_measured, varargin)
            % FDM.compare - 对比理论值和实测值并可视化
            %
            % 语法:
            %   FDM.compare(y_theory, y_measured)
            %   FDM.compare(y_theory, y_measured, 'FreqsKHz', freqs, 'Plot', true)
            %
            % 输入:
            %   y_theory    - 理论响应
            %   y_measured  - 实测响应
            %
            % 可选参数:
            %   'FreqsKHz'  - 频率标签
            %   'Plot'      - 是否绘图 (默认: true)
            %   'Title'     - 图标题
            
            p = inputParser;
            addRequired(p, 'y_theory');
            addRequired(p, 'y_measured');
            addParameter(p, 'FreqsKHz', FDM.DEFAULT_FREQS_KHZ(FDM.DEFAULT_WORKING_LEDS), @isnumeric);
            addParameter(p, 'Plot', true, @islogical);
            addParameter(p, 'Title', 'Theory vs Measured Comparison', @ischar);
            parse(p, y_theory, y_measured, varargin{:});
            
            opts = p.Results;
            y_theory = y_theory(:);
            y_measured = y_measured(:);
            freqs = opts.FreqsKHz(:);
            
            % 归一化
            y_th_norm = FDM.normalize(y_theory);
            y_ms_norm = FDM.normalize(y_measured);
            
            % 计算指标
            corr_mat = corrcoef(y_theory, y_measured);
            correlation = corr_mat(1, 2);
            rmse = sqrt(mean((y_th_norm - y_ms_norm).^2));
            
            % 打印结果
            fprintf('\n%s\n', repmat('=', 1, 50));
            fprintf('对比分析结果\n');
            fprintf('%s\n', repmat('=', 1, 50));
            fprintf('LED    Freq     理论      实测      误差\n');
            fprintf('%s\n', repmat('-', 1, 50));
            for i = 1:length(y_theory)
                err = 100 * abs(y_th_norm(i) - y_ms_norm(i)) / y_th_norm(i);
                fprintf('%2d   %3dkHz   %.4f    %.4f    %6.1f%%\n', ...
                    i, freqs(i), y_th_norm(i), y_ms_norm(i), err);
            end
            fprintf('%s\n', repmat('-', 1, 50));
            fprintf('相关系数: %.6f\n', correlation);
            fprintf('RMSE: %.4f\n', rmse);
            
            % 可视化
            if opts.Plot
                figure('Position', [100, 100, 1200, 400], 'Color', 'w');
                
                % 柱状图
                subplot(1, 3, 1);
                bar_data = [y_th_norm, y_ms_norm];
                bar(bar_data);
                set(gca, 'XTickLabel', arrayfun(@num2str, freqs, 'UniformOutput', false));
                xlabel('Frequency (kHz)');
                ylabel('Normalized Amplitude');
                title('Bar Comparison');
                legend('Theory', 'Measured');
                grid on;
                
                % 曲线图
                subplot(1, 3, 2);
                plot(freqs, y_th_norm, 'go-', 'LineWidth', 2, 'MarkerSize', 8); hold on;
                plot(freqs, y_ms_norm, 'bs-', 'LineWidth', 2, 'MarkerSize', 8);
                xlabel('Frequency (kHz)');
                ylabel('Normalized Amplitude');
                title('Curve Comparison');
                legend('Theory', 'Measured');
                grid on;
                
                % 散点图
                subplot(1, 3, 3);
                scatter(y_th_norm, y_ms_norm, 100, 'b', 'filled'); hold on;
                max_val = max([y_th_norm; y_ms_norm]) * 1.1;
                plot([0, max_val], [0, max_val], 'k--', 'LineWidth', 1);
                xlabel('Theory');
                ylabel('Measured');
                title(sprintf('Correlation: r=%.4f', correlation));
                axis equal;
                grid on;
                
                sgtitle(opts.Title);
            end
        end
    end
end
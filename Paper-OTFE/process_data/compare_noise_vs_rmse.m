clear; 
clc;
%% 
A0 = load_mat("led_pd_0118", "gt")';
colorchecker = load_mat("colorchecker_trans_0118", "gt");
idx = 15;
x = colorchecker(:, idx);
%% 
path = "./data/PD-01-18/I/";
duration = 100e-5;
duration_ref = 100e-5;
k_A = read_rigol_wfm(path+"新建文件-1.wfm", 1e9, duration_ref);
A = k_A .* A0;
% 10~14强白光（1v量程）
% 15无噪声（1v量程）
% 16~42都是白光（1V量程）
% 43開始是手電
file_idx = 1;
y_measured = read_rigol_wfm(path+"新建文件"+num2str(file_idx)+".wfm", 1e9, duration);
y_theory = A * x;
%% 
% vpp 4.32v为极限最优
% 41的vpp是4.28v,42vpp是4.04v
% 以下為手電
% 46的vpp是4.64v
% 2+46是3.96v,3+46是4.96v,4是4.88v
% 5是6.24v（nice），6是6.48v,7是純净無噪聲（2V量程）
% 8是9.52v，9是7.2v，10是5.76v，11是5.24v(1v量程)
% 12是6.52v,13是3.4v，14是5.12v,15是4.52v
% 16是4.64v，17是3.36v，18是4.04v
fft_data = plot_rigol_fft(path+"新建文件"+num2str(file_idx)+".wfm", 1e9, duration);
n_points = size(fft_data, 1);
noise_mask = false(n_points, 1);
noise_mask(2:390) = true;
fft_mag = fft_data(:, 2);
noise_mag = fft_mag(noise_mask);
noise_mag_sum = sum(noise_mag);
sig_mag_sum = sum(y_measured);
noise_to_signal_ratio = noise_mag_sum / sig_mag_sum;
disp(noise_to_signal_ratio);
%% 
figure(1);
plot(y_measured);
hold on;
plot(y_theory);
legend('测量值','理论值');
hold off; 
rel_error = abs(y_measured - y_theory) ./ abs(y_theory);
mean_rel_error = mean(rel_error) * 100;
fprintf('平均相对误差为: %.2f%%\n', mean_rel_error);
%% 
figure(2);
clf;
k_beta = 1;
y = y_measured * k_beta;
x_est = fdm_reconstruct(y ./ k_A, A0, 'Method', 'tv');
wav = 400:10:700;
rmse = RMSE(x_est, x);
psnr = PSNR(rmse);
rgb_est = spec2rgb_simple(x_est);
rgb_gt = spec2rgb_simple(x);

% 确保rgb是1x3行向量
rgb_est = reshape(rgb_est, 1, 3);
rgb_gt = reshape(rgb_gt, 1, 3);

fprintf('PSNR为: %.1f dB\n', psnr);

% 绘制光谱曲线
plot(wav, x_est, 'LineWidth', 1.5);
hold on;
plot(wav, x, 'LineWidth', 1.5);
legend('预测', '真实', 'Location', 'southwest');
xlabel('波长 (nm)');
ylabel('反射率');
title(sprintf('光谱重建 (PSNR=%.1f dB)', psnr));
ylim([0, 1]);
xlim([400, 700]);
grid on;

% 用fill在数据坐标系内画色块（右上角区域）
block_w = 30;
block_h = 0.15;
x_start = 680;
y_start = 0.98;

% 预测颜色（右边）
fill([x_start-block_w, x_start, x_start, x_start-block_w], ...
     [y_start-block_h, y_start-block_h, y_start, y_start], ...
     rgb_est, 'EdgeColor', 'k', 'LineWidth', 1);
text(x_start - block_w/2, y_start - block_h - 0.03, '预测', ...
     'HorizontalAlignment', 'center', 'FontSize', 9);

% 真实颜色（左边）
x_start2 = x_start - block_w - 5;
fill([x_start2-block_w, x_start2, x_start2, x_start2-block_w], ...
     [y_start-block_h, y_start-block_h, y_start, y_start], ...
     rgb_gt, 'EdgeColor', 'k', 'LineWidth', 1);
text(x_start2 - block_w/2, y_start - block_h - 0.03, '真实', ...
     'HorizontalAlignment', 'center', 'FontSize', 9);

hold off;

%% 

%% 
%% ================== 读取函数（修正校正方向） ==================
function [amps, freq_detected, volt_div, v_min, v_max] = read_rigol_wfm(filename, fs, duration, options)
% READ_RIGOL_WFM 读取Rigol示波器wfm文件并提取LED调制幅值
%
% 语法:
%   amps = read_rigol_wfm(filename)
%   amps = read_rigol_wfm(filename, fs)
%   amps = read_rigol_wfm(filename, fs, duration)
%   amps = read_rigol_wfm(filename, fs, duration, Name=Value)
%   [amps, freq_detected, volt_div, v_min, v_max] = read_rigol_wfm(...)
%
% 输入参数:
%   filename - wfm文件路径
%   fs       - 采样率 (默认: 1e9 Hz)
%   duration - 截取时长 (默认: inf，全部数据)
%
% 名称-值参数:
%   LEDFreqs   - LED频率数组，单位kHz (默认: [380:10:490])
%   NSidelobe  - 旁瓣数量，主瓣两侧各N个 (默认: 1)
%   Method     - 幅值估计方法 (默认: 'rss')
%                'peak'     - 仅主瓣峰值
%                'sum'      - 基于幅值选择旁瓣 + 直接求和
%                'rss'      - 基于幅值选择旁瓣 + RSS (推荐)
%                'weighted' - 基于幅值选择旁瓣 + sinc加权求和
%
% 旁瓣选择策略:
%   基于幅值相近原则，从主瓣出发交替向左右扩展，
%   优先选择幅值更接近主瓣的相邻频点，避免选到远处噪声。
%
% 输出参数:
%   amps         - 各LED的幅值估计 [n_leds x 1]
%   freq_detected - 检测到的实际频率 [n_leds x 1]
%   volt_div     - 示波器V/div设置
%   v_min, v_max - 信号电压范围
%
% 示例:
%   % 使用默认参数（基于幅值RSS方法，1个旁瓣）
%   amps = read_rigol_wfm("test.wfm", 1e9, 100e-5);
%
%   % 自定义LED频率和旁瓣数
%   amps = read_rigol_wfm("test.wfm", 1e9, 100e-5, ...
%       LEDFreqs=[30,50,70,110,130,170,190,230,290,310,370,410], ...
%       NSidelobe=2);
%
% 基于实验测试（46个文件），基于幅值选择旁瓣 + RSS方法 + 旁瓣数1 为最优:
%   平均PSNR: 24.15 dB, 平均RMSE: 0.0770

    arguments
        filename string
        fs double = 1e9
        duration double = inf
        options.LEDFreqs (1,:) double = [380, 390, 400, 410, 420, 430, 440, 450, 460, 470, 480, 490]
        options.NSidelobe (1,1) double {mustBeNonnegative, mustBeInteger} = 1
        options.Method string {mustBeMember(options.Method, {'peak', 'sum', 'rss', 'weighted'})} = 'rss'
    end

    led_freqs = options.LEDFreqs;
    n_sidelobe = options.NSidelobe;
    method = options.Method;
    n_leds = length(led_freqs);

    % ==================== 读取文件头 ====================
    fid = fopen(filename, 'rb');
    if fid == -1
        error('无法打开文件: %s', filename);
    end
    
    try
        % 读取V/div (0x84)
        fseek(fid, hex2dec('84'), 'bof');
        volt_div = fread(fid, 1, 'float32');
        
        % 读取电压刻度因子 (0xA0)
        fseek(fid, hex2dec('A0'), 'bof');
        volt_scale = fread(fid, 1, 'float32');
        
        % 读取电压偏移 (0xA4)
        volt_offset = fread(fid, 1, 'float32');

        % 读取波形数据 (从3334字节开始)
        fseek(fid, 3334, 'bof');
        raw_data = fread(fid, inf, 'uint8');
    catch ME
        fclose(fid);
        rethrow(ME);
    end
    fclose(fid);

    % ==================== 数据预处理 ====================
    % 转换为电压
    signal = (double(raw_data) - 128) * volt_scale + volt_offset;
    
    % 截取指定时长
    if isfinite(duration)
        n_use = min(round(duration * fs), length(signal));
        signal = signal(1:n_use);
    end

    % 输出电压范围
    v_min = min(signal);
    v_max = max(signal);

    % ==================== FFT分析 ====================
    signal_ac = signal - mean(signal);
    n_fft = 2^nextpow2(length(signal_ac));
    fft_result = fft(signal_ac, n_fft);
    fft_mag = abs(fft_result(1:n_fft/2));
    freq_axis = (0:n_fft/2-1) * fs / n_fft / 1e3;  % kHz
    freq_resolution = fs / n_fft / 1e3;

    % ==================== 提取各LED幅值 ====================
    amps = zeros(n_leds, 1);
    freq_detected = zeros(n_leds, 1);
    search_width = max(5, freq_resolution * 2);  % 搜索窗口宽度

    for i = 1:n_leds
        f_target = led_freqs(i);
        
        % 在目标频率附近搜索主瓣峰值
        mask = (freq_axis >= f_target - search_width) & ...
               (freq_axis <= f_target + search_width);
        mask_indices = find(mask);
        
        if isempty(mask_indices)
            warning('未找到频率 %.1f kHz 附近的信号', f_target);
            continue;
        end
        
        [peak_val, rel_idx] = max(fft_mag(mask_indices));
        peak_idx = mask_indices(rel_idx);
        freq_detected(i) = freq_axis(peak_idx);
        
        % 根据方法计算幅值（使用基于幅值的旁瓣选择）
        switch lower(method)
            case 'peak'
                % 仅主瓣峰值
                amps(i) = fft_mag(peak_idx);
                
            case 'sum'
                % 基于幅值选择旁瓣 + 直接求和
                idx_range = get_amplitude_based_indices(fft_mag, peak_idx, peak_val, n_sidelobe);
                amps(i) = sum(fft_mag(idx_range));
                
            case 'rss'
                % 基于幅值选择旁瓣 + RSS (推荐)
                idx_range = get_amplitude_based_indices(fft_mag, peak_idx, peak_val, n_sidelobe);
                amps(i) = sqrt(sum(fft_mag(idx_range).^2));
                
            case 'weighted'
                % 基于幅值选择旁瓣 + sinc加权求和
                idx_range = get_amplitude_based_indices(fft_mag, peak_idx, peak_val, n_sidelobe);
                weights = get_sinc_weights(length(idx_range));
                amps(i) = sum(fft_mag(idx_range) .* weights(:));
        end
    end

    % 乘以V/div得到绝对强度
    amps = amps * volt_div;
end

%% ==================== 辅助函数 ====================
function idx_range = get_amplitude_based_indices(fft_mag, peak_idx, peak_val, n_sidelobe)
% 基于幅值相近原则选择旁瓣
% 从主瓣出发，交替向左右扩展，优先选择幅值更接近主瓣的相邻频点

    if n_sidelobe == 0
        idx_range = peak_idx;
        return;
    end
    
    max_len = length(fft_mag);
    selected = peak_idx;
    left_ptr = peak_idx - 1;
    right_ptr = peak_idx + 1;
    
    for k = 1:n_sidelobe
        left_valid = left_ptr >= 1;
        right_valid = right_ptr <= max_len;
        
        if ~left_valid && ~right_valid
            break;
        elseif ~left_valid
            selected = [selected, right_ptr];
            right_ptr = right_ptr + 1;
        elseif ~right_valid
            selected = [selected, left_ptr];
            left_ptr = left_ptr - 1;
        else
            % 比较幅值与主瓣的接近程度
            left_diff = abs(fft_mag(left_ptr) - peak_val);
            right_diff = abs(fft_mag(right_ptr) - peak_val);
            
            if left_diff <= right_diff
                selected = [selected, left_ptr];
                left_ptr = left_ptr - 1;
            else
                selected = [selected, right_ptr];
                right_ptr = right_ptr + 1;
            end
        end
    end
    
    idx_range = sort(selected);
end

function weights = get_sinc_weights(n_total)
% 生成sinc函数旁瓣权重
    weights = zeros(1, n_total);
    center = ceil(n_total / 2);
    for k = 1:n_total
        offset = k - center;
        if offset == 0
            weights(k) = 1;
        else
            weights(k) = abs(sinc(offset));
        end
    end
end


function fft_data = plot_rigol_fft(filename, fs, duration, freq_max, do_plot)
% PLOT_RIGOL_FFT 读取Rigol示波器wfm文件并绘制FFT频谱图
%
% 输入参数:
%   filename - wfm文件路径
%   fs       - 采样率 (默认 1e9 Hz)
%   duration - 截取时长 (默认 inf，即全部数据)
%   freq_max - 频谱显示的最大频率，单位kHz (默认 500 kHz)
%   do_plot  - 是否绘图 (默认 false)
%
% 输出参数:
%   fft_data - Nx2矩阵，第一列是频率(kHz)，第二列是幅值
%
% 示例:
%   data = plot_rigol_fft("./data/test.wfm", 1e9, 100e-5, 500);       % 不绘图
%   data = plot_rigol_fft("./data/test.wfm", 1e9, 100e-5, 500, true); % 绘图
%   freq = data(:,1);  % 频率
%   mag = data(:,2);   % 幅值

    if nargin < 2 || isempty(fs), fs = 1e9; end
    if nargin < 3 || isempty(duration), duration = inf; end
    if nargin < 4 || isempty(freq_max), freq_max = 500; end
    if nargin < 5 || isempty(do_plot), do_plot = false; end

    % 打开文件
    fid = fopen(filename, 'rb');
    if fid == -1, error('无法打开文件: %s', filename); end

    % 读取真实V/div (0x84)
    fseek(fid, hex2dec('84'), 'bof');
    volt_div = fread(fid, 1, 'float32');
    
    % 读取电压刻度因子 (0xA0)
    fseek(fid, hex2dec('A0'), 'bof');
    volt_scale = fread(fid, 1, 'float32');
    
    % 读取电压偏移 (0xA4)
    volt_offset = fread(fid, 1, 'float32');

    % 读取数据
    fseek(fid, 3334, 'bof');
    raw_data = fread(fid, inf, 'uint8');
    fclose(fid);

    % 转换为电压
    signal = (double(raw_data) - 128) * volt_scale + volt_offset;
    
    % 截取指定时长
    if isfinite(duration)
        n_use = min(round(duration * fs), length(signal));
        signal = signal(1:n_use);
    end

    % FFT
    signal_ac = signal - mean(signal);
    n_fft = 2^nextpow2(length(signal_ac));
    fft_result = fft(signal_ac, n_fft);
    fft_mag = abs(fft_result(1:n_fft/2));
    freq_axis = (0:n_fft/2-1) * fs / n_fft / 1e3;  % 转换为kHz

    % 乘以V/div得到绝对强度
    fft_mag = fft_mag * volt_div;

    % 截取0到freq_max kHz的范围
    valid_idx = freq_axis <= freq_max;
    freq_plot = freq_axis(valid_idx);
    mag_plot = fft_mag(valid_idx);

    % 输出结果：第一列频率，第二列幅值
    fft_data = [freq_plot(:), mag_plot(:)];

    % 绘图（仅当do_plot为true时）
    if do_plot
        figure;
        plot(freq_plot, mag_plot, 'LineWidth', 1);
        xlabel('频率 (kHz)');
        ylabel('幅值');
        title(sprintf('FFT频谱 (0-%d kHz)', freq_max));
        xlim([0, freq_max]);
        grid on;

        % 标注LED频率位置
        led_freqs = [380, 390, 400, 410, 420, 430, 440, 450, 460, 470, 480, 490];
        hold on;
        for i = 1:length(led_freqs)
            if led_freqs(i) <= freq_max
                xline(led_freqs(i), '--r', sprintf('%d', led_freqs(i)), ...
                    'LabelHorizontalAlignment', 'center', ...
                    'LabelVerticalAlignment', 'bottom', ...
                    'FontSize', 8, 'Alpha', 0.5);
            end
        end
        hold off;

        % 打印信息
        fprintf('文件: %s\n', filename);
        fprintf('V/div: %.4f V\n', volt_div);
        fprintf('信号长度: %d 点\n', length(signal));
        fprintf('FFT点数: %d\n', n_fft);
        fprintf('频率分辨率: %.3f kHz\n', fs / n_fft / 1e3);
        fprintf('输出数据: %d x 2 矩阵 [频率(kHz), 幅值]\n', size(fft_data, 1));
    end
end
function [y, info] = extract_measurement(sample_csv, varargin)
% EXTRACT_MEASUREMENT 从样本CSV提取FDM测量值
%
% 用法：
%   y = extract_measurement(sample_csv)
%   [y, info] = extract_measurement(sample_csv, 'Name', Value)
%
% 输入：
%   sample_csv - 样本测量CSV文件
%
% 可选参数：
%   'Freqs'      - LED频率(kHz)，默认 [30,50,70,110,130,170,190,230,270,290,310,370]
%   'SkipLEDs'   - 跳过的LED索引，默认 []
%   'Duration'   - 截取时长(μs)，默认 100
%   'UseWindow'  - 是否使用窗函数，默认 false
%
% 输出：
%   y    - 测量值 [num_working × 1]
%   info - 结构体

    p = inputParser;
    p.addRequired('sample_csv');
    p.addParameter('Freqs', [30,50,70,110,130,170,190,230,270,290,310,370], @isnumeric);
    p.addParameter('SkipLEDs', [], @isnumeric);
    p.addParameter('Duration', 100, @isnumeric);  % 默认100μs
    p.addParameter('UseWindow', false, @islogical);
    p.parse(sample_csv, varargin{:});
    opts = p.Results;
    
    all_freqs = opts.Freqs(:)';
    num_leds = length(all_freqs);
    working_leds = setdiff(1:num_leds, opts.SkipLEDs(:)');
    
    % 提取频率幅度
    [y_full, df, extra] = extract_freq_amplitudes(sample_csv, all_freqs, ...
                                                   opts.Duration, opts.UseWindow);
    y = y_full(working_leds);
    
    % 输出信息
    if nargout >= 2
        info.y_full = y_full;
        info.working_leds = working_leds;
        info.freqs = all_freqs(working_leds);
        info.all_freqs = all_freqs;
        info.df = df;
        info.fs = extra.fs;
        info.N = extra.N;
        info.N_original = extra.N_original;
        info.duration = opts.Duration;
        info.truncated = extra.truncated;
    end
end

%% ==================== 内部函数 ====================
function [amplitudes, df, extra] = extract_freq_amplitudes(csv_file, target_freqs, duration_us, use_window)
% EXTRACT_FREQ_AMPLITUDES 提取指定频率的FFT幅度
%
% 输入：
%   csv_file     - CSV文件路径
%   target_freqs - 目标频率 (kHz)
%   duration_us  - 截取时长 (μs)
%   use_window   - 是否使用窗函数

    % 读取CSV头部获取采样参数
    fid = fopen(csv_file, 'r');
    if fid == -1
        error('无法打开文件: %s', csv_file);
    end
    fgetl(fid);
    line2 = fgetl(fid);
    fclose(fid);
    
    parts = strsplit(line2, ',');
    dt = str2double(parts{4});  % 采样间隔
    fs = 1 / dt;                % 采样率
    
    % 读取电压数据
    data = readmatrix(csv_file, 'NumHeaderLines', 2);
    voltage = data(:, 2);
    voltage = voltage(~isnan(voltage));
    N_original = length(voltage);
    
    % 计算目标采样点数
    N_target = round(duration_us * 1e-6 * fs);
    
    % 截取或保持原长度
    if N_original >= N_target
        voltage = voltage(1:N_target);
        truncated = true;
    else
        warning('数据长度 (%d点, %.1fμs) 不足 %.0fμs，使用全部数据', ...
                N_original, N_original * dt * 1e6, duration_us);
        N_target = N_original;
        truncated = false;
    end
    
    N = length(voltage);
    df = fs / N;  % 频率分辨率
    
    % 去除直流分量
    voltage_ac = voltage - mean(voltage);
    
    % 可选：应用窗函数
    if use_window
        win = hanning(N);
        voltage_ac = voltage_ac .* win;
        % 窗函数幅度补偿
        voltage_ac = voltage_ac * 2;  % 近似补偿
    end
    
    % FFT
    Y = fft(voltage_ac);
    P = 2 * abs(Y(1:floor(N/2)+1)) / N;
    f = fs * (0:floor(N/2)) / N;
    
    % 提取各频率幅度
    amplitudes = zeros(length(target_freqs), 1);
    for i = 1:length(target_freqs)
        target = target_freqs(i) * 1000;  % kHz → Hz
        
        % 检查频率是否落在整数bin上
        expected_bin = target / df;
        if abs(expected_bin - round(expected_bin)) < 0.01
            % 刚好在bin上，直接取
            idx = round(expected_bin) + 1;  % MATLAB索引从1开始
        else
            % 不在bin上，找最近的
            [~, idx] = min(abs(f - target));
        end
        
        amplitudes(i) = P(idx);
    end
    
    % 额外信息
    extra.fs = fs;
    extra.N = N;
    extra.N_original = N_original;
    extra.truncated = truncated;
    extra.df = df;
end
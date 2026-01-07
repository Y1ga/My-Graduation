function [y_norm, t, y_fft, info] = read_rigol_wfm_normalized(filename, fs, duration, normalize_method)
% READ_RIGOL_WFM_NORMALIZED 读取Rigol示波器wfm文件并归一化
%
% 输入：
%   filename         - wfm文件路径
%   fs               - 采样率 (Hz)，默认 1e9
%   duration         - 采样时间 (s)，默认 inf（读取全部）
%   normalize_method - 归一化方法，默认 'zscore'
%                      'zscore'  : 零均值、单位方差（推荐）
%                      'minmax'  : 归一化到 [0, 1]
%                      'ac_only' : 只去直流
%                      'none'    : 不归一化
%
% 输出：
%   y_norm - 归一化后的时域信号
%   t      - 时间轴
%   y_fft  - FFT提取的12个LED频率幅值
%   info   - 结构体，包含原始信号信息
%
% 使用示例：
%   [y, t, y_fft] = read_rigol_wfm_normalized('test.wfm', 1e9, 1e-3, 'zscore');

    if nargin < 2 || isempty(fs), fs = 1e9; end
    if nargin < 3 || isempty(duration), duration = inf; end
    if nargin < 4 || isempty(normalize_method), normalize_method = 'zscore'; end
    
    % LED调制频率 (kHz)
    led_freqs = [30, 50, 70, 110, 130, 170, 190, 230, 290, 310, 370, 410];
    n_leds = length(led_freqs);
    
    % =====================================================
    % 读取wfm文件
    % =====================================================
    fid = fopen(filename, 'rb');
    if fid == -1, error('无法打开文件: %s', filename); end
    
    % 读取V/div (0x84)
    fseek(fid, hex2dec('84'), 'bof');
    volt_div = fread(fid, 1, 'float32');
    
    % 读取电压刻度因子 (0xA0)
    fseek(fid, hex2dec('A0'), 'bof');
    volt_scale = fread(fid, 1, 'float32');
    
    % 读取电压偏移 (0xA4)
    volt_offset = fread(fid, 1, 'float32');
    
    % 读取原始数据
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
    
    % 生成时间轴
    t = (0:length(signal)-1)' / fs;
    
    % =====================================================
    % 保存原始信息
    % =====================================================
    info.volt_div = volt_div;
    info.volt_scale = volt_scale;
    info.volt_offset = volt_offset;
    info.raw_mean = mean(signal);
    info.raw_std = std(signal);
    info.raw_min = min(signal);
    info.raw_max = max(signal);
    info.n_samples = length(signal);
    
    % =====================================================
    % 归一化
    % =====================================================
    switch lower(normalize_method)
        case 'zscore'
            y_norm = (signal - info.raw_mean) / info.raw_std;
            
        case 'minmax'
            y_norm = (signal - info.raw_min) / (info.raw_max - info.raw_min);
            
        case 'ac_only'
            y_norm = signal - info.raw_mean;
            
        case 'none'
            y_norm = signal;
            
        otherwise
            error('未知的归一化方法: %s', normalize_method);
    end
    
    % =====================================================
    % FFT提取各频率幅值
    % =====================================================
    signal_ac = signal - mean(signal);
    n_fft = 2^nextpow2(length(signal_ac));
    fft_result = fft(signal_ac, n_fft);
    fft_mag = abs(fft_result(1:n_fft/2));
    fft_mag = fft_mag(:);  % 确保是列向量
    freq_axis = (0:n_fft/2-1)' * fs / n_fft / 1e3;  % kHz，列向量
    freq_resolution = fs / n_fft / 1e3;
    
    % 提取各LED频率的幅值
    y_fft = zeros(n_leds, 1);
    search_width = max(5, freq_resolution * 2);
    
    for i = 1:n_leds
        f_target = led_freqs(i);
        mask = (freq_axis >= f_target - search_width) & (freq_axis <= f_target + search_width);
        masked_mag = fft_mag .* mask;  % 逐元素相乘
        [max_val, ~] = max(masked_mag);
        y_fft(i) = max_val * volt_div;  % 乘以V/div得到绝对幅值
    end
    
    info.y_fft = y_fft;
end
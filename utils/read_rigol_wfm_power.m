function [amps, freq_detected, volt_div, v_min, v_max, signal] = read_rigol_wfm_power(filename, fs, duration)
% READ_RIGOL_WFM 读取Rigol示波器WFM文件并提取FFT幅值
%
% 输入:
%   filename - WFM文件路径
%   fs       - 目标采样率 (默认 1e9，即不降采样)
%   duration - 截取时长 (默认 inf)
%
% 输出:
%   amps         - 12个LED基频的FFT幅值
%   freq_detected - 检测到的实际频率
%   volt_div     - 示波器V/div设置
%   v_min        - 信号最小电压
%   v_max        - 信号最大电压
%   signal       - 时域信号（已去DC）

    % 原始采样率（Rigol示波器固定1GHz）
    fs_original = 1e9;
    
    if nargin < 2 || isempty(fs), fs = fs_original; end
    if nargin < 3 || isempty(duration), duration = inf; end
    
    led_freqs = [30, 50, 70, 110, 130, 170, 190, 230, 290, 310, 370, 410];
    n_leds = length(led_freqs);
    
    fid = fopen(filename, 'rb');
    if fid == -1, error('无法打开文件: %s', filename); end
    
    % 读取真实V/div (0x84)
    fseek(fid, hex2dec('84'), 'bof');
    volt_div = fread(fid, 1, 'float32');
    
    % 读取电压刻度因子 (0xA0)
    fseek(fid, hex2dec('A0'), 'bof');
    volt_scale = fread(fid, 1, 'float32');
    
    % 读取数据
    fseek(fid, 3334, 'bof');
    raw_data = fread(fid, inf, 'uint8');
    fclose(fid);
    
    % 转换为电压（修正：乘以 volt_scale * volt_div）
    signal = (double(raw_data) - 128) * volt_scale * volt_div;
    
    % 截取指定时长（基于原始采样率）
    if isfinite(duration)
        n_use = min(round(duration * fs_original), length(signal));
        signal = signal(1:n_use);
    end
    
    % 降采样（如果目标采样率低于原始采样率）
    if fs < fs_original
        downsample_factor = round(fs_original / fs);
        signal = signal(1:downsample_factor:end);
    end
    
    % 去除DC
    signal = signal - mean(signal);
    
    % 输出电压范围
    v_min = min(signal);
    v_max = max(signal);
    
    % FFT（使用目标采样率计算频率轴）
    n_fft = 2^nextpow2(length(signal));
    fft_result = fft(signal, n_fft);
    fft_mag = abs(fft_result(1:n_fft/2));
    freq_axis = (0:n_fft/2-1) * fs / n_fft / 1e3;  % kHz
    freq_resolution = fs / n_fft / 1e3;
    
    % 提取幅度
    amps = zeros(n_leds, 1);
    freq_detected = zeros(n_leds, 1);
    search_width = max(5, freq_resolution * 2);
    
    % 奈奎斯特频率
    nyquist = fs / 2 / 1e3;  % kHz
    
    for i = 1:n_leds
        f_target = led_freqs(i);
        
        % 检查是否超过奈奎斯特频率
        if f_target >= nyquist
            amps(i) = NaN;
            freq_detected(i) = NaN;
            continue;
        end
        
        mask = (freq_axis >= f_target - search_width) & (freq_axis <= f_target + search_width);
        [max_val, max_idx] = max(fft_mag .* mask');
        amps(i) = max_val;
        freq_detected(i) = freq_axis(max_idx);
    end
end
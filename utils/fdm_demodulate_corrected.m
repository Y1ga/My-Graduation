function [amplitudes, f, P, debug_info] = fdm_demodulate_corrected(voltage, varargin)
% FDM_DEMODULATE_CORRECTED 修正后的FFT解调函数
%
% 改进:
%   1. 支持窗函数减少频谱泄漏
%   2. 峰值搜索代替单bin取值
%   3. 幅度修正
%
% 语法:
%   amplitudes = fdm_demodulate_corrected(voltage)
%   amplitudes = fdm_demodulate_corrected(voltage, target_freqs_Hz)
%   [amplitudes, f, P, debug_info] = fdm_demodulate_corrected(voltage, target_freqs_Hz, ...)
%
% 可选参数:
%   'Fs'           - 采样率 (默认: 10MHz)
%   'Window'       - 窗函数: 'none','hann','hamming','blackman','flattop' (默认: 'flattop')
%   'PeakSearch'   - 是否使用峰值搜索 (默认: true)
%   'SearchWidth'  - 峰值搜索宽度Hz (默认: 4000)
%
% 示例:
%   % 使用修正后的解调
%   amps = fdm_demodulate_corrected(voltage, freqs_Hz, 'Window', 'flattop');
%
% 作者: Claude
% 日期: 2024-12

    % 默认参数
    DEFAULT_FS = 10e6;
    DEFAULT_FREQS_KHZ = [118, 128, 138, 148, 158, 168, 178, 208, 218, 228];
    
    p = inputParser;
    addRequired(p, 'voltage', @isnumeric);
    addOptional(p, 'target_freqs_Hz', DEFAULT_FREQS_KHZ * 1000, @isnumeric);
    addParameter(p, 'Fs', DEFAULT_FS, @isnumeric);
    addParameter(p, 'Window', 'flattop', @ischar);
    addParameter(p, 'PeakSearch', true, @islogical);
    addParameter(p, 'SearchWidth', 4000, @isnumeric);  % Hz
    parse(p, voltage, varargin{:});
    
    voltage = p.Results.voltage(:);
    target_freqs = p.Results.target_freqs_Hz(:);
    Fs = p.Results.Fs;
    window_type = p.Results.Window;
    use_peak_search = p.Results.PeakSearch;
    search_width = p.Results.SearchWidth;
    
    N = length(voltage);
    df = Fs / N;
    
    % 选择窗函数
    switch lower(window_type)
        case 'none'
            win = ones(N, 1);
            win_name = 'Rectangular';
        case 'hann'
            win = hann(N);
            win_name = 'Hann';
        case 'hamming'
            win = hamming(N);
            win_name = 'Hamming';
        case 'blackman'
            win = blackman(N);
            win_name = 'Blackman';
        case 'flattop'
            win = flattopwin(N);
            win_name = 'Flat-top';
        otherwise
            win = ones(N, 1);
            win_name = 'Rectangular';
    end
    
    % 计算窗函数幅度修正因子 (coherent gain)
    coherent_gain = sum(win) / N;
    
    % 去直流
    voltage_ac = voltage - mean(voltage);
    
    % 加窗
    voltage_windowed = voltage_ac .* win;
    
    % FFT
    Y = fft(voltage_windowed);
    P_raw = 2 * abs(Y(1:floor(N/2)+1)) / N;
    
    % 幅度修正 (补偿窗函数引入的增益损失)
    P = P_raw / coherent_gain;
    
    f = Fs * (0:floor(N/2))' / N;
    
    % 提取各频率幅度
    amplitudes = zeros(length(target_freqs), 1);
    peak_freqs = zeros(length(target_freqs), 1);
    search_bins = round(search_width / df);
    
    for i = 1:length(target_freqs)
        [~, center_idx] = min(abs(f - target_freqs(i)));
        
        if use_peak_search
            % 在目标频率附近搜索峰值
            search_start = max(1, center_idx - search_bins);
            search_end = min(length(P), center_idx + search_bins);
            search_idx = search_start:search_end;
            
            [amplitudes(i), local_idx] = max(P(search_idx));
            peak_freqs(i) = f(search_idx(local_idx));
        else
            % 直接取目标频率bin的值
            amplitudes(i) = P(center_idx);
            peak_freqs(i) = f(center_idx);
        end
    end
    
    % 调试信息
    debug_info.window = win_name;
    debug_info.coherent_gain = coherent_gain;
    debug_info.df = df;
    debug_info.N = N;
    debug_info.peak_freqs = peak_freqs;
    debug_info.target_freqs = target_freqs;
    debug_info.freq_errors = peak_freqs - target_freqs;
end
function [amplitudes, f, P, df] = fdm_demodulate(voltage, varargin)
% FDM_DEMODULATE FFT解调提取各频率分量幅度
%
% 语法:
%   amplitudes = fdm_demodulate(voltage)
%   amplitudes = fdm_demodulate(voltage, target_freqs_Hz)
%   amplitudes = fdm_demodulate(voltage, params)  % 使用fdm_generate_signal返回的params
%   [amplitudes, f, P, df] = fdm_demodulate(voltage, target_freqs_Hz, 'Fs', Fs)
%
% 输入:
%   voltage         - 时域电压信号 [N x 1] 或 [1 x N]
%   target_freqs_Hz - 目标频率数组 (Hz), 或 fdm_generate_signal返回的params结构体
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
%   % 方式1: 指定频率
%   freqs = [118, 128, 138] * 1000;
%   amps = fdm_demodulate(voltage, freqs, 'Fs', 10e6);
%
%   % 方式2: 使用params (推荐，确保频率一致)
%   [v, t, params] = fdm_generate_signal(amps_in, 'FreqMode', 'auto');
%   amps_out = fdm_demodulate(v, params);
%
% 作者: Claude
% 日期: 2024-12

    % 默认参数
    DEFAULT_FS = 10e6;
    DEFAULT_FREQS_KHZ = [118, 128, 138, 148, 158, 168, 178, 208, 218, 228];
    
    % 检查第二个参数是否为params结构体
    if nargin >= 2 && isstruct(varargin{1})
        params = varargin{1};
        target_freqs_Hz = params.FreqsHz;
        Fs = params.Fs;
        varargin = varargin(2:end);  % 移除已处理的参数
    else
        % 常规解析
        p = inputParser;
        addRequired(p, 'voltage', @isnumeric);
        addOptional(p, 'target_freqs_Hz', DEFAULT_FREQS_KHZ * 1000, @isnumeric);
        addParameter(p, 'Fs', DEFAULT_FS, @isnumeric);
        parse(p, voltage, varargin{:});
        
        target_freqs_Hz = p.Results.target_freqs_Hz(:);
        Fs = p.Results.Fs;
    end
    
    voltage = voltage(:);  % 列向量
    target_freqs = target_freqs_Hz(:);
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

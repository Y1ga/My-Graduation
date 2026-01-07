function [y_t, t, y_fft, freq_detected, amplitudes] = simulate_led_signal(A0, x_gt, k_A, fs, duration, snr_db, normalize_method, random_phase)
% SIMULATE_LED_SIGNAL 仿真多LED频分复用光谱测量信号（50%占空比方波）
%
% 输入：
%   A0               - LED归一化光谱矩阵 (12×31)
%   x_gt             - 目标物体光谱 (31×1)
%   k_A              - 系统增益向量 (12×1)，即白板测量的各LED响应强度
%   fs               - 采样率 (Hz)，默认 1e9
%   duration         - 采样时间 (s)，默认 1e-3 (1ms)
%   snr_db           - 信噪比 (dB)，若为空则不加噪声
%   normalize_method - 归一化方法，默认 'zscore'
%                      'zscore'  : 零均值、单位方差（推荐）
%                      'minmax'  : 归一化到 [0, 1]
%                      'ac_only' : 只去直流
%                      'none'    : 不归一化（输出原始幅值）
%   random_phase     - 是否添加随机初始相位，默认 true
%
% 输出：
%   y_t          - 时域信号（归一化后）
%   t            - 时间轴 (s)
%   y_fft        - FFT提取的基频幅值 (12×1)
%   freq_detected - 检测到的频率 (12×1)
%   amplitudes   - 各LED理论幅值 (12×1)
%
% 说明：
%   方波的傅里叶级数：f(t) = A/2 + (2A/π)∑(1/n)sin(nωt), n=1,3,5,...
%   直流分量 = Σ(A_i/2)，基频幅值 = 2A/π ≈ 0.6366A
%
% 使用示例：
%   % E2E训练用（归一化输出，随机相位）
%   [y_t, t] = simulate_led_signal(A0, x_gt, k_A, 1e9, 1e-3, 40, 'zscore', true);
%
%   % 固定相位（用于调试）
%   [y_t, t] = simulate_led_signal(A0, x_gt, k_A, 1e9, 1e-3, [], 'none', false);

    % 默认参数
    if nargin < 4 || isempty(fs), fs = 1e9; end
    if nargin < 5 || isempty(duration), duration = 1e-3; end
    if nargin < 6, snr_db = []; end
    if nargin < 7 || isempty(normalize_method), normalize_method = 'zscore'; end
    if nargin < 8 || isempty(random_phase), random_phase = true; end
    if nargin < 3 || isempty(k_A), k_A = ones(12, 1); end

    % LED调制频率 (kHz -> Hz)
    led_freqs = [30, 50, 70, 110, 130, 170, 190, 230, 290, 310, 370, 410] * 1e3;
    n_leds = length(led_freqs);
    
    % 确保 x_gt 是列向量
    x_gt = x_gt(:);
    k_A = k_A(:);
    
    % =====================================================
    % 计算各LED对目标光谱的响应（理论幅值）
    % 物理模型：y_i = k_i * (A0_i · x)
    %   - A0_i: 第i个LED的归一化光谱 (1×31)
    %   - x: 目标反射光谱 (31×1)
    %   - k_i: 第i个LED在白板上的响应（系统增益）
    % =====================================================
    
    % 光谱响应：每个LED对目标光谱的响应比例
    spectral_response = A0 * x_gt;  % (12×31) * (31×1) = (12×1)
    
    % 乘以系统增益得到实际幅值
    amplitudes = spectral_response .* k_A;
    
    % =====================================================
    % 生成时域信号（50%占空比方波）
    % =====================================================
    n_samples = round(fs * duration);
    t = (0:n_samples-1)' / fs;
    
    % 生成随机初始相位（如果启用）
    if random_phase
        phases = 2 * pi * rand(n_leds, 1);  % 每个LED独立的随机相位 [0, 2π]
    else
        phases = zeros(n_leds, 1);  % 所有相位为0
    end
    
    % 各LED方波叠加
    y_t = zeros(n_samples, 1);
    for i = 1:n_leds
        % 50%占空比方波，带随机初始相位
        % sign(sin(ωt + φ)) 产生相位偏移的方波
        square_wave = (sign(sin(2 * pi * led_freqs(i) * t + phases(i))) + 1) / 2;
        y_t = y_t + amplitudes(i) * square_wave;
    end
    
    % =====================================================
    % 添加噪声（可选，在归一化之前）
    % =====================================================
    if ~isempty(snr_db)
        signal_power = mean(y_t.^2);
        noise_power = signal_power / (10^(snr_db/10));
        noise = sqrt(noise_power) * randn(size(y_t));
        y_t = y_t + noise;
    end
    
    % =====================================================
    % 归一化（用于E2E网络训练）
    % =====================================================
    switch lower(normalize_method)
        case 'zscore'
            % 零均值、单位方差（推荐）
            y_t = (y_t - mean(y_t)) / std(y_t);
            
        case 'minmax'
            % 归一化到 [0, 1]
            y_t = (y_t - min(y_t)) / (max(y_t) - min(y_t));
            
        case 'ac_only'
            % 只去直流
            y_t = y_t - mean(y_t);
            
        case 'none'
            % 不归一化，保留原始值
            % y_t 保持不变
            
        otherwise
            error('未知的归一化方法: %s', normalize_method);
    end
    
    % =====================================================
    % FFT提取幅值（与read_rigol_wfm保持一致的处理方式）
    % =====================================================
    signal_ac = y_t - mean(y_t);
    n_fft = 2^nextpow2(length(signal_ac));
    fft_result = fft(signal_ac, n_fft);
    fft_mag = abs(fft_result(1:n_fft/2));
    fft_mag = fft_mag(:);  % 确保是列向量
    freq_axis = (0:n_fft/2-1)' * fs / n_fft;  % Hz，列向量
    freq_resolution = fs / n_fft;
    
    % FFT幅值归一化：除以 N/2 得到真实幅值
    % 对于方波基频，理论幅值 = A * 2/π
    fft_mag = fft_mag / (n_fft / 2);
    
    % 在各LED频率附近搜索峰值
    y_fft = zeros(n_leds, 1);
    freq_detected = zeros(n_leds, 1);
    search_width = max(5e3, freq_resolution * 2);  % Hz
    
    for i = 1:n_leds
        f_target = led_freqs(i);
        mask = (freq_axis >= f_target - search_width) & (freq_axis <= f_target + search_width);
        masked_mag = fft_mag .* mask;  % 两个都是列向量，逐元素相乘
        [max_val, max_idx] = max(masked_mag);
        y_fft(i) = max_val;
        freq_detected(i) = freq_axis(max_idx);
    end
end
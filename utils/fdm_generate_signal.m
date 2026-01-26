function [v_signal, t, params] = fdm_generate_signal(amplitudes, varargin)
% FDM_GENERATE_SIGNAL 生成FDM调制的时域信号
%
% 语法:
%   [v_signal, t] = fdm_generate_signal(amplitudes)
%   [v_signal, t, params] = fdm_generate_signal(amplitudes, 'Name', Value, ...)
%
% 输入:
%   amplitudes  - 各LED幅度 [N_led x 1] 或 [1 x N_led]
%
% 可选参数 (Name-Value pairs):
%   'Fs'        - 采样率 (默认: 10MHz)
%   'N'         - 采样点数 (默认: 1200)
%   'FreqsHz'   - 各LED调制频率Hz (默认: [], 自动选择)
%   'FreqMode'  - 频率模式: 'auto', 'legacy', 'custom' (默认: 'auto')
%   'T'         - 采样时间，用于自动频率选择 (默认: 100e-6)
%   'DC'        - 直流偏置 (默认: 0)
%   'Phases'    - 各LED相位 (默认: 随机)
%   'Waveform'  - 波形类型: 'sine', 'square', 'square_odd' (默认: 'sine')
%                 'sine': 纯正弦波（理想情况）
%                 'square': 方波，包含所有谐波（2,3,4,5,...）模拟实际非理想驱动
%                 'square_odd': 理想方波，只含奇次谐波（1,3,5,7,...）
%   'MaxHarmonicFreq' - 谐波最大频率限制Hz (默认: 500e3)
%   'SNR_dB'        - 全频段白噪声信噪比dB (默认: Inf, 无噪声)
%   'SNR_inband_dB' - 带内噪声信噪比dB, 30-410kHz (默认: Inf)
%   'SNR_100Hz_dB'  - 100Hz工频干扰信噪比dB (默认: Inf, 无干扰)
%   'AmbientDC'     - DC环境光强度，相对信号的倍数 (默认: 0)
%   'Ambient100Hz'  - [旧参数，保留兼容] 100Hz灯光干扰，相对信号的倍数 (默认: 0)
%   'AmbientSMPS'   - SMPS/PWM开关噪声，相对信号的倍数 (默认: 0)
%   'SMPSFreqHz'    - SMPS/PWM干扰频率Hz (默认: 100e3)
%                     ≤30kHz: PWM调光，方波模型（奇次谐波，1/k衰减）
%                     >30kHz: SMPS电源，三角波模型（奇次谐波，1/k²衰减）
%   'NoiseRefMode'  - 噪声倍数参考基准 (默认: 'rms')
%                     'mean': 各LED幅度平均值
%                     'sum':  各LED幅度总和
%                     'rms':  信号RMS值（推荐，物理意义明确）
%   'Seed'          - 随机种子 (默认: 无)
%
% 输出:
%   v_signal    - 时域电压信号 [1 x N]
%   t           - 时间轴 [1 x N]
%   params      - 使用的参数结构体
%
% 噪声模型说明:
%   PWM调光噪声 (≤30kHz): 方波傅里叶级数，仅奇次谐波
%     n(t) = A * [sin(ωt) + (1/3)sin(3ωt) + (1/5)sin(5ωt) + (1/7)sin(7ωt) + (1/9)sin(9ωt)]
%   SMPS开关噪声 (>30kHz): 三角波傅里叶级数，奇次谐波按1/k²衰减
%     n(t) = A * [sin(ωt) - (1/9)sin(3ωt) + (1/25)sin(5ωt) - (1/49)sin(7ωt)]
%
% 示例:
%   % 自动选择频率，使用方波（含所有谐波）
%   amps = rand(1, 12);
%   [v, t, p] = fdm_generate_signal(amps, 'FreqMode', 'auto', 'Waveform', 'square');
%
%   % 添加20kHz PWM调光噪声
%   [v, t, p] = fdm_generate_signal(amps, 'AmbientSMPS', 10, 'SMPSFreqHz', 20e3);
%
%   % 添加100kHz SMPS开关噪声
%   [v, t, p] = fdm_generate_signal(amps, 'AmbientSMPS', 10, 'SMPSFreqHz', 100e3);
%
% 作者: Claude
% 日期: 2024-12

    % 旧版默认频率 (兼容)
    LEGACY_FREQS_KHZ = [118, 128, 138, 148, 158, 168, 178, 208, 218, 228];
    
    % 解析输入参数
    p = inputParser;
    addRequired(p, 'amplitudes', @isnumeric);
    addParameter(p, 'Fs', 10e6, @isnumeric);
    addParameter(p, 'N', [], @isnumeric);  % 默认由T和Fs计算
    addParameter(p, 'FreqsHz', [], @isnumeric);
    addParameter(p, 'FreqMode', 'auto', @ischar);  % 'auto', 'legacy', 'custom'
    addParameter(p, 'T', 100e-6, @isnumeric);  % 采样时间
    addParameter(p, 'DC', 0, @isnumeric);
    addParameter(p, 'Phases', [], @isnumeric);
    addParameter(p, 'Waveform', 'sine', @ischar);  % 'sine', 'square', 'square_odd'
    addParameter(p, 'MaxHarmonicFreq', 500e3, @isnumeric);  % 谐波最大频率
    addParameter(p, 'SNR_dB', Inf, @isnumeric);        % 白噪声（全频段）
    addParameter(p, 'SNR_inband_dB', Inf, @isnumeric); % 带内噪声
    addParameter(p, 'SNR_100Hz_dB', Inf, @isnumeric);  % 100Hz工频干扰 (SNR定义)
    addParameter(p, 'NoiseMode', 'white', @ischar);    % 'white', 'inband', 'ambient'
    addParameter(p, 'AmbientDC', 0, @isnumeric);       % DC环境光强度
    addParameter(p, 'Ambient100Hz', 0, @isnumeric);    % [旧参数] 100Hz灯光干扰强度
    addParameter(p, 'AmbientSMPS', 0, @isnumeric);     % SMPS/PWM开关噪声强度
    addParameter(p, 'SMPSFreqHz', 100e3, @isnumeric);  % SMPS/PWM频率
    addParameter(p, 'NoiseRefMode', 'rms', @ischar);   % 噪声参考基准: 'mean', 'sum', 'rms'
    addParameter(p, 'Seed', [], @isnumeric);
    parse(p, amplitudes, varargin{:});
    
    opts = p.Results;
    amplitudes = opts.amplitudes(:)';  % 确保是行向量
    num_led = length(amplitudes);
    Fs = opts.Fs;
    T = opts.T;
    
    %% 确定采样点数N
    if isempty(opts.N)
        % 由T和Fs计算
        N = round(Fs * T);
    else
        N = opts.N;
        T = N / Fs;  % 更新实际采样时间
    end
    
    %% 确定频率
    switch lower(opts.FreqMode)
        case 'auto'
            % 自动选择满足约束的频率
            if isempty(opts.FreqsHz)
                [freqs_Hz, freq_info] = fdm_select_frequencies(num_led, 'T', T);
            else
                freqs_Hz = opts.FreqsHz(:)';
            end
            
        case 'legacy'
            % 使用旧版固定频率
            freqs_Hz = LEGACY_FREQS_KHZ(1:min(num_led, length(LEGACY_FREQS_KHZ))) * 1000;
            
        case 'custom'
            % 使用用户指定的频率
            if isempty(opts.FreqsHz)
                error('FreqMode=''custom'' 时必须指定 FreqsHz');
            end
            freqs_Hz = opts.FreqsHz(:)';
            
        otherwise
            error('未知的 FreqMode: %s', opts.FreqMode);
    end
    
    % 验证频率数量
    if length(freqs_Hz) < num_led
        error('频率数量(%d)少于幅度数量(%d)', length(freqs_Hz), num_led);
    elseif length(freqs_Hz) > num_led
        freqs_Hz = freqs_Hz(1:num_led);  % 截取
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
    dt = 1 / Fs;
    t = (0:N-1) * dt;
    
    %% 生成信号
    v_signal = opts.DC * ones(1, N);
    f_max_harmonic = opts.MaxHarmonicFreq;
    
    % 记录谐波信息
    harmonic_info = struct('num_harmonics', 0, 'max_order', 1);
    total_harmonics = 0;
    max_harmonic_order = 1;
    
    switch lower(opts.Waveform)
        case 'sine'
            % 纯正弦波: v(t) = DC + Σ a_i * sin(2πf_i*t + φ_i)
            for i = 1:num_led
                v_signal = v_signal + amplitudes(i) * sin(2*pi*freqs_Hz(i)*t + phases(i));
            end
            
        case 'square'
            % 方波（含所有谐波: 1, 2, 3, 4, 5, ...）
            % 模拟实际非理想驱动电路产生的波形
            % 傅里叶级数: Σ (1/n) * sin(2πnf*t)
            for i = 1:num_led
                f0 = freqs_Hz(i);
                n_max = floor(f_max_harmonic / f0);
                max_harmonic_order = max(max_harmonic_order, n_max);
                
                for n = 1:n_max  % 所有谐波: 1, 2, 3, 4, ...
                    f_harmonic = n * f0;
                    if f_harmonic <= f_max_harmonic
                        % 幅度按1/n衰减
                        v_signal = v_signal + amplitudes(i) * (1/n) * sin(2*pi*f_harmonic*t + n*phases(i));
                        total_harmonics = total_harmonics + 1;
                    end
                end
            end
            
        case 'square_odd'
            % 理想方波（只含奇次谐波: 1, 3, 5, 7, ...）
            % 50%占空比方波的傅里叶级数
            for i = 1:num_led
                f0 = freqs_Hz(i);
                n_max = floor(f_max_harmonic / f0);
                max_harmonic_order = max(max_harmonic_order, n_max);
                
                for n = 1:2:n_max  % 奇次谐波: 1, 3, 5, 7, ...
                    f_harmonic = n * f0;
                    if f_harmonic <= f_max_harmonic
                        % 幅度按1/n衰减，系数4/π
                        v_signal = v_signal + amplitudes(i) * (4/pi) * (1/n) * sin(2*pi*f_harmonic*t + n*phases(i));
                        total_harmonics = total_harmonics + 1;
                    end
                end
            end
            
        otherwise
            error('未知的 Waveform: %s. 可选: sine, square, square_odd', opts.Waveform);
    end
    
    harmonic_info.num_harmonics = total_harmonics;
    harmonic_info.max_order = max_harmonic_order;
    
    % 添加噪声
    noise_total = zeros(1, N);
    
    % 计算噪声参考基准
    switch lower(opts.NoiseRefMode)
        case 'mean'
            signal_ref = mean(abs(amplitudes));  % 各LED幅度平均值
        case 'sum'
            signal_ref = sum(abs(amplitudes));   % 各LED幅度总和
        case 'rms'
            signal_ref = rms(v_signal - opts.DC);  % 信号RMS值（去直流）
        otherwise
            signal_ref = rms(v_signal - opts.DC);  % 默认RMS
    end
    
    % 计算信号功率（用于SNR计算）
    signal_power = var(v_signal - opts.DC);
    
    % === 带外噪声 (环境光) ===
    % DC环境光 - AmbientDC表示DC是信号的多少倍
    if opts.AmbientDC > 0
        dc_amplitude = opts.AmbientDC * signal_ref;
        noise_total = noise_total + dc_amplitude;
    end
    
    % 100Hz灯光干扰 - 新参数：SNR_100Hz_dB (SNR定义)
    if ~isinf(opts.SNR_100Hz_dB)
        % 使用SNR定义
        noise_power_100hz = signal_power / (10^(opts.SNR_100Hz_dB/10));
        hz100_amplitude = sqrt(2 * noise_power_100hz);  % 正弦波幅度 = sqrt(2) * RMS
        
        if ~isempty(opts.Seed)
            phase_100hz = 0;  % 固定相位便于复现
        else
            phase_100hz = 2 * pi * rand();
        end
        
        % 100Hz及其谐波
        noise_100hz = hz100_amplitude * sin(2*pi*100*t + phase_100hz);
        noise_100hz = noise_100hz + hz100_amplitude * 0.3 * sin(2*pi*200*t + phase_100hz);
        noise_100hz = noise_100hz + hz100_amplitude * 0.1 * sin(2*pi*300*t + phase_100hz);
        
        % 归一化使总功率符合SNR定义
        actual_power = var(noise_100hz);
        noise_100hz = noise_100hz * sqrt(noise_power_100hz / actual_power);
        
        noise_total = noise_total + noise_100hz;
        
    elseif opts.Ambient100Hz > 0
        % 旧参数：倍数定义（保留兼容）
        hz100_amplitude = opts.Ambient100Hz * signal_ref;
        if ~isempty(opts.Seed)
            phase_100hz = 0;
        else
            phase_100hz = 2 * pi * rand();
        end
        noise_total = noise_total + hz100_amplitude * sin(2*pi*100*t + phase_100hz);
        noise_total = noise_total + hz100_amplitude * 0.3 * sin(2*pi*200*t + phase_100hz);
        noise_total = noise_total + hz100_amplitude * 0.1 * sin(2*pi*300*t + phase_100hz);
    end
    
    % === SMPS/PWM 开关噪声 ===
    % 根据频率自动选择波形模型:
    %   PWM调光 (≤30kHz): 真实方波 (square函数)
    %   SMPS开关电源 (>30kHz): 三角波模型 (sawtooth函数)
    if opts.AmbientSMPS > 0
        smps_amplitude = opts.AmbientSMPS * signal_ref;
        smps_freq = opts.SMPSFreqHz;
        if ~isempty(opts.Seed)
            phase_smps = 0;
        else
            phase_smps = 2 * pi * rand();
        end
        
        omega = 2 * pi * smps_freq;
        
        if smps_freq <= 30e3
            % === PWM 调光噪声 (≤30kHz): 真实方波 ===
            % 使用 square() 生成50%占空比方波，值域[-1, 1]
            % 频谱自动包含所有奇次谐波 (1, 3, 5, 7, ...)，幅度按 1/k 衰减
            noise_smps = smps_amplitude * square(omega*t + phase_smps);
        else
            % === SMPS 开关电源噪声 (>30kHz): 真实三角波 ===
            % 使用 sawtooth(..., 0.5) 生成对称三角波，值域[-1, 1]
            % 频谱自动包含所有奇次谐波 (1, 3, 5, 7, ...)，幅度按 1/k² 衰减
            noise_smps = smps_amplitude * sawtooth(omega*t + phase_smps, 0.5);
        end
        
        noise_total = noise_total + noise_smps;
    end
    
    % === 全频段白噪声 (SNR定义) ===
    if ~isinf(opts.SNR_dB)
        noise_power = signal_power / (10^(opts.SNR_dB/10));
        noise_white = sqrt(noise_power) * randn(1, N);
        noise_total = noise_total + noise_white;
    end
    
    % === 带内噪声 (SNR定义, 30-410kHz) ===
    if ~isinf(opts.SNR_inband_dB)
        noise_power = signal_power / (10^(opts.SNR_inband_dB/10));
        
        % 生成带限噪声
        noise_inband = sqrt(noise_power) * randn(1, N);
        f_low = 30e3 / (Fs/2);
        f_high = min(410e3 / (Fs/2), 0.99);
        if f_high > f_low
            [b, a] = butter(4, [f_low, f_high], 'bandpass');
            noise_inband = filter(b, a, noise_inband);
            noise_inband = noise_inband * sqrt(noise_power / var(noise_inband));
        end
        noise_total = noise_total + noise_inband;
    end
    
    v_signal = v_signal + noise_total;
    
    % 返回参数
    params.Fs = Fs;
    params.N = N;
    params.T = T;
    params.dt = dt;
    params.df = Fs / N;
    params.FreqsHz = freqs_Hz;
    params.FreqsKHz = freqs_Hz / 1000;
    params.FreqMode = opts.FreqMode;
    params.Waveform = opts.Waveform;
    params.MaxHarmonicFreq = f_max_harmonic;
    params.HarmonicInfo = harmonic_info;
    params.DC = opts.DC;
    params.Phases = phases;
    params.SNR_dB = opts.SNR_dB;
    params.SNR_inband_dB = opts.SNR_inband_dB;
    params.SNR_100Hz_dB = opts.SNR_100Hz_dB;
    params.AmbientDC = opts.AmbientDC;
    params.Ambient100Hz = opts.Ambient100Hz;
    params.AmbientSMPS = opts.AmbientSMPS;
    params.SMPSFreqHz = opts.SMPSFreqHz;
    params.NoiseRefMode = opts.NoiseRefMode;
    params.signal_ref = signal_ref;  % 实际使用的噪声参考值
    params.amplitudes = amplitudes;
    
    % 如果是自动模式，附加频率选择信息
    if strcmpi(opts.FreqMode, 'auto') && exist('freq_info', 'var')
        params.freq_info = freq_info;
    end
end
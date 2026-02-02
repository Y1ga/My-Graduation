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
%   'MaxHarmonicFreq' - 谐波最大频率限制Hz (默认: 500e3)
%   'SNR_dB'        - 全频段白噪声信噪比dB (默认: Inf, 无噪声)
%   'SNR_inband_dB' - 带内噪声信噪比dB (默认: Inf)
%   'InbandNoiseMode' - 带内噪声模式 (默认: 'gaussian')
%                       'gaussian': 带限高斯白噪声 (原模式)
%                       'multitone': 多音干扰模型
%   'InbandNumTones'  - 多音干扰的音调数量M (默认: 20)
%   'InbandFreqRange' - 带内噪声频率范围 [f_min, f_max] Hz (默认: [30e3, 410e3])
%   'InbandAvoidCarrier' - 多音频率是否避开调制频率 (默认: false)
%   'InbandGuardBand'    - 保护带宽Hz (默认: 1e3)
%   'SNR_100Hz_dB'  - 100Hz工频干扰信噪比dB (默认: Inf, 无干扰)
%   'AmbientDC'     - DC环境光强度，相对信号的倍数 (默认: 0)
%   'Ambient100Hz'  - [旧参数，保留兼容] 100Hz灯光干扰 (默认: 0)
%   'AmbientSMPS'   - SMPS/PWM开关噪声 (默认: 0)
%   'SMPSFreqHz'    - SMPS/PWM干扰频率Hz (默认: 100e3)
%   'NoiseRefMode'  - 噪声倍数参考基准 (默认: 'rms')
%   'Seed'          - 随机种子 (默认: 无)
%
% 带内噪声模型说明:
%   1. 'gaussian' (带限高斯白噪声):
%      n(t) = BPF{ white_noise(t) }
%      功率谱密度在带内均匀分布，模拟热噪声等
%
%   2. 'multitone' (多音干扰):
%      I_inband(t) = Σ A_j * cos(2πf_j*t + φ_j), f_j ∈ [f_min, f_max]
%      模拟实际环境中的窄带干扰源（开关电源、荧光灯等）
%      - M: 干扰音调数量 (InbandNumTones)
%      - A_j: 各音调幅度 (自动计算以满足SNR)
%      - f_j: 随机频率，均匀分布在 [f_min, f_max]
%      - φ_j: 随机初始相位，均匀分布在 [0, 2π]
%
%      InbandAvoidCarrier = true 时:
%      - 多音频率会避开FDM调制频率±GuardBand范围
%      - 模拟"带内但不与信号频率重叠"的干扰
%
% 输出:
%   v_signal    - 时域电压信号 [1 x N]
%   t           - 时间轴 [1 x N]
%   params      - 使用的参数结构体
%
% 示例:
%   % 使用多音干扰模型，避开调制频率
%   amps = rand(1, 12);
%   [v, t, p] = fdm_generate_signal(amps, 'SNR_inband_dB', 10, ...
%       'InbandNoiseMode', 'multitone', 'InbandNumTones', 30, ...
%       'InbandAvoidCarrier', true, 'InbandGuardBand', 2e3);
%
% 作者: Claude
% 日期: 2024-12

    % 旧版默认频率 (兼容)
    LEGACY_FREQS_KHZ = [118, 128, 138, 148, 158, 168, 178, 208, 218, 228];
    
    % 解析输入参数
    p = inputParser;
    addRequired(p, 'amplitudes', @isnumeric);
    addParameter(p, 'Fs', 10e6, @isnumeric);
    addParameter(p, 'N', [], @isnumeric);
    addParameter(p, 'FreqsHz', [], @isnumeric);
    addParameter(p, 'FreqMode', 'auto', @ischar);
    addParameter(p, 'T', 100e-6, @isnumeric);
    addParameter(p, 'DC', 0, @isnumeric);
    addParameter(p, 'Phases', [], @isnumeric);
    addParameter(p, 'Waveform', 'sine', @ischar);
    addParameter(p, 'MaxHarmonicFreq', 500e3, @isnumeric);
    addParameter(p, 'SNR_dB', Inf, @isnumeric);
    addParameter(p, 'SNR_inband_dB', Inf, @isnumeric);
    addParameter(p, 'InbandNoiseMode', 'gaussian', @ischar);
    addParameter(p, 'InbandNumTones', 20, @isnumeric);
    addParameter(p, 'InbandFreqRange', [30e3, 410e3], @isnumeric);
    addParameter(p, 'InbandAvoidCarrier', false, @islogical);  % 新增：是否避开调制频率
    addParameter(p, 'InbandGuardBand', 1e3, @isnumeric);       % 新增：保护带宽
    addParameter(p, 'SNR_100Hz_dB', Inf, @isnumeric);
    addParameter(p, 'NoiseMode', 'white', @ischar);
    addParameter(p, 'AmbientDC', 0, @isnumeric);
    addParameter(p, 'Ambient100Hz', 0, @isnumeric);
    addParameter(p, 'AmbientSMPS', 0, @isnumeric);
    addParameter(p, 'SMPSFreqHz', 100e3, @isnumeric);
    addParameter(p, 'NoiseRefMode', 'rms', @ischar);
    addParameter(p, 'Seed', [], @isnumeric);
    parse(p, amplitudes, varargin{:});
    
    opts = p.Results;
    amplitudes = opts.amplitudes(:)';
    num_led = length(amplitudes);
    Fs = opts.Fs;
    T = opts.T;
    
    %% 确定采样点数N
    if isempty(opts.N)
        N = round(Fs * T);
    else
        N = opts.N;
        T = N / Fs;
    end
    
    %% 确定频率
    switch lower(opts.FreqMode)
        case 'auto'
            if isempty(opts.FreqsHz)
                [freqs_Hz, freq_info] = fdm_select_frequencies(num_led, 'T', T);
            else
                freqs_Hz = opts.FreqsHz(:)';
            end
            
        case 'legacy'
            freqs_Hz = LEGACY_FREQS_KHZ(1:min(num_led, length(LEGACY_FREQS_KHZ))) * 1000;
            
        case 'custom'
            if isempty(opts.FreqsHz)
                error('FreqMode=''custom'' 时必须指定 FreqsHz');
            end
            freqs_Hz = opts.FreqsHz(:)';
            
        otherwise
            error('未知的 FreqMode: %s', opts.FreqMode);
    end
    
    if length(freqs_Hz) < num_led
        error('频率数量(%d)少于幅度数量(%d)', length(freqs_Hz), num_led);
    elseif length(freqs_Hz) > num_led
        freqs_Hz = freqs_Hz(1:num_led);
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
    
    harmonic_info = struct('num_harmonics', 0, 'max_order', 1);
    total_harmonics = 0;
    max_harmonic_order = 1;
    
    switch lower(opts.Waveform)
        case 'sine'
            for i = 1:num_led
                v_signal = v_signal + amplitudes(i) * sin(2*pi*freqs_Hz(i)*t + phases(i));
            end
            
        case 'square'
            for i = 1:num_led
                f0 = freqs_Hz(i);
                n_max = floor(f_max_harmonic / f0);
                max_harmonic_order = max(max_harmonic_order, n_max);
                
                for n = 1:n_max
                    f_harmonic = n * f0;
                    if f_harmonic <= f_max_harmonic
                        v_signal = v_signal + amplitudes(i) * (1/n) * sin(2*pi*f_harmonic*t + n*phases(i));
                        total_harmonics = total_harmonics + 1;
                    end
                end
            end
            
        case 'square_odd'
            for i = 1:num_led
                f0 = freqs_Hz(i);
                n_max = floor(f_max_harmonic / f0);
                max_harmonic_order = max(max_harmonic_order, n_max);
                
                for n = 1:2:n_max
                    f_harmonic = n * f0;
                    if f_harmonic <= f_max_harmonic
                        v_signal = v_signal + amplitudes(i) * (4/pi) * (1/n) * sin(2*pi*f_harmonic*t + n*phases(i));
                        total_harmonics = total_harmonics + 1;
                    end
                end
            end
            
        otherwise
            error('未知的 Waveform: %s', opts.Waveform);
    end
    
    harmonic_info.num_harmonics = total_harmonics;
    harmonic_info.max_order = max_harmonic_order;
    
    %% 添加噪声
    noise_total = zeros(1, N);
    
    % 计算噪声参考基准
    switch lower(opts.NoiseRefMode)
        case 'mean'
            signal_ref = mean(abs(amplitudes));
        case 'sum'
            signal_ref = sum(abs(amplitudes));
        case 'rms'
            signal_ref = rms(v_signal - opts.DC);
        otherwise
            signal_ref = rms(v_signal - opts.DC);
    end
    
    signal_power = var(v_signal - opts.DC);
    
    %% === DC环境光 ===
    if opts.AmbientDC > 0
        dc_amplitude = opts.AmbientDC * signal_ref;
        noise_total = noise_total + dc_amplitude;
    end
    
    %% === 100Hz工频干扰 ===
    if ~isinf(opts.SNR_100Hz_dB)
        noise_power_100hz = signal_power / (10^(opts.SNR_100Hz_dB/10));
        hz100_amplitude = sqrt(2 * noise_power_100hz);
        
        if ~isempty(opts.Seed)
            phase_100hz = 0;
        else
            phase_100hz = 2 * pi * rand();
        end
        
        noise_100hz = hz100_amplitude * sin(2*pi*100*t + phase_100hz);
        noise_100hz = noise_100hz + hz100_amplitude * 0.3 * sin(2*pi*200*t + phase_100hz);
        noise_100hz = noise_100hz + hz100_amplitude * 0.1 * sin(2*pi*300*t + phase_100hz);
        
        actual_power = var(noise_100hz);
        noise_100hz = noise_100hz * sqrt(noise_power_100hz / actual_power);
        
        noise_total = noise_total + noise_100hz;
        
    elseif opts.Ambient100Hz > 0
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
    
    %% === SMPS/PWM 开关噪声 ===
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
            noise_smps = smps_amplitude * square(omega*t + phase_smps);
        else
            noise_smps = smps_amplitude * sawtooth(omega*t + phase_smps, 0.5);
        end
        
        noise_total = noise_total + noise_smps;
    end
    
    %% === 全频段白噪声 (AWGN) ===
    if ~isinf(opts.SNR_dB)
        noise_power = signal_power / (10^(opts.SNR_dB/10));
        noise_white = sqrt(noise_power) * randn(1, N);
        noise_total = noise_total + noise_white;
    end
    
    %% === 带内噪声 ===
    inband_info = struct();
    
    if ~isinf(opts.SNR_inband_dB)
        noise_power = signal_power / (10^(opts.SNR_inband_dB/10));
        f_inband_low = opts.InbandFreqRange(1);
        f_inband_high = opts.InbandFreqRange(2);
        
        switch lower(opts.InbandNoiseMode)
            case 'gaussian'
                %% 带限高斯白噪声
                noise_inband = sqrt(noise_power) * randn(1, N);
                f_low_norm = f_inband_low / (Fs/2);
                f_high_norm = min(f_inband_high / (Fs/2), 0.99);
                if f_high_norm > f_low_norm
                    [b, a] = butter(4, [f_low_norm, f_high_norm], 'bandpass');
                    noise_inband = filter(b, a, noise_inband);
                    noise_inband = noise_inband * sqrt(noise_power / var(noise_inband));
                end
                
                inband_info.mode = 'gaussian';
                inband_info.freq_range = [f_inband_low, f_inband_high];
                
            case 'multitone'
                %% 多音干扰模型
                M = opts.InbandNumTones;
                guard_band = opts.InbandGuardBand;
                avoid_carrier = opts.InbandAvoidCarrier;
                
                % 生成多音频率
                f_tones = zeros(1, M);
                
                if avoid_carrier
                    % 避开调制频率模式
                    max_attempts = 1000;  % 防止死循环
                    for j = 1:M
                        attempts = 0;
                        while attempts < max_attempts
                            f_candidate = f_inband_low + (f_inband_high - f_inband_low) * rand();
                            % 检查是否与任何调制频率太近
                            if all(abs(f_candidate - freqs_Hz) > guard_band)
                                f_tones(j) = f_candidate;
                                break;
                            end
                            attempts = attempts + 1;
                        end
                        % 如果找不到合适的频率，使用随机频率（降级处理）
                        if attempts >= max_attempts
                            f_tones(j) = f_inband_low + (f_inband_high - f_inband_low) * rand();
                            warning('无法为第%d个音调找到避开调制频率的位置，使用随机频率', j);
                        end
                    end
                else
                    % 不避开调制频率（原模式）
                    f_tones = f_inband_low + (f_inband_high - f_inband_low) * rand(1, M);
                end
                
                % 生成随机相位
                phi_tones = 2 * pi * rand(1, M);
                
                % 生成多音干扰信号
                noise_inband = zeros(1, N);
                for j = 1:M
                    noise_inband = noise_inband + cos(2*pi*f_tones(j)*t + phi_tones(j));
                end
                
                % 归一化到目标噪声功率
                current_power = var(noise_inband);
                if current_power > 0
                    noise_inband = noise_inband * sqrt(noise_power / current_power);
                end
                
                % 计算各音调的实际幅度
                A_tones = sqrt(noise_power / current_power) * ones(1, M);
                
                inband_info.mode = 'multitone';
                inband_info.num_tones = M;
                inband_info.frequencies = f_tones;
                inband_info.phases = phi_tones;
                inband_info.amplitudes = A_tones;
                inband_info.freq_range = [f_inband_low, f_inband_high];
                inband_info.avoid_carrier = avoid_carrier;
                inband_info.guard_band = guard_band;
                
            otherwise
                error('未知的 InbandNoiseMode: %s', opts.InbandNoiseMode);
        end
        
        noise_total = noise_total + noise_inband;
    end
    
    v_signal = v_signal + noise_total;
    
    %% 返回参数
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
    params.InbandNoiseMode = opts.InbandNoiseMode;
    params.InbandNumTones = opts.InbandNumTones;
    params.InbandFreqRange = opts.InbandFreqRange;
    params.InbandAvoidCarrier = opts.InbandAvoidCarrier;
    params.InbandGuardBand = opts.InbandGuardBand;
    params.InbandInfo = inband_info;
    params.SNR_100Hz_dB = opts.SNR_100Hz_dB;
    params.AmbientDC = opts.AmbientDC;
    params.Ambient100Hz = opts.Ambient100Hz;
    params.AmbientSMPS = opts.AmbientSMPS;
    params.SMPSFreqHz = opts.SMPSFreqHz;
    params.NoiseRefMode = opts.NoiseRefMode;
    params.signal_ref = signal_ref;
    params.amplitudes = amplitudes;
    
    if strcmpi(opts.FreqMode, 'auto') && exist('freq_info', 'var')
        params.freq_info = freq_info;
    end
end
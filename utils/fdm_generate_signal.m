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
%   'SNR_dB'        - 全频段白噪声信噪比dB (默认: Inf, 无噪声)
%   'SNR_inband_dB' - 带内噪声信噪比dB, 40-250kHz (默认: Inf)
%   'AmbientDC'     - DC环境光强度，相对信号的倍数 (默认: 0)
%   'Ambient100Hz'  - 100Hz灯光干扰，相对信号的倍数 (默认: 0)
%   'AmbientSMPS'   - SMPS开关噪声 (典型100kHz)，相对信号的倍数 (默认: 0)
%   'SMPSFreqHz'    - SMPS干扰频率Hz (默认: 100e3, 即100kHz)
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
% 示例:
%   % 自动选择频率（推荐）
%   amps = rand(1, 12);
%   [v, t, p] = fdm_generate_signal(amps, 'FreqMode', 'auto', 'T', 100e-6);
%   disp(p.FreqsHz / 1e3);  % 查看选择的频率(kHz)
%
%   % 使用旧版固定频率
%   [v, t] = fdm_generate_signal(amps, 'FreqMode', 'legacy');
%
%   % 自定义频率
%   freqs = [100, 150, 200] * 1e3;
%   [v, t] = fdm_generate_signal([0.1, 0.2, 0.3], 'FreqsHz', freqs);
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
    addParameter(p, 'SNR_dB', Inf, @isnumeric);        % 白噪声（全频段）
    addParameter(p, 'SNR_inband_dB', Inf, @isnumeric); % 带内噪声
    addParameter(p, 'NoiseMode', 'white', @ischar);    % 'white', 'inband', 'ambient'
    addParameter(p, 'AmbientDC', 0, @isnumeric);       % DC环境光强度
    addParameter(p, 'Ambient100Hz', 0, @isnumeric);    % 100Hz灯光干扰强度
    addParameter(p, 'AmbientSMPS', 0, @isnumeric);     % SMPS开关噪声强度
    addParameter(p, 'SMPSFreqHz', 100e3, @isnumeric);  % SMPS频率，默认100kHz
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
    
    % 生成信号: v(t) = DC + Σ a_i * sin(2πf_i*t + φ_i)
    v_signal = opts.DC * ones(1, N);
    for i = 1:num_led
        v_signal = v_signal + amplitudes(i) * sin(2*pi*freqs_Hz(i)*t + phases(i));
    end
    
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
    
    % === 带外噪声 (环境光) ===
    % DC环境光 - AmbientDC表示DC是信号的多少倍
    if opts.AmbientDC > 0
        dc_amplitude = opts.AmbientDC * signal_ref;
        noise_total = noise_total + dc_amplitude;
    end
    
    % 100Hz灯光干扰 - Ambient100Hz表示100Hz幅度是信号的多少倍
    % 注意：当T << 10ms时，100Hz信号会产生频谱泄漏
    % 实际系统可通过多次采样平均或同步采样消除
    if opts.Ambient100Hz > 0
        hz100_amplitude = opts.Ambient100Hz * signal_ref;
        % 随机初始相位（模拟真实情况）
        if ~isempty(opts.Seed)
            phase_100hz = 0;  % 固定相位便于复现
        else
            phase_100hz = 2 * pi * rand();
        end
        noise_total = noise_total + hz100_amplitude * sin(2*pi*100*t + phase_100hz);
        noise_total = noise_total + hz100_amplitude * 0.3 * sin(2*pi*200*t + phase_100hz);
        noise_total = noise_total + hz100_amplitude * 0.1 * sin(2*pi*300*t + phase_100hz);
    end
    
    % SMPS开关噪声 - 模拟LED驱动器开关电源干扰 (典型50-400kHz)
    % 这是真正的带内干扰，会直接影响FDM解调
    if opts.AmbientSMPS > 0
        smps_amplitude = opts.AmbientSMPS * signal_ref;
        smps_freq = opts.SMPSFreqHz;
        if ~isempty(opts.Seed)
            phase_smps = 0;
        else
            phase_smps = 2 * pi * rand();
        end
        % SMPS噪声：基频 + 谐波 (方波近似)
        noise_total = noise_total + smps_amplitude * sin(2*pi*smps_freq*t + phase_smps);
        noise_total = noise_total + smps_amplitude * 0.33 * sin(2*pi*2*smps_freq*t + phase_smps);  % 2次谐波
        noise_total = noise_total + smps_amplitude * 0.20 * sin(2*pi*3*smps_freq*t + phase_smps);  % 3次谐波
    end
    
    % === 全频段白噪声 (SNR定义) ===
    if ~isinf(opts.SNR_dB)
        signal_power = var(v_signal - opts.DC);
        noise_power = signal_power / (10^(opts.SNR_dB/10));
        noise_white = sqrt(noise_power) * randn(1, N);
        noise_total = noise_total + noise_white;
    end
    
    % === 带内噪声 (SNR定义, 40-250kHz) ===
    if ~isinf(opts.SNR_inband_dB)
        signal_power = var(v_signal - opts.DC);
        noise_power = signal_power / (10^(opts.SNR_inband_dB/10));
        
        % 生成带限噪声
        noise_inband = sqrt(noise_power) * randn(1, N);
        f_low = 40e3 / (Fs/2);
        f_high = min(250e3 / (Fs/2), 0.99);
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
    params.DC = opts.DC;
    params.Phases = phases;
    params.SNR_dB = opts.SNR_dB;
    params.SNR_inband_dB = opts.SNR_inband_dB;
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
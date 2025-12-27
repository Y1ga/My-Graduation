function [amplitudes, info] = extract_freq_amplitudes(csv_file, target_freqs, varargin)
% EXTRACT_FREQ_AMPLITUDES 从CSV文件提取指定频率的FFT幅度
%
% 输入：
%   csv_file     - 示波器CSV文件路径
%   target_freqs - 目标频率 (kHz)
%
% 可选参数：
%   'Duration'      - 截取时长(μs)，默认 100
%   'UseWindow'     - 是否使用窗函数，默认 false
%   'SquareWaveCompensation' - 方波补偿，默认 true
%
% 输出：
%   amplitudes - 各频率幅度 [n × 1]
%   info       - 结构体

    p = inputParser;
    p.addRequired('csv_file');
    p.addRequired('target_freqs', @isnumeric);
    p.addParameter('Duration', 100, @isnumeric);
    p.addParameter('UseWindow', false, @islogical);
    p.addParameter('SquareWaveCompensation', true, @islogical);  % 新增
    p.parse(csv_file, target_freqs, varargin{:});
    opts = p.Results;
    
    %% 读取CSV头部获取采样参数
    fid = fopen(csv_file, 'r');
    if fid == -1
        error('无法打开文件: %s', csv_file);
    end
    fgetl(fid);
    line2 = fgetl(fid);
    fclose(fid);
    
    parts = strsplit(line2, ',');
    dt = str2double(parts{4});
    fs = 1 / dt;
    
    %% 读取电压数据
    data = readmatrix(csv_file, 'NumHeaderLines', 2);
    voltage = data(:, 2);
    voltage = voltage(~isnan(voltage));
    N_original = length(voltage);
    T_original = N_original * dt;
    
    %% 截取指定时长
    N_target = round(opts.Duration * 1e-6 * fs);
    
    if N_original >= N_target
        voltage = voltage(1:N_target);
        truncated = true;
    else
        warning('数据长度不足，使用全部数据');
        N_target = N_original;
        truncated = false;
    end
    
    N = length(voltage);
    T = N * dt;
    df = 1 / T;
    
    %% 去除直流分量
    voltage_ac = voltage - mean(voltage);
    
    %% 可选：应用窗函数
    if opts.UseWindow
        win = hanning(N);
        voltage_ac = voltage_ac .* win;
        voltage_ac = voltage_ac * 2;
    end
    
    %% FFT
    Y = fft(voltage_ac);
    P = 2 * abs(Y(1:floor(N/2)+1)) / N;
    f = (0:floor(N/2)) * df;
    
    %% 提取各频率幅度
    target_freqs = target_freqs(:)';
    amplitudes = zeros(length(target_freqs), 1);
    bin_indices = zeros(length(target_freqs), 1);
    
    for i = 1:length(target_freqs)
        target_hz = target_freqs(i) * 1000;
        
        expected_bin = target_hz / df;
        
        if abs(expected_bin - round(expected_bin)) < 0.01
            idx = round(expected_bin) + 1;
        else
            [~, idx] = min(abs(f - target_hz));
        end
        
        bin_indices(i) = idx;
        amplitudes(i) = P(idx);
    end
    
    %% 方波补偿（关键！）
    % 方波基频幅度 = 原始幅度 × 2/π
    % 所以需要乘以 π/2 来还原
    if opts.SquareWaveCompensation
        amplitudes = amplitudes * (pi / 2);
    end
    
    %% 输出信息
    if nargout >= 2
        info.fs = fs;
        info.dt = dt;
        info.N = N;
        info.N_original = N_original;
        info.T = T;
        info.T_original = T_original;
        info.df = df;
        info.f = f;
        info.P = P;
        info.voltage = voltage;
        info.truncated = truncated;
        info.duration = opts.Duration;
        info.use_window = opts.UseWindow;
        info.square_wave_compensation = opts.SquareWaveCompensation;
        info.target_freqs = target_freqs;
        info.bin_indices = bin_indices;
    end
end

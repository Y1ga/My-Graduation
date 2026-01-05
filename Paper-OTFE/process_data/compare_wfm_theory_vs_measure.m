clear; 
clc;
%% 
A0 = load_mat("led_0711", "gt")';
colorchecker = load_mat("colorchecker", "gt");
idx = 17;
x = colorchecker(:, idx);
%% 
% -1,0是白板,
% 1~24对应24色卡
path = "./data/PD-01-04/";
k_A = read_rigol_wfm(path+"新建文件-1.wfm", 1e9, 1000e-6);
A = k_A .* A0;
y_measured = read_rigol_wfm(path+"新建文件"+num2str(idx)+".wfm", 1e9, 1000e-6);
y_theory = A * x;
%% 
figure(1);
y_measured_norm = y_measured ./ max(y_measured);
y_theory_norm = y_theory ./ max(y_theory);
plot(y_measured_norm);
hold on;
plot(y_theory_norm);
legend('测量值','理论值');
hold off;
%% 
% 1. 计算点对点的相对误差 (得到一个 12x1 的向量)
rel_error = abs(y_measured_norm - y_theory_norm) ./ abs(y_theory_norm);

% 2. 如果你想看平均相对误差 (百分比形式)
mean_rel_error = mean(rel_error) * 100;

% 3. 输出结果
fprintf('平均相对误差为: %.2f%%\n', mean_rel_error);
%% 
figure(2);
k_beta = max(y_theory,[],'all') / max(y_measured,[],'all') ;
% k_beta = 1;
y = y_measured * k_beta;
x_est = fdm_reconstruct(y, A, 'Method', 'tv');
wav = 400:10:700;
plot(wav, x_est,wav, x);
legend('预测','真实');
ylim([0,1]);
%% 
function [amps, freq_detected] = read_rigol_wfm(filename, fs, duration)
% READ_RIGOL_WFM 从 Rigol DS1202Z-E 的 WFM 文件中提取12个LED的幅度值
%
% 输入:
%   filename - WFM 文件路径
%   fs       - 采样率 (Hz), 默认 1e9 (1 GSa/s)
%   duration - 分析时长 (s), 默认 inf (使用全部数据)
%              例如 120e-6 表示只分析前 120 μs
%
% 输出:
%   amps         - 12x1 向量, 各LED频率处的FFT幅度
%   freq_detected - 12x1 向量, 实际检测到的峰值频率 (kHz)
%
% 示例:
%   [amps, freqs] = read_rigol_wfm('新建文件2.wfm');
%   [amps, freqs] = read_rigol_wfm('新建文件2.wfm', 1e9, 120e-6);  % 只分析前120μs

    if nargin < 2 || isempty(fs)
        fs = 1e9;  % 默认 1 GSa/s
    end
    if nargin < 3 || isempty(duration)
        duration = inf;  % 默认使用全部数据
    end

    % 12个LED的调制频率 (kHz)
    led_freqs = [30, 50, 70, 110, 130, 170, 190, 230, 290, 310, 370, 410];
    n_leds = length(led_freqs);

    %% 读取 WFM 文件
    fid = fopen(filename, 'rb');
    if fid == -1
        error('无法打开文件: %s', filename);
    end

    % 读取电压刻度 (偏移 0xA0, float32)
    fseek(fid, hex2dec('A0'), 'bof');
    volt_scale = fread(fid, 1, 'float32');

    % 跳过头部 (3334 bytes), 读取数据
    header_size = 3334;
    fseek(fid, header_size, 'bof');
    raw_data = fread(fid, inf, 'uint8');
    fclose(fid);

    % 转换为电压
    signal = (double(raw_data) - 128) * volt_scale;
    
    %% 截取指定时长
    n_total = length(signal);
    if isfinite(duration)
        n_use = min(round(duration * fs), n_total);
        signal = signal(1:n_use);
        actual_duration = n_use / fs;
        fprintf('读取 %s: %d/%d 点 (%.1f μs), 电压范围 [%.3f, %.3f] V\n', ...
            filename, n_use, n_total, actual_duration*1e6, min(signal), max(signal));
    else
        actual_duration = n_total / fs;
        fprintf('读取 %s: %d 点 (%.1f ms), 电压范围 [%.3f, %.3f] V\n', ...
            filename, n_total, actual_duration*1e3, min(signal), max(signal));
    end

    %% FFT 分析
    % 去除直流分量
    signal_ac = signal - mean(signal);

    % FFT
    n = length(signal_ac);
    n_fft = 2^nextpow2(n);
    fft_result = fft(signal_ac, n_fft);
    fft_mag = abs(fft_result(1:n_fft/2));
    freq_axis = (0:n_fft/2-1) * fs / n_fft / 1e3;  % kHz
    freq_resolution = fs / n_fft / 1e3;  % kHz
    
    fprintf('FFT: %d 点, 频率分辨率 %.2f kHz\n', n_fft, freq_resolution);

    %% 提取各LED频率的幅度
    amps = zeros(n_leds, 1);
    freq_detected = zeros(n_leds, 1);
    
    % 搜索窗口至少为频率分辨率的2倍，或 ±5 kHz
    search_width = max(5, freq_resolution * 2);

    for i = 1:n_leds
        f_target = led_freqs(i);  % kHz
        % 在目标频率 ± search_width 范围内找峰值
        mask = (freq_axis >= f_target - search_width) & (freq_axis <= f_target + search_width);
        [max_val, max_idx] = max(fft_mag .* mask');
        amps(i) = max_val;
        freq_detected(i) = freq_axis(max_idx);
    end

    %% 显示结果
    fprintf('\nLED幅度提取结果:\n');
    fprintf('%-6s %-12s %-12s %-12s\n', 'LED', '期望频率', '检测频率', '幅度');
    fprintf('%s\n', repmat('-', 1, 45));
    for i = 1:n_leds
        fprintf('%-6d %-12.0f %-12.1f %-12.2f\n', ...
            i, led_freqs(i), freq_detected(i), amps(i));
    end
end
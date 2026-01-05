%% FDM 仿真 vs 真实测量 对比验证
% 对比三者：仿真解调、真实测量解调、理论值
clear; clc;

%% 1. 参数设置
path = "./data/PD-01-04/";
duration = 300e-6;  % 300 μs
fs = 1e9;           % 1 GSa/s
idx = 18;           % 色卡编号

%% 2. 加载数据
A0 = load_mat("led_0711", "gt")';
colorchecker = load_mat("colorchecker", "gt");
x = colorchecker(:, idx);

% 加载系统增益 (从白板测量获得)
k_A = read_rigol_wfm(path + "新建文件-1.wfm", fs, duration);
A = k_A .* A0;

%% 3. 三种结果
% 3.1 理论值
y_theory = A * x;

% 3.2 真实测量解调
y_measured = read_rigol_wfm(path + "新建文件" + num2str(idx) + ".wfm", fs, duration);

% 3.3 仿真信号解调
snr_db = inf;  % 无噪声
[signal_sim, t] = generate_fdm_signal(A, x, fs, duration, snr_db);
y_sim = extract_fdm_amps(signal_sim, fs);

fprintf('\n仿真信号: %d 点, %.1f μs\n', length(signal_sim), duration*1e6);

%% 4. 归一化对比
y_theory_norm = y_theory / max(y_theory);
y_measured_norm = y_measured / max(y_measured);
y_sim_norm = y_sim / max(y_sim);

%% 5. 计算误差
err_sim_vs_theory = mean(abs(y_sim_norm - y_theory_norm) ./ abs(y_theory_norm)) * 100;
err_meas_vs_theory = mean(abs(y_measured_norm - y_theory_norm) ./ abs(y_theory_norm)) * 100;
err_sim_vs_meas = mean(abs(y_sim_norm - y_measured_norm) ./ abs(y_measured_norm)) * 100;

%% 6. 打印结果
fprintf('\n==================== 对比结果 ====================\n');
fprintf('%-6s %-12s %-12s %-12s\n', 'CH', '理论(归一)', '仿真(归一)', '测量(归一)');
fprintf('%s\n', repmat('-', 1, 54));
for i = 1:12
    fprintf('%-6d %-12.4f %-12.4f %-12.4f\n', i, y_theory_norm(i), y_sim_norm(i), y_measured_norm(i));
end
fprintf('%s\n', repmat('-', 1, 54));

fprintf('\n==================== 误差统计 ====================\n');
fprintf('仿真 vs 理论:  %.2f%%\n', err_sim_vs_theory);
fprintf('测量 vs 理论:  %.2f%%\n', err_meas_vs_theory);
fprintf('仿真 vs 测量:  %.2f%%\n', err_sim_vs_meas);
fprintf('==================================================\n');

%% 7. 可视化
figure(1); clf;

% 7.1 三者柱状图对比
subplot(2,3,1);
bar([y_theory_norm, y_sim_norm, y_measured_norm]);
xlabel('通道'); ylabel('归一化幅度');
legend('理论', '仿真', '测量', 'Location', 'best');
title('三者对比 (归一化)');
grid on;

% 7.2 仿真 vs 理论
subplot(2,3,2);
plot(y_theory_norm, y_sim_norm, 'bo', 'MarkerSize', 8, 'LineWidth', 1.5);
hold on;
plot([0, 1], [0, 1], 'r--', 'LineWidth', 1);
xlabel('理论值'); ylabel('仿真值');
title(sprintf('仿真 vs 理论 (误差 %.2f%%)', err_sim_vs_theory));
axis equal; grid on; xlim([0,1]); ylim([0,1]);

% 7.3 测量 vs 理论
subplot(2,3,3);
plot(y_theory_norm, y_measured_norm, 'go', 'MarkerSize', 8, 'LineWidth', 1.5);
hold on;
plot([0, 1], [0, 1], 'r--', 'LineWidth', 1);
xlabel('理论值'); ylabel('测量值');
title(sprintf('测量 vs 理论 (误差 %.2f%%)', err_meas_vs_theory));
axis equal; grid on; xlim([0,1]); ylim([0,1]);

% 7.4 仿真 vs 测量
subplot(2,3,4);
plot(y_measured_norm, y_sim_norm, 'mo', 'MarkerSize', 8, 'LineWidth', 1.5);
hold on;
plot([0, 1], [0, 1], 'r--', 'LineWidth', 1);
xlabel('测量值'); ylabel('仿真值');
title(sprintf('仿真 vs 测量 (误差 %.2f%%)', err_sim_vs_meas));
axis equal; grid on; xlim([0,1]); ylim([0,1]);

% 7.5 仿真时域信号
subplot(2,3,5);
plot(t*1e6, signal_sim);
xlabel('时间 (μs)'); ylabel('幅值');
title('仿真时域信号（方波调制）');
xlim([0, 50]);
grid on;

% 7.6 仿真频谱
subplot(2,3,6);
n_fft = 2^nextpow2(length(signal_sim));
fft_mag = abs(fft(signal_sim - mean(signal_sim), n_fft));
freq_axis = (0:n_fft/2-1) * fs / n_fft / 1e3;
plot(freq_axis, fft_mag(1:n_fft/2));
xlabel('频率 (kHz)'); ylabel('幅度');
title('仿真频谱');
xlim([0, 500]);
grid on;

sgtitle(sprintf('FDM 仿真 vs 测量 对比 (色卡 #%d, %.0f μs)', idx, duration*1e6));

%% ==================== 函数定义 ====================

function [signal, t] = generate_fdm_signal(A, x, fs, duration, snr_db)
% GENERATE_FDM_SIGNAL 生成FDM调制信号（方波调制）
%
% 输入:
%   A        - 系统矩阵 (12×31)
%   x        - 待测光谱 (31×1)
%   fs       - 采样率 (Hz)
%   duration - 信号时长 (s)
%   snr_db   - 信噪比 (dB), inf 表示无噪声
%
% 输出:
%   signal   - 时域电压信号
%   t        - 时间轴

    if nargin < 3 || isempty(fs), fs = 1e9; end
    if nargin < 4 || isempty(duration), duration = 1e-3; end
    if nargin < 5 || isempty(snr_db), snr_db = inf; end

    % 12个LED调制频率 (Hz)
    led_freqs = [30, 50, 70, 110, 130, 170, 190, 230, 290, 310, 370, 410] * 1e3;
    N_led = length(led_freqs);
    
    % 计算各LED通道的强度
    I_led = A * x;  % [12×1]
    
    % 生成时间轴
    N_points = round(fs * duration);
    t = (0:N_points-1)' / fs;
    
    % 生成方波调制矩阵
    modulation_matrix = zeros(N_led, N_points);
    for k = 1:N_led
        sq_wave = square(2 * pi * led_freqs(k) * t');
        modulation_matrix(k, :) = (sq_wave + 1) / 2;  % 归一化到 [0, 1]
    end
    
    % 叠加各LED信号
    signal = (I_led' * modulation_matrix)';  % [N_points × 1]
    
    % 添加高斯白噪声
    if isfinite(snr_db)
        sig_power = mean(signal.^2);
        noise_power = sig_power / (10^(snr_db/10));
        noise = sqrt(noise_power) * randn(size(signal));
        signal = signal + noise;
    end
end

function amps = extract_fdm_amps(signal, fs)
% EXTRACT_FDM_AMPS 从时域信号中提取各LED频率的幅度
% (与 read_rigol_wfm 保持一致的搜索逻辑)

    % 12个LED调制频率 (kHz)
    led_freqs = [30, 50, 70, 110, 130, 170, 190, 230, 290, 310, 370, 410];
    n_leds = length(led_freqs);
    
    % 去直流
    signal_ac = signal - mean(signal);
    
    % FFT
    n = length(signal_ac);
    n_fft = 2^nextpow2(n);
    fft_result = fft(signal_ac, n_fft);
    fft_mag = abs(fft_result(1:n_fft/2));
    freq_axis = (0:n_fft/2-1) * fs / n_fft / 1e3;  % kHz
    freq_resolution = fs / n_fft / 1e3;  % kHz
    
    % 搜索窗口 (与 read_rigol_wfm 一致)
    search_width = max(5, freq_resolution * 2);
    
    % 提取各频率幅度
    amps = zeros(n_leds, 1);
    for i = 1:n_leds
        f_target = led_freqs(i);  % kHz
        mask = (freq_axis >= f_target - search_width) & (freq_axis <= f_target + search_width);
        amps(i) = max(fft_mag .* mask');
    end
end

function [amps, freq_detected] = read_rigol_wfm(filename, fs, duration)
% READ_RIGOL_WFM 从 Rigol DS1202Z-E 的 WFM 文件中提取12个LED的幅度值

    if nargin < 2 || isempty(fs), fs = 1e9; end
    if nargin < 3 || isempty(duration), duration = inf; end

    led_freqs = [30, 50, 70, 110, 130, 170, 190, 230, 290, 310, 370, 410];
    n_leds = length(led_freqs);

    % 读取 WFM 文件
    fid = fopen(filename, 'rb');
    if fid == -1, error('无法打开文件: %s', filename); end

    fseek(fid, hex2dec('A0'), 'bof');
    volt_scale = fread(fid, 1, 'float32');

    header_size = 3334;
    fseek(fid, header_size, 'bof');
    raw_data = fread(fid, inf, 'uint8');
    fclose(fid);

    signal = (double(raw_data) - 128) * volt_scale;
    
    % 截取指定时长
    n_total = length(signal);
    if isfinite(duration)
        n_use = min(round(duration * fs), n_total);
        signal = signal(1:n_use);
        fprintf('读取 %s: %d/%d 点 (%.1f μs)\n', filename, n_use, n_total, n_use/fs*1e6);
    else
        fprintf('读取 %s: %d 点 (%.1f ms)\n', filename, n_total, n_total/fs*1e3);
    end

    % FFT
    signal_ac = signal - mean(signal);
    n = length(signal_ac);
    n_fft = 2^nextpow2(n);
    fft_result = fft(signal_ac, n_fft);
    fft_mag = abs(fft_result(1:n_fft/2));
    freq_axis = (0:n_fft/2-1) * fs / n_fft / 1e3;
    freq_resolution = fs / n_fft / 1e3;

    % 提取幅度
    amps = zeros(n_leds, 1);
    freq_detected = zeros(n_leds, 1);
    search_width = max(5, freq_resolution * 2);

    for i = 1:n_leds
        f_target = led_freqs(i);
        mask = (freq_axis >= f_target - search_width) & (freq_axis <= f_target + search_width);
        [max_val, max_idx] = max(fft_mag .* mask');
        amps(i) = max_val;
        freq_detected(i) = freq_axis(max_idx);
    end
end
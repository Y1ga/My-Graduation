%% FDM 信号仿真验证（方波调制）
% 验证流程: x -> 生成WFM信号 -> FFT解调 -> 对比理论值 y = A*x
clear; clc;

%% 1. 加载数据
A0 = load_mat("led_0711", "gt")';
colorchecker = load_mat("colorchecker", "gt");
idx = 21;
x = colorchecker(:, idx);

% 加载系统增益 (从白板测量获得)
path = "./data/PD-01-04/";
duration = 300e-6;  % 300 μs
fs = 1e9;           % 1 GSa/s
k_A = read_rigol_wfm(path + "新建文件-1.wfm", fs, duration);
A = k_A .* A0;

%% 2. 理论值
y_theory = A * x;

%% 3. 仿真生成信号并解调
snr_db = inf;  % 先用无噪声测试
[signal, t] = generate_fdm_signal(A, x, fs, duration, snr_db);
y_sim = extract_fdm_amps(signal, fs);

fprintf('仿真信号: %d 点, %.1f μs\n', length(signal), duration*1e6);

%% 4. 对比结果 (归一化后比较)
y_theory_norm = y_theory / max(y_theory);
y_sim_norm = y_sim / max(y_sim);

fprintf('\n========== 仿真验证结果 ==========\n');
fprintf('%-6s %-12s %-12s %-12s\n', 'CH', '理论(归一)', '仿真(归一)', '相对误差(%)');
fprintf('%s\n', repmat('-', 1, 48));
for i = 1:12
    rel_err = abs(y_sim_norm(i) - y_theory_norm(i)) / abs(y_theory_norm(i)) * 100;
    fprintf('%-6d %-12.4f %-12.4f %-12.2f\n', i, y_theory_norm(i), y_sim_norm(i), rel_err);
end

mean_err = mean(abs(y_sim_norm - y_theory_norm) ./ abs(y_theory_norm)) * 100;
fprintf('%s\n', repmat('-', 1, 48));
fprintf('平均相对误差: %.2f%%\n', mean_err);
fprintf('===================================\n');

%% 5. 可视化
figure(1); clf;
subplot(2,2,1);
plot(t*1e6, signal);
xlabel('时间 (μs)'); ylabel('电压');
title('仿真时域信号（方波调制）'); xlim([0, 50]);

subplot(2,2,2);
n_fft = 2^nextpow2(length(signal));
fft_mag = abs(fft(signal - mean(signal), n_fft));
freq_axis = (0:n_fft/2-1) * fs / n_fft / 1e3;
plot(freq_axis, fft_mag(1:n_fft/2));
xlabel('频率 (kHz)'); ylabel('幅度');
title('频谱'); xlim([0, 500]);

subplot(2,2,3);
bar([y_theory_norm, y_sim_norm]);
xlabel('通道'); ylabel('归一化幅度');
legend('理论值', '仿真解调');
title('通道幅度对比 (归一化)');

subplot(2,2,4);
plot(y_theory_norm, y_sim_norm, 'o', 'MarkerSize', 8);
hold on;
plot([0, 1], [0, 1], 'r--');
xlabel('理论值 (归一化)'); ylabel('仿真解调 (归一化)');
title(sprintf('线性相关 (误差 %.2f%%)', mean_err));
axis equal; grid on; xlim([0,1]); ylim([0,1]);

%% ==================== 函数定义 ====================

function [signal, t] = generate_fdm_signal(A, x, fs, duration, snr_db)
% GENERATE_FDM_SIGNAL 生成FDM调制信号（方波调制）
%
% 输入:
%   A        - 系统矩阵 (12×31)
%   x        - 待测光谱 (31×1)
%   fs       - 采样率 (Hz), 默认 1e9
%   duration - 信号时长 (s), 默认 1e-3
%   snr_db   - 信噪比 (dB), 默认 inf (无噪声)
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
%
% 输入:
%   signal - 时域信号
%   fs     - 采样率 (Hz)
%
% 输出:
%   amps   - 12×1 向量, 各频率处的幅度

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
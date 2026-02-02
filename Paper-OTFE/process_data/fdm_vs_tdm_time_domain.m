%% TDM vs FDM 时域信号对比
% 绘制无噪声和25dB SNR下的TDM和FDM时域信号
clear; clc; close all;

%% 加载数据
A0 = load_mat("led_0711", "gt");
colorchecker = load_mat("colorchecker_trans_0118", "gt");

if size(A0,1) == 31, A0 = A0'; end
if size(colorchecker,1) == 31, colorchecker = colorchecker'; end

working_leds = 1:12;
A0_working = A0(working_leds, :);
x_gt = colorchecker(15, :)';
y_theory = A0_working * x_gt;

N_LED = length(working_leds);

%% 公共参数
Fs = 10e6;
T_total = 100e-6;

T_fdm = T_total;
N_fdm = round(Fs * T_fdm);
T_slot = T_total / N_LED;
N_slot = round(Fs * T_slot);
N_total = N_LED * N_slot;

SNR_dB = 25;  % 噪声信噪比

%% 图形参数
FONTSIZE = 16;
FONTSIZE_LEGEND = 13;
FONTSIZE_TICK = 14;
MARKER_SIZE = 7;
SHOW_GRID = false;

% 颜色定义
color_fdm_clean = [0.20, 0.45, 0.70];     % 蓝色 - FDM无噪声
color_tdm_clean = [0.85, 0.35, 0.25];     % 红色 - TDM无噪声
color_fdm_noisy = [0.30, 0.70, 0.50];     % 绿色 - FDM有噪声
color_tdm_noisy = [0.80, 0.50, 0.20];     % 橙色 - TDM有噪声

%% 生成FDM信号
% 无噪声
[v_fdm_clean, t_fdm, params_fdm] = fdm_generate_signal(y_theory, ...
    'FreqMode', 'auto', 'T', T_fdm, 'Fs', Fs, ...
    'SNR_dB', Inf, 'Seed', 1, 'Waveform', 'sine');

% 有噪声 (25dB)
[v_fdm_noisy, ~, ~] = fdm_generate_signal(y_theory, ...
    'FreqMode', 'auto', 'T', T_fdm, 'Fs', Fs, ...
    'SNR_dB', SNR_dB, 'Seed', 1, 'Waveform', 'sine');

%% 生成TDM信号
t_tdm = (0:N_total-1) / Fs;
P_signal_fdm = var(v_fdm_clean);
noise_variance = P_signal_fdm / (10^(SNR_dB/10));
noise_std = sqrt(noise_variance);

% 无噪声TDM
v_tdm_clean = zeros(1, N_total);
for i = 1:N_LED
    idx_start = (i-1) * N_slot + 1;
    idx_end = i * N_slot;
    v_tdm_clean(idx_start:idx_end) = y_theory(i);
end

% 有噪声TDM (25dB)
rng(1);
v_tdm_noisy = v_tdm_clean + noise_std * randn(1, N_total);

%% 绘图
fig = figure('Position', [100, 100, 800, 500], 'Color', 'w');
hold on; box on;

% 转换时间为微秒
t_fdm_us = t_fdm * 1e6;
t_tdm_us = t_tdm * 1e6;

% 绘制曲线（按顺序：先画有噪声的在底层，再画无噪声的在上层）
h4 = plot(t_tdm_us, v_tdm_noisy, '-', 'LineWidth', 1.0, 'Color', [color_tdm_noisy, 0.7]);
h3 = plot(t_fdm_us, v_fdm_noisy, '-', 'LineWidth', 1.0, 'Color', [color_fdm_noisy, 0.7]);
h2 = plot(t_tdm_us, v_tdm_clean, '-', 'LineWidth', 1.5, 'Color', color_tdm_clean);
h1 = plot(t_fdm_us, v_fdm_clean, '-', 'LineWidth', 1.5, 'Color', color_fdm_clean);

xlabel('Time (μs)', 'FontSize', FONTSIZE, 'FontName', 'Arial');
ylabel('Voltage (a.u.)', 'FontSize', FONTSIZE, 'FontName', 'Arial');

leg = legend([h1, h2, h3, h4], ...
    {'FDM (Clean)', 'TDM (Clean)', sprintf('FDM (%ddB)', SNR_dB), sprintf('TDM (%ddB)', SNR_dB)}, ...
    'Location', 'northeast', 'FontSize', FONTSIZE_LEGEND, 'NumColumns', 2);
leg.Box = 'off';

set(gca, 'FontSize', FONTSIZE_TICK, 'FontName', 'Arial', 'LineWidth', 1.0);
if SHOW_GRID
    grid on;
    set(gca, 'GridLineStyle', ':', 'GridAlpha', 0.3);
end
xlim([0, T_total*1e6]);

%% 保存
savename = 'fig_tdm_vs_fdm_timedomain';
print(gcf, savename, '-dpng', '-r300');
print(gcf, savename, '-depsc', '-r300');
fprintf('Saved: %s.png and %s.eps\n', savename, savename);

%% 打印信息
fprintf('\n============================================================\n');
fprintf('时域信号参数\n');
fprintf('============================================================\n');
fprintf('总时间: %.0f μs\n', T_total*1e6);
fprintf('采样率: %.0f MHz\n', Fs/1e6);
fprintf('FDM采样点数: %d\n', N_fdm);
fprintf('TDM采样点数: %d (每时隙 %d 点)\n', N_total, N_slot);
fprintf('SNR: %d dB\n', SNR_dB);
fprintf('FDM调制频率: %.0f - %.0f kHz\n', min(params_fdm.FreqsHz)/1e3, max(params_fdm.FreqsHz)/1e3);
fprintf('============================================================\n');
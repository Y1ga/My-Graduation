%% FDM论文仿真：时域信号对比图
% Figure 1: MODE 1-3 影响大的噪声 (白噪声、带内随机、100Hz工频)
% Figure 2: MODE 4-6 影响小的噪声 10x (DC环境光、PWM 20kHz、SMPS 100kHz)
% Figure 3: MODE 4-6 影响小的噪声 1000x (DC环境光、PWM 20kHz、SMPS 100kHz)
clear; clc; close all;

%% 加载数据
A0 = load_mat("led_0711", "gt");
colorchecker = load_mat("colorchecker", "gt");

if size(A0,1) == 31, A0 = A0'; end
if size(colorchecker,1) == 31, colorchecker = colorchecker'; end

working_leds = [1,2,3,4,5,6,7,10,11,12];
A0_working = A0(working_leds, :);
x_gt = colorchecker(16, :)';
y_theory = A0_working * x_gt;

%% 统一设置
FIG_WIDTH = 1200;
FIG_HEIGHT = 700;
FONTSIZE = 14;
FONTSIZE_LEGEND = 10;
FONTSIZE_TICK = 12;
LINE_WIDTH = 1.0;

% 显示选项
SHOW_TITLE = true;  % true: 显示标题, false: 不显示标题

% 时间显示范围 (μs)
T_DISPLAY = 50;  % 显示前50μs

%% 噪声参数
% === 影响大的噪声 (MODE 1-3) ===
SNR_WHITE = 20;       % 白噪声 SNR (dB)
SNR_INBAND = 30;      % 带内噪声 SNR (dB)
AMBIENT_100HZ = 10;   % 100Hz噪声倍数 (高影响！)

% === 影响小的噪声 (MODE 4-6) ===
AMBIENT_SMPS_10x = 10;      % SMPS噪声 10x
AMBIENT_PWM_10x = 10;       % PWM噪声 10x
AMBIENT_DC_10x = 10;        % DC噪声 10x

AMBIENT_SMPS_1000x = 1000;  % SMPS噪声 1000x
AMBIENT_PWM_1000x = 1000;   % PWM噪声 1000x
AMBIENT_DC_1000x = 1000;    % DC噪声 1000x

SMPS_FREQ = 100e3;    % SMPS频率 100kHz
PWM_FREQ = 20e3;      % PWM频率 20kHz

%% 生成信号
% 1. 无噪声信号
[v_clean, t, params] = fdm_generate_signal(y_theory, ...
    'FreqMode', 'auto', 'SNR_dB', Inf, 'Seed', 42);

% === 影响大的噪声 (MODE 1-3) ===
% 2. 白噪声信号 (MODE 1)
[v_white, ~, ~] = fdm_generate_signal(y_theory, ...
    'FreqMode', 'auto', 'SNR_dB', SNR_WHITE, 'Seed', 42);
noise_white = v_white - v_clean;

% 3. 带内噪声信号 (MODE 2)
[v_inband, ~, ~] = fdm_generate_signal(y_theory, ...
    'FreqMode', 'auto', 'SNR_dB', Inf, 'SNR_inband_dB', SNR_INBAND, 'Seed', 42);
noise_inband = v_inband - v_clean;

% 4. 100Hz噪声信号 (MODE 3, 高影响)
[v_100hz, ~, ~] = fdm_generate_signal(y_theory, ...
    'FreqMode', 'auto', 'SNR_dB', Inf, 'Ambient100Hz', AMBIENT_100HZ, 'Seed', 42);
noise_100hz = v_100hz - v_clean;

% === 影响小的噪声 10x (MODE 4-6) ===
% 5. SMPS噪声信号 10x (MODE 4, 100kHz)
[v_smps_10x, ~, ~] = fdm_generate_signal(y_theory, ...
    'FreqMode', 'auto', 'SNR_dB', Inf, 'AmbientSMPS', AMBIENT_SMPS_10x, ...
    'SMPSFreqHz', SMPS_FREQ, 'Seed', 42);
noise_smps_10x = v_smps_10x - v_clean;

% 6. PWM噪声信号 10x (MODE 5, 20kHz)
[v_pwm_10x, ~, ~] = fdm_generate_signal(y_theory, ...
    'FreqMode', 'auto', 'SNR_dB', Inf, 'AmbientSMPS', AMBIENT_PWM_10x, ...
    'SMPSFreqHz', PWM_FREQ, 'Seed', 42);
noise_pwm_10x = v_pwm_10x - v_clean;

% 7. DC噪声信号 10x (MODE 6)
[v_dc_10x, ~, ~] = fdm_generate_signal(y_theory, ...
    'FreqMode', 'auto', 'SNR_dB', Inf, 'AmbientDC', AMBIENT_DC_10x, 'Seed', 42);
noise_dc_10x = v_dc_10x - v_clean;

% === 影响小的噪声 1000x ===
% 8. SMPS噪声信号 1000x
[v_smps_1000x, ~, ~] = fdm_generate_signal(y_theory, ...
    'FreqMode', 'auto', 'SNR_dB', Inf, 'AmbientSMPS', AMBIENT_SMPS_1000x, ...
    'SMPSFreqHz', SMPS_FREQ, 'Seed', 42);
noise_smps_1000x = v_smps_1000x - v_clean;

% 9. PWM噪声信号 1000x
[v_pwm_1000x, ~, ~] = fdm_generate_signal(y_theory, ...
    'FreqMode', 'auto', 'SNR_dB', Inf, 'AmbientSMPS', AMBIENT_PWM_1000x, ...
    'SMPSFreqHz', PWM_FREQ, 'Seed', 42);
noise_pwm_1000x = v_pwm_1000x - v_clean;

% 10. DC噪声信号 1000x
[v_dc_1000x, ~, ~] = fdm_generate_signal(y_theory, ...
    'FreqMode', 'auto', 'SNR_dB', Inf, 'AmbientDC', AMBIENT_DC_1000x, 'Seed', 42);
noise_dc_1000x = v_dc_1000x - v_clean;

% 时间轴转换为μs
t_us = t * 1e6;
idx_display = t_us <= T_DISPLAY;

%% 配色
color_clean = [0.2, 0.2, 0.2];      % 深灰 - 无噪声
color_white = [0.2, 0.5, 0.7];      % 蓝色 - 白噪声
color_inband = [0.7, 0.4, 0.2];     % 橙色 - 带内噪声
color_smps = [0.8, 0.3, 0.3];       % 红色 - SMPS噪声
color_100hz = [0.6, 0.3, 0.5];      % 紫色 - 100Hz噪声
color_pwm = [0.5, 0.5, 0.7];        % 蓝紫 - PWM噪声
color_dc = [0.4, 0.6, 0.3];         % 绿色 - DC噪声

%% ========== Figure 1: 影响大的噪声 (MODE 1-3) ==========
fig1 = figure('Position', [50, 50, FIG_WIDTH, FIG_HEIGHT], 'Color', 'w');

% 第一行：纯噪声
% (a) 白噪声
subplot(2, 3, 1);
plot(t_us(idx_display), noise_white(idx_display), '-', ...
    'LineWidth', LINE_WIDTH, 'Color', color_white);
xlabel('Time (\mus)', 'FontSize', FONTSIZE);
ylabel('Amplitude', 'FontSize', FONTSIZE);
if SHOW_TITLE
    title(sprintf('(a) White Noise\n(SNR = %d dB)', SNR_WHITE), 'FontSize', FONTSIZE);
end
set(gca, 'FontSize', FONTSIZE_TICK, 'LineWidth', 0.8);
grid on; box on;
xlim([0, T_DISPLAY]);

% (b) 带内随机噪声
subplot(2, 3, 2);
plot(t_us(idx_display), noise_inband(idx_display), '-', ...
    'LineWidth', LINE_WIDTH, 'Color', color_inband);
xlabel('Time (\mus)', 'FontSize', FONTSIZE);
ylabel('Amplitude', 'FontSize', FONTSIZE);
if SHOW_TITLE
    title(sprintf('(b) In-band Noise\n(SNR = %d dB)', SNR_INBAND), 'FontSize', FONTSIZE);
end
set(gca, 'FontSize', FONTSIZE_TICK, 'LineWidth', 0.8);
grid on; box on;
xlim([0, T_DISPLAY]);

% (c) 100Hz噪声
subplot(2, 3, 3);
plot(t_us(idx_display), noise_100hz(idx_display), '-', ...
    'LineWidth', LINE_WIDTH, 'Color', color_100hz);
xlabel('Time (\mus)', 'FontSize', FONTSIZE);
ylabel('Amplitude', 'FontSize', FONTSIZE);
if SHOW_TITLE
    title(sprintf('(c) 100 Hz Noise\n(%dx Signal)', AMBIENT_100HZ), 'FontSize', FONTSIZE);
end
set(gca, 'FontSize', FONTSIZE_TICK, 'LineWidth', 0.8);
grid on; box on;
xlim([0, T_DISPLAY]);

% 第二行：信号+噪声混合
% (d) 信号 + 白噪声
subplot(2, 3, 4);
plot(t_us(idx_display), v_clean(idx_display), '-', ...
    'LineWidth', LINE_WIDTH, 'Color', color_clean, 'DisplayName', 'Clean');
hold on;
plot(t_us(idx_display), v_white(idx_display), '-', ...
    'LineWidth', LINE_WIDTH, 'Color', color_white, 'DisplayName', 'Noisy');
xlabel('Time (\mus)', 'FontSize', FONTSIZE);
ylabel('Amplitude', 'FontSize', FONTSIZE);
if SHOW_TITLE
    title('(d) Signal + White', 'FontSize', FONTSIZE);
end
legend('Location', 'best', 'FontSize', FONTSIZE_LEGEND);
set(gca, 'FontSize', FONTSIZE_TICK, 'LineWidth', 0.8);
grid on; box on;
xlim([0, T_DISPLAY]);

% (e) 信号 + 带内噪声
subplot(2, 3, 5);
plot(t_us(idx_display), v_clean(idx_display), '-', ...
    'LineWidth', LINE_WIDTH, 'Color', color_clean, 'DisplayName', 'Clean');
hold on;
plot(t_us(idx_display), v_inband(idx_display), '-', ...
    'LineWidth', LINE_WIDTH, 'Color', color_inband, 'DisplayName', 'Noisy');
xlabel('Time (\mus)', 'FontSize', FONTSIZE);
ylabel('Amplitude', 'FontSize', FONTSIZE);
if SHOW_TITLE
    title('(e) Signal + In-band', 'FontSize', FONTSIZE);
end
legend('Location', 'best', 'FontSize', FONTSIZE_LEGEND);
set(gca, 'FontSize', FONTSIZE_TICK, 'LineWidth', 0.8);
grid on; box on;
xlim([0, T_DISPLAY]);

% (f) 信号 + 100Hz噪声
subplot(2, 3, 6);
plot(t_us(idx_display), v_clean(idx_display), '-', ...
    'LineWidth', LINE_WIDTH, 'Color', color_clean, 'DisplayName', 'Clean');
hold on;
plot(t_us(idx_display), v_100hz(idx_display), '-', ...
    'LineWidth', LINE_WIDTH, 'Color', color_100hz, 'DisplayName', 'Noisy');
xlabel('Time (\mus)', 'FontSize', FONTSIZE);
ylabel('Amplitude', 'FontSize', FONTSIZE);
if SHOW_TITLE
    title('(f) Signal + 100Hz', 'FontSize', FONTSIZE);
end
legend('Location', 'best', 'FontSize', FONTSIZE_LEGEND);
set(gca, 'FontSize', FONTSIZE_TICK, 'LineWidth', 0.8);
grid on; box on;
xlim([0, T_DISPLAY]);

% 保存 Figure 1
if SHOW_TITLE
    savename1 = 'fig_signal_high_impact';
else
    savename1 = 'fig_signal_high_impact_notitle';
end
print(fig1, savename1, '-dpng', '-r300');
print(fig1, savename1, '-depsc', '-r300');
fprintf('Saved: %s.png and %s.eps\n', savename1, savename1);

%% ========== Figure 2: 影响小的噪声 10x (MODE 4-6) ==========
fig2 = figure('Position', [100, 50, FIG_WIDTH, FIG_HEIGHT], 'Color', 'w');

% 第一行：纯噪声
% (a) DC噪声 10x
subplot(2, 3, 1);
plot(t_us(idx_display), noise_dc_10x(idx_display), '-', ...
    'LineWidth', LINE_WIDTH, 'Color', color_dc);
xlabel('Time (\mus)', 'FontSize', FONTSIZE);
ylabel('Amplitude', 'FontSize', FONTSIZE);
if SHOW_TITLE
    title(sprintf('(a) DC Ambient\n(%dx Signal)', AMBIENT_DC_10x), 'FontSize', FONTSIZE);
end
set(gca, 'FontSize', FONTSIZE_TICK, 'LineWidth', 0.8);
% 简化Y轴显示
ax = gca;
ax.YAxis.Exponent = 0;
ytickformat('%.1f');
grid on; box on;
xlim([0, T_DISPLAY]);

% (b) PWM噪声 10x (20kHz)
subplot(2, 3, 2);
plot(t_us(idx_display), noise_pwm_10x(idx_display), '-', ...
    'LineWidth', LINE_WIDTH, 'Color', color_pwm);
xlabel('Time (\mus)', 'FontSize', FONTSIZE);
ylabel('Amplitude', 'FontSize', FONTSIZE);
if SHOW_TITLE
    title(sprintf('(b) PWM Noise\n(%.0f kHz, %dx)', PWM_FREQ/1e3, AMBIENT_PWM_10x), 'FontSize', FONTSIZE);
end
set(gca, 'FontSize', FONTSIZE_TICK, 'LineWidth', 0.8);
grid on; box on;
xlim([0, T_DISPLAY]);

% (c) SMPS噪声 10x (100kHz)
subplot(2, 3, 3);
plot(t_us(idx_display), noise_smps_10x(idx_display), '-', ...
    'LineWidth', LINE_WIDTH, 'Color', color_smps);
xlabel('Time (\mus)', 'FontSize', FONTSIZE);
ylabel('Amplitude', 'FontSize', FONTSIZE);
if SHOW_TITLE
    title(sprintf('(c) SMPS Noise\n(%.0f kHz, %dx)', SMPS_FREQ/1e3, AMBIENT_SMPS_10x), 'FontSize', FONTSIZE);
end
set(gca, 'FontSize', FONTSIZE_TICK, 'LineWidth', 0.8);
grid on; box on;
xlim([0, T_DISPLAY]);

% 第二行：信号+噪声混合
% (d) 信号 + DC噪声 10x
subplot(2, 3, 4);
plot(t_us(idx_display), v_clean(idx_display), '-', ...
    'LineWidth', LINE_WIDTH, 'Color', color_clean, 'DisplayName', 'Clean');
hold on;
plot(t_us(idx_display), v_dc_10x(idx_display), '-', ...
    'LineWidth', LINE_WIDTH, 'Color', color_dc, 'DisplayName', 'Noisy');
xlabel('Time (\mus)', 'FontSize', FONTSIZE);
ylabel('Amplitude', 'FontSize', FONTSIZE);
if SHOW_TITLE
    title('(d) Signal + DC', 'FontSize', FONTSIZE);
end
legend('Location', 'best', 'FontSize', FONTSIZE_LEGEND);
set(gca, 'FontSize', FONTSIZE_TICK, 'LineWidth', 0.8);
grid on; box on;
xlim([0, T_DISPLAY]);

% (e) 信号 + PWM噪声 10x
subplot(2, 3, 5);
plot(t_us(idx_display), v_clean(idx_display), '-', ...
    'LineWidth', LINE_WIDTH, 'Color', color_clean, 'DisplayName', 'Clean');
hold on;
plot(t_us(idx_display), v_pwm_10x(idx_display), '-', ...
    'LineWidth', LINE_WIDTH, 'Color', color_pwm, 'DisplayName', 'Noisy');
xlabel('Time (\mus)', 'FontSize', FONTSIZE);
ylabel('Amplitude', 'FontSize', FONTSIZE);
if SHOW_TITLE
    title('(e) Signal + PWM', 'FontSize', FONTSIZE);
end
legend('Location', 'best', 'FontSize', FONTSIZE_LEGEND);
set(gca, 'FontSize', FONTSIZE_TICK, 'LineWidth', 0.8);
grid on; box on;
xlim([0, T_DISPLAY]);

% (f) 信号 + SMPS噪声 10x
subplot(2, 3, 6);
plot(t_us(idx_display), v_clean(idx_display), '-', ...
    'LineWidth', LINE_WIDTH, 'Color', color_clean, 'DisplayName', 'Clean');
hold on;
plot(t_us(idx_display), v_smps_10x(idx_display), '-', ...
    'LineWidth', LINE_WIDTH, 'Color', color_smps, 'DisplayName', 'Noisy');
xlabel('Time (\mus)', 'FontSize', FONTSIZE);
ylabel('Amplitude', 'FontSize', FONTSIZE);
if SHOW_TITLE
    title('(f) Signal + SMPS', 'FontSize', FONTSIZE);
end
legend('Location', 'best', 'FontSize', FONTSIZE_LEGEND);
set(gca, 'FontSize', FONTSIZE_TICK, 'LineWidth', 0.8);
grid on; box on;
xlim([0, T_DISPLAY]);

% 保存 Figure 2
if SHOW_TITLE
    savename2 = 'fig_signal_low_impact_10x';
else
    savename2 = 'fig_signal_low_impact_10x_notitle';
end
print(fig2, savename2, '-dpng', '-r300');
print(fig2, savename2, '-depsc', '-r300');
fprintf('Saved: %s.png and %s.eps\n', savename2, savename2);

%% ========== Figure 3: 影响小的噪声 1000x (MODE 4-6) ==========
fig3 = figure('Position', [150, 50, FIG_WIDTH, FIG_HEIGHT], 'Color', 'w');

% 第一行：纯噪声
% (a) DC噪声 1000x
subplot(2, 3, 1);
plot(t_us(idx_display), noise_dc_1000x(idx_display), '-', ...
    'LineWidth', LINE_WIDTH, 'Color', color_dc);
xlabel('Time (\mus)', 'FontSize', FONTSIZE);
ylabel('Amplitude', 'FontSize', FONTSIZE);
if SHOW_TITLE
    title(sprintf('(a) DC Ambient\n(%dx Signal)', AMBIENT_DC_1000x), 'FontSize', FONTSIZE);
end
set(gca, 'FontSize', FONTSIZE_TICK, 'LineWidth', 0.8);
% 简化Y轴显示
ax = gca;
ax.YAxis.Exponent = 0;
ytickformat('%.0f');
grid on; box on;
xlim([0, T_DISPLAY]);

% (b) PWM噪声 1000x (20kHz)
subplot(2, 3, 2);
plot(t_us(idx_display), noise_pwm_1000x(idx_display), '-', ...
    'LineWidth', LINE_WIDTH, 'Color', color_pwm);
xlabel('Time (\mus)', 'FontSize', FONTSIZE);
ylabel('Amplitude', 'FontSize', FONTSIZE);
if SHOW_TITLE
    title(sprintf('(b) PWM Noise\n(%.0f kHz, %dx)', PWM_FREQ/1e3, AMBIENT_PWM_1000x), 'FontSize', FONTSIZE);
end
set(gca, 'FontSize', FONTSIZE_TICK, 'LineWidth', 0.8);
grid on; box on;
xlim([0, T_DISPLAY]);

% (c) SMPS噪声 1000x (100kHz)
subplot(2, 3, 3);
plot(t_us(idx_display), noise_smps_1000x(idx_display), '-', ...
    'LineWidth', LINE_WIDTH, 'Color', color_smps);
xlabel('Time (\mus)', 'FontSize', FONTSIZE);
ylabel('Amplitude', 'FontSize', FONTSIZE);
if SHOW_TITLE
    title(sprintf('(c) SMPS Noise\n(%.0f kHz, %dx)', SMPS_FREQ/1e3, AMBIENT_SMPS_1000x), 'FontSize', FONTSIZE);
end
set(gca, 'FontSize', FONTSIZE_TICK, 'LineWidth', 0.8);
grid on; box on;
xlim([0, T_DISPLAY]);

% 第二行：信号+噪声混合
% (d) 信号 + DC噪声 1000x
subplot(2, 3, 4);
plot(t_us(idx_display), v_clean(idx_display), '-', ...
    'LineWidth', LINE_WIDTH, 'Color', color_clean, 'DisplayName', 'Clean');
hold on;
plot(t_us(idx_display), v_dc_1000x(idx_display), '-', ...
    'LineWidth', LINE_WIDTH, 'Color', color_dc, 'DisplayName', 'Noisy');
xlabel('Time (\mus)', 'FontSize', FONTSIZE);
ylabel('Amplitude', 'FontSize', FONTSIZE);
if SHOW_TITLE
    title('(d) Signal + DC', 'FontSize', FONTSIZE);
end
legend('Location', 'best', 'FontSize', FONTSIZE_LEGEND);
set(gca, 'FontSize', FONTSIZE_TICK, 'LineWidth', 0.8);
grid on; box on;
xlim([0, T_DISPLAY]);

% (e) 信号 + PWM噪声 1000x
subplot(2, 3, 5);
plot(t_us(idx_display), v_clean(idx_display), '-', ...
    'LineWidth', LINE_WIDTH, 'Color', color_clean, 'DisplayName', 'Clean');
hold on;
plot(t_us(idx_display), v_pwm_1000x(idx_display), '-', ...
    'LineWidth', LINE_WIDTH, 'Color', color_pwm, 'DisplayName', 'Noisy');
xlabel('Time (\mus)', 'FontSize', FONTSIZE);
ylabel('Amplitude', 'FontSize', FONTSIZE);
if SHOW_TITLE
    title('(e) Signal + PWM', 'FontSize', FONTSIZE);
end
legend('Location', 'best', 'FontSize', FONTSIZE_LEGEND);
set(gca, 'FontSize', FONTSIZE_TICK, 'LineWidth', 0.8);
grid on; box on;
xlim([0, T_DISPLAY]);

% (f) 信号 + SMPS噪声 1000x
subplot(2, 3, 6);
plot(t_us(idx_display), v_clean(idx_display), '-', ...
    'LineWidth', LINE_WIDTH, 'Color', color_clean, 'DisplayName', 'Clean');
hold on;
plot(t_us(idx_display), v_smps_1000x(idx_display), '-', ...
    'LineWidth', LINE_WIDTH, 'Color', color_smps, 'DisplayName', 'Noisy');
xlabel('Time (\mus)', 'FontSize', FONTSIZE);
ylabel('Amplitude', 'FontSize', FONTSIZE);
if SHOW_TITLE
    title('(f) Signal + SMPS', 'FontSize', FONTSIZE);
end
legend('Location', 'best', 'FontSize', FONTSIZE_LEGEND);
set(gca, 'FontSize', FONTSIZE_TICK, 'LineWidth', 0.8);
grid on; box on;
xlim([0, T_DISPLAY]);

% 保存 Figure 3
if SHOW_TITLE
    savename3 = 'fig_signal_low_impact_1000x';
else
    savename3 = 'fig_signal_low_impact_1000x_notitle';
end
print(fig3, savename3, '-dpng', '-r300');
print(fig3, savename3, '-depsc', '-r300');
fprintf('Saved: %s.png and %s.eps\n', savename3, savename3);

%% 打印信息
fprintf('\n============================================================\n');
fprintf('Signal Parameters\n');
fprintf('============================================================\n');
fprintf('Sampling rate: %.1f MHz\n', params.Fs/1e6);
fprintf('Sampling time: %.1f us\n', params.T*1e6);
fprintf('Modulation frequencies: %.0f - %.0f kHz\n', min(params.FreqsKHz), max(params.FreqsKHz));
fprintf('\n=== High Impact Noise (MODE 1-3) ===\n');
fprintf('  1. White noise SNR: %d dB\n', SNR_WHITE);
fprintf('  2. In-band noise SNR: %d dB\n', SNR_INBAND);
fprintf('  3. 100 Hz interference: %dx (spectral leakage!)\n', AMBIENT_100HZ);
fprintf('\n=== Low Impact Noise (MODE 4-6) ===\n');
fprintf('  4. DC ambient: 10x and 1000x (immune)\n');
fprintf('  5. PWM dimming: 10x and 1000x at %.0f kHz\n', PWM_FREQ/1e3);
fprintf('  6. SMPS noise: 10x and 1000x at %.0f kHz (can be avoided)\n', SMPS_FREQ/1e3);
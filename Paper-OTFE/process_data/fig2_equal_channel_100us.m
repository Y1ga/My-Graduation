%% fig2_equal_channel_100us.m — fig2 a/b/c/d 等通道积分时间版本
% 用 figure(1)~figure(4) 分别绑定，不会互相覆盖
% 所有子图共享 fig2_style() 样式配置
% 公平性口径：OFE和TDM每个通道均采样100 us。
% OFE的12个通道并行采样，因此总时长为100 us；
% TDM的12个通道串行采样，因此总时长为12*100 us = 1.2 ms。
clear; clc; close all;

%% ========== fig2 a: TDM vs FDM 时域信号对比 (AWGN) ==========
sty = fig2_style();

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
T_channel = 100e-6;
T_fdm = T_channel;
N_fdm = round(Fs * T_fdm);
T_slot = T_channel;
N_slot = round(Fs * T_slot);
N_total = N_LED * N_slot;
T_tdm_total = N_total / Fs;
SNR_dB = 25;

T_START = 0;
T_END_OFE = T_fdm * 1e6;
T_END_TDM = T_tdm_total * 1e6;

fprintf('Equal channel time: OFE %.0f us/channel, %.0f us total; ', ...
    T_fdm*1e6, T_fdm*1e6);
fprintf('TDM %.0f us/channel, %.0f us total (%d channels).\n', ...
    N_slot/Fs*1e6, T_tdm_total*1e6, N_LED);

%% 生成无噪声FDM信号
[v_fdm_clean, t_fdm, params_fdm] = fdm_generate_signal(y_theory, ...
    'FreqMode', 'auto', 'T', T_fdm, 'Fs', Fs, ...
    'SNR_dB', Inf, 'Seed', 1, 'Waveform', 'sine');
P_signal_fdm = var(v_fdm_clean);
freqs_Hz = params_fdm.FreqsHz;

%% 生成无噪声TDM信号
t_tdm = (0:N_total-1) / Fs;
v_tdm_clean = zeros(1, N_total);
for i = 1:N_LED
    idx_start = (i-1) * N_slot + 1;
    idx_end = i * N_slot;
    v_tdm_clean(idx_start:idx_end) = y_theory(i);
end

%% 噪声
noise_variance = P_signal_fdm / (10^(SNR_dB/10));
noise_std = sqrt(noise_variance);

t_fdm_us = t_fdm * 1e6;
t_tdm_us = t_tdm * 1e6;
idx_fdm = (t_fdm_us >= T_START) & (t_fdm_us <= T_END_OFE);
idx_tdm = (t_tdm_us >= T_START) & (t_tdm_us <= T_END_TDM);

rng(1);
v_fdm_noisy = v_fdm_clean + noise_std * randn(1, N_fdm);
rng(1);
v_tdm_noisy = v_tdm_clean + noise_std * randn(1, N_total);

noise_label = sprintf('AWGN, SNR = %d dB', SNR_dB);

%% 绘图 — figure(1)
FIG_H = 16;
figure(1);
set(gcf, 'Units', 'centimeters', 'Position', [2, 2, sty.FIG_WIDTH_CM, FIG_H], 'Color', 'w');
set(gcf, 'PaperUnits', 'centimeters', 'PaperSize', [sty.FIG_WIDTH_CM, FIG_H], ...
    'PaperPosition', [0, 0, sty.FIG_WIDTH_CM, FIG_H]);

ml = sty.margin_left;  mr = sty.margin_right;
mb = sty.margin_bottom; mt = sty.margin_top; gp = sty.gap;
pw = 1 - ml - mr;
ph = (1 - mb - mt - gp) / 2;

% --- 上图: OFE ---
ax1 = axes('Position', [ml, mb+ph+gp, pw, ph]);
hold on; box on;
h1 = plot(t_fdm_us(idx_fdm), v_fdm_clean(idx_fdm), '-', ...
    'LineWidth', sty.LINE_WIDTH + 0.3, 'Color', sty.color_clean);
h2 = plot(t_fdm_us(idx_fdm), v_fdm_noisy(idx_fdm), '-', ...
    'LineWidth', sty.LINE_WIDTH, 'Color', sty.color_noisy_fdm);
ylabel('AC Amplitude (a.u.)', 'FontSize', sty.FONTSIZE_LABEL, 'FontName', sty.FONT_NAME);
xlabel('Time (μs)', 'FontSize', sty.FONTSIZE_LABEL, 'FontName', sty.FONT_NAME);
leg1 = legend([h1, h2], {'Noiseless', noise_label}, ...
    'Location', 'northeast', 'FontSize', sty.FONTSIZE_LEGEND);
leg1.Box = 'off';
set(ax1, 'FontSize', sty.FONTSIZE_TICK, 'FontName', sty.FONT_NAME, ...
    'LineWidth', sty.LINE_WIDTH_AXIS);
xlim([T_START, T_END_OFE]);

% --- 下图: TDM ---
ax2 = axes('Position', [ml, mb, pw, ph]);
hold on; box on;
h3 = plot(t_tdm_us(idx_tdm), v_tdm_clean(idx_tdm), '-', ...
    'LineWidth', sty.LINE_WIDTH + 0.3, 'Color', sty.color_clean);
h4 = plot(t_tdm_us(idx_tdm), v_tdm_noisy(idx_tdm), '-', ...
    'LineWidth', sty.LINE_WIDTH, 'Color', sty.color_noisy_tdm);
xlabel('Time (μs)', 'FontSize', sty.FONTSIZE_LABEL, 'FontName', sty.FONT_NAME);
ylabel('AC Amplitude (a.u.)', 'FontSize', sty.FONTSIZE_LABEL, 'FontName', sty.FONT_NAME);
leg2 = legend([h3, h4], {'Noiseless', noise_label}, ...
    'Location', 'northeast', 'FontSize', sty.FONTSIZE_LEGEND);
leg2.Box = 'off';
set(ax2, 'FontSize', sty.FONTSIZE_TICK, 'FontName', sty.FONT_NAME, ...
    'LineWidth', sty.LINE_WIDTH_AXIS);
xlim([T_START, T_END_TDM]);

yl1 = ax1.YLim; yl2 = ax2.YLim;
y_common = [min(yl1(1), yl2(1)), max(yl1(2), yl2(2))];
ylim(ax1, y_common); ylim(ax2, y_common);

savename = 'fig2a_timedomain_awgn_equal_channel_100us';
print(gcf, savename, '-dpng', '-r300');
print(gcf, savename, '-depsc', '-r300');
fprintf('Saved: %s\n', savename);

%% ========== fig2 b: TDM vs OFE AWGN 性能曲线 — figure(2) ==========
tdm_vs_ofe_sim_v2(1, 'TDMChannelTime', T_channel, ...
    'SaveSuffix', '_equal_channel_100us');

%% ========== fig2 c: 窄带多音噪声时域对比 — figure(3) ==========
sty = fig2_style();  % 重新读取

%% 仿真参数
M = 10;
SNR_dB_c = -10;
CLEAN_MODE = true;

if CLEAN_MODE
    guard_band_list = 10e3;
else
    guard_band_list = [1e3, 10e3];
end
n_case = length(guard_band_list);

%% 配色
color_baseline = sty.color_clean;
color_1k  = [0.72, 0.25, 0.22];
color_10k = [0.22, 0.40, 0.68];

if CLEAN_MODE
    colors_case = color_10k;
    linestyles = {'--'};
else
    colors_case = [color_1k; color_10k];
    linestyles = {'-', '--'};
end

lw_base  = sty.LINE_WIDTH + 0.5;
lw_noise = sty.LINE_WIDTH;

%% 获取调制频率
[v_fdm_clean_c, t_f, params_clean] = fdm_generate_signal(y_theory, ...
    'FreqMode', 'auto', 'T', T_fdm, 'Fs', Fs, ...
    'SNR_dB', Inf, 'Seed', 1, 'Waveform', 'sine');
P_signal = var(v_fdm_clean_c);
freqs_sorted = sort(params_clean.FreqsHz);
noise_var_c = P_signal / (10^(SNR_dB_c/10));

%% 生成TDM无噪声信号
t_t = (0:N_total-1) / Fs;
v_tdm_clean_c = zeros(1, N_total);
for i = 1:N_LED
    v_tdm_clean_c((i-1)*N_slot+1 : i*N_slot) = y_theory(i);
end

%% 为每个Δf生成有噪声信号
v_fdm_noisy_c = zeros(n_case, length(v_fdm_clean_c));
v_tdm_noisy_c = zeros(n_case, N_total);

for g = 1:n_case
    f_noise = freqs_sorted(1:min(M, length(freqs_sorted))) + guard_band_list(g);
    rng(1);
    phi = 2*pi*rand(1, M);
    
    noise_f = zeros(1, length(t_f));
    for j = 1:M
        noise_f = noise_f + cos(2*pi*f_noise(j)*t_f + phi(j));
    end
    noise_f = noise_f * sqrt(noise_var_c / var(noise_f));
    v_fdm_noisy_c(g,:) = v_fdm_clean_c + noise_f;
    
    noise_t = zeros(1, N_total);
    for j = 1:M
        noise_t = noise_t + cos(2*pi*f_noise(j)*t_t + phi(j));
    end
    noise_t = noise_t * sqrt(noise_var_c / var(noise_t));
    v_tdm_noisy_c(g,:) = v_tdm_clean_c + noise_t;
    
    fprintf('Δf = %d kHz: noise %.0f–%.0f kHz\n', ...
        guard_band_list(g)/1e3, min(f_noise)/1e3, max(f_noise)/1e3);
end

%% 时间轴
t_f_us = t_f * 1e6;
t_t_us = t_t * 1e6;
T_END_C = 20;  % fig2c仅展示前20 us；不改变实际采样和解调时长
idx_f = (t_f_us >= T_START) & (t_f_us <= T_END_C);
idx_t = (t_t_us >= T_START) & (t_t_us <= T_END_C);

%% figure 2c
FIG_H_C = 16;
figure(3);
set(gcf, 'Units', 'centimeters', 'Position', [2, 2, sty.FIG_WIDTH_CM, FIG_H_C], 'Color', 'w');
set(gcf, 'PaperUnits', 'centimeters', 'PaperSize', [sty.FIG_WIDTH_CM, FIG_H_C], ...
    'PaperPosition', [0, 0, sty.FIG_WIDTH_CM, FIG_H_C]);

pw = 1 - ml - mr;
ph = (1 - mb - mt - gp) / 2;

% --- 上图: OFE ---
ax1c = axes('Position', [ml, mb+ph+gp, pw, ph]);
hold on; box on;
plot(t_f_us(idx_f), v_fdm_clean_c(idx_f), '-', ...
    'LineWidth', lw_base, 'Color', color_baseline);
for g = 1:n_case
    plot(t_f_us(idx_f), v_fdm_noisy_c(g, idx_f), linestyles{g}, ...
        'LineWidth', lw_noise, 'Color', colors_case(g,:));
end
ylabel('AC Amplitude (a.u.)', 'FontSize', sty.FONTSIZE_LABEL, 'FontName', sty.FONT_NAME);
xlabel('Time (μs)', 'FontSize', sty.FONTSIZE_LABEL, 'FontName', sty.FONT_NAME);
set(gca, 'FontSize', sty.FONTSIZE_TICK, 'FontName', sty.FONT_NAME, ...
    'LineWidth', sty.LINE_WIDTH_AXIS);
xlim([T_START, T_END_C]);

% --- 下图: TDM ---
ax2c = axes('Position', [ml, mb, pw, ph]);
hold on; box on;
plot(t_t_us(idx_t), v_tdm_clean_c(idx_t), '-', ...
    'LineWidth', lw_base, 'Color', color_baseline);
for g = 1:n_case
    plot(t_t_us(idx_t), v_tdm_noisy_c(g, idx_t), linestyles{g}, ...
        'LineWidth', lw_noise, 'Color', colors_case(g,:));
end
ylabel('AC Amplitude (a.u.)', 'FontSize', sty.FONTSIZE_LABEL, 'FontName', sty.FONT_NAME);
xlabel('Time (μs)', 'FontSize', sty.FONTSIZE_LABEL, 'FontName', sty.FONT_NAME);
set(gca, 'FontSize', sty.FONTSIZE_TICK, 'FontName', sty.FONT_NAME, ...
    'LineWidth', sty.LINE_WIDTH_AXIS);
xlim([T_START, T_END_C]);

% 统一Y轴
yl1c = get(ax1c, 'YLim'); yl2c = get(ax2c, 'YLim');
ylc = [min(yl1c(1),yl2c(1)), max(yl1c(2),yl2c(2))];
set(ax1c, 'YLim', ylc); set(ax2c, 'YLim', ylc);

% 图例
axes(ax1c);
h_leg = gobjects(n_case + 1, 1);
leg_str = cell(n_case + 1, 1);
h_leg(1) = plot(NaN, NaN, '-', 'LineWidth', lw_base, 'Color', color_baseline);
leg_str{1} = 'Noiseless';
for g = 1:n_case
    h_leg(g+1) = plot(NaN, NaN, linestyles{g}, 'LineWidth', lw_noise, 'Color', colors_case(g,:));
    leg_str{g+1} = sprintf('Multitone noise', ...
        guard_band_list(g)/1e3, SNR_dB_c);
end
leg = legend(h_leg, leg_str, 'Location', 'northwest', ...
    'FontSize', sty.FONTSIZE_LEGEND, 'FontName', sty.FONT_NAME);
leg.Box = 'off';

savename = 'fig2c_narrowband_timedomain_equal_channel_100us';
print(gcf, savename, '-dpng', '-r300');
print(gcf, savename, '-depsc', '-r300');
fprintf('Saved: %s\n', savename);

%% ========== fig2 d: TDM vs OFE 多音噪声性能曲线 — figure(4) ==========
tdm_vs_ofe_sim_v2(3, 'TDMChannelTime', T_channel, ...
    'SaveSuffix', '_equal_channel_100us');

fprintf('\n=== fig2 a/b/c/d 等通道100 us版本全部生成完毕 ===\n');

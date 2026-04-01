%% Fig 2c: OFE vs TDM 窄带干扰时域波形
% 三线极简: Noiseless(黑) + Δf=1kHz(红) + Δf=10kHz(蓝)
% 上图OFE + 下图TDM, 共享横轴, OFE子图带放大框
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

%% 仿真参数
M = 10;                          % 噪声音调数
SNR_dB = -10;                    % 显示用SNR
CLEAN_MODE = true;              % true: 只画 Noiseless + 10kHz; false: 多画 1kHz

if CLEAN_MODE
    guard_band_list = 10e3;
else
    guard_band_list = [1e3, 10e3];
end
n_case = length(guard_band_list);

T_START = 0;  T_END = 20;       % 显示范围 (μs)

%% 图形样式
FIG_W = 18;   % cm
FIG_H = 16;   % cm (比原来高一点，给inset留空间)

FONTSIZE = 18;
FONTSIZE_LEGEND = 15;
FONTSIZE_TICK = 16;
LINE_WIDTH = 1.8;
LINE_WIDTH_AXIS = 0.5;

% 配色 (低饱和度)
color_baseline = [0.15, 0.15, 0.15];        % 黑 - Noiseless
color_1k  = [0.72, 0.25, 0.22];             % 暗红 - Δf=1 kHz
color_10k = [0.22, 0.40, 0.68];             % 藏蓝 - Δf=10 kHz

if CLEAN_MODE
    colors_case = color_10k;
    linestyles = {'--'};
else
    colors_case = [color_1k; color_10k];
    linestyles = {'-', '--'};
end

lw_base  = LINE_WIDTH + 0.5;    % baseline粗
lw_noise = LINE_WIDTH;           % 干扰线

%% 获取调制频率
[v_fdm_clean, t_f, params_clean] = fdm_generate_signal(y_theory, ...
    'FreqMode', 'auto', 'T', T_fdm, 'Fs', Fs, ...
    'SNR_dB', Inf, 'Seed', 1, 'Waveform', 'sine');
P_signal = var(v_fdm_clean);
freqs_sorted = sort(params_clean.FreqsHz);
noise_var = P_signal / (10^(SNR_dB/10));

%% 生成TDM无噪声信号
N_total = N_LED * N_slot;
t_t = (0:N_total-1) / Fs;
v_tdm_clean = zeros(1, N_total);
for i = 1:N_LED
    v_tdm_clean((i-1)*N_slot+1 : i*N_slot) = y_theory(i);
end

%% 为每个Δf生成有噪声信号
v_fdm_noisy = zeros(n_case, length(v_fdm_clean));
v_tdm_noisy = zeros(n_case, N_total);

for g = 1:n_case
    f_noise = freqs_sorted(1:min(M, length(freqs_sorted))) + guard_band_list(g);
    rng(1);
    phi = 2*pi*rand(1, M);
    
    % OFE噪声
    noise_f = zeros(1, length(t_f));
    for j = 1:M
        noise_f = noise_f + cos(2*pi*f_noise(j)*t_f + phi(j));
    end
    noise_f = noise_f * sqrt(noise_var / var(noise_f));
    v_fdm_noisy(g,:) = v_fdm_clean + noise_f;
    
    % TDM噪声
    noise_t = zeros(1, N_total);
    for j = 1:M
        noise_t = noise_t + cos(2*pi*f_noise(j)*t_t + phi(j));
    end
    noise_t = noise_t * sqrt(noise_var / var(noise_t));
    v_tdm_noisy(g,:) = v_tdm_clean + noise_t;
    
    fprintf('Δf = %d kHz: noise %.0f–%.0f kHz\n', ...
        guard_band_list(g)/1e3, min(f_noise)/1e3, max(f_noise)/1e3);
end

%% 时间轴
t_f_us = t_f * 1e6;
t_t_us = t_t * 1e6;
idx_f = (t_f_us >= T_START) & (t_f_us <= T_END);
idx_t = (t_t_us >= T_START) & (t_t_us <= T_END);

%% ==================== 绘图 ====================
fig = figure('Units', 'centimeters', 'Position', [2, 2, FIG_W, FIG_H], 'Color', 'w');
set(fig, 'PaperUnits', 'centimeters', 'PaperSize', [FIG_W, FIG_H], ...
    'PaperPosition', [0, 0, FIG_W, FIG_H]);

% 布局参数
ml = 0.13;  mr = 0.04;  mb = 0.12;  mt = 0.04;  gap = 0.06;
pw = 1 - ml - mr;
ph = (1 - mb - mt - gap) / 2;

%% ========== 上图: OFE ==========
ax1 = axes('Position', [ml, mb+ph+gap, pw, ph]);
hold on; box on;

plot(t_f_us(idx_f), v_fdm_clean(idx_f), '-', ...
    'LineWidth', lw_base, 'Color', color_baseline);
for g = 1:n_case
    plot(t_f_us(idx_f), v_fdm_noisy(g, idx_f), linestyles{g}, ...
        'LineWidth', lw_noise, 'Color', colors_case(g,:));
end

ylabel('AC Amplitude (a.u.)', 'FontSize', FONTSIZE, 'FontName', 'Arial');
set(gca, 'XTickLabel', [], 'FontSize', FONTSIZE_TICK, 'FontName', 'Arial', ...
    'LineWidth', LINE_WIDTH_AXIS);
xlim([T_START, T_END]);

%% ========== 下图: TDM ==========
ax2 = axes('Position', [ml, mb, pw, ph]);
hold on; box on;

plot(t_t_us(idx_t), v_tdm_clean(idx_t), '-', ...
    'LineWidth', lw_base, 'Color', color_baseline);
for g = 1:n_case
    plot(t_t_us(idx_t), v_tdm_noisy(g, idx_t), linestyles{g}, ...
        'LineWidth', lw_noise, 'Color', colors_case(g,:));
end

ylabel('AC Amplitude (a.u.)', 'FontSize', FONTSIZE, 'FontName', 'Arial');
xlabel('Time (μs)', 'FontSize', FONTSIZE, 'FontName', 'Arial');
set(gca, 'FontSize', FONTSIZE_TICK, 'FontName', 'Arial', 'LineWidth', LINE_WIDTH_AXIS);
xlim([T_START, T_END]);

%% 统一Y轴
yl1 = get(ax1, 'YLim');
yl2 = get(ax2, 'YLim');
ylc = [min(yl1(1),yl2(1)), max(yl1(2),yl2(2))];
set(ax1, 'YLim', ylc);
set(ax2, 'YLim', ylc);

%% 图例 (放在上图内部, 左上角)
axes(ax1);
h_leg = gobjects(n_case + 1, 1);
leg_str = cell(n_case + 1, 1);
h_leg(1) = plot(NaN, NaN, '-', 'LineWidth', lw_base, 'Color', color_baseline);
leg_str{1} = 'Noiseless';
for g = 1:n_case
    h_leg(g+1) = plot(NaN, NaN, linestyles{g}, 'LineWidth', lw_noise, 'Color', colors_case(g,:));
    leg_str{g+1} = sprintf('Multitone noise, \\Deltaf_{guard} = %d kHz, SNR = %d dB', ...
        guard_band_list(g)/1e3, SNR_dB);
end
leg = legend(h_leg, leg_str, 'Location', 'northwest', ...
    'FontSize', FONTSIZE_LEGEND, 'FontName', 'Arial');
leg.Box = 'off';

%% 保存
savename = 'fig2c_narrowband_timedomain';
print(gcf, savename, '-dpng', '-r300');
print(gcf, savename, '-depsc', '-r300');
fprintf('Saved: %s.png and %s.eps\n', savename, savename);

%% 打印信息
fprintf('\nSNR = %d dB, M = %d tones\n', SNR_dB, M);
fprintf('OFE freqs: %.0f–%.0f kHz\n', min(freqs_sorted)/1e3, max(freqs_sorted)/1e3);
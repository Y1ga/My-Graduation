%% TDM vs FDM 时域信号对比 — 上下堆叠子图版
% 上半部分: FDM 无噪 + 带噪
% 下半部分: TDM 无噪 + 带噪
% 共享X轴，便于同一时间刻度上下比对
%
% MODE 1: AWGN噪声
% MODE 2: 带内噪声
% MODE 3: 多音噪声 (不同Δf)
clear; clc; close all;

%% ==================== 选择模式 ====================
MODE = 1;  % 1=AWGN, 2=带内噪声, 3=多音噪声

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

SNR_dB = 25;

%% 显示时间范围 (μs)
T_START = 0;
T_END = 20;

%% 图形参数
FIG_WIDTH_CM = 18;
FIG_HEIGHT_CM = 16;  % 稍微增高以容纳两个子图

FONTSIZE = 16;
FONTSIZE_LEGEND = FONTSIZE - 2;
FONTSIZE_TICK = FONTSIZE - 2;
FONTSIZE_LABEL = FONTSIZE;
LINE_WIDTH = 1.5;
LINE_WIDTH_AXIS = 0.5;
SHOW_GRID = false;

%% 颜色定义（全局）
color_clean = [0.15, 0.15, 0.15];       % 深灰/黑 — 无噪声
color_noisy_fdm = [0.20, 0.45, 0.85];   % 蓝色 — FDM带噪
color_noisy_tdm = [0.85, 0.25, 0.25];   % 红色 — TDM带噪

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

%% 噪声功率
noise_variance = P_signal_fdm / (10^(SNR_dB/10));
noise_std = sqrt(noise_variance);

%% 时间轴(μs)与显示索引
t_fdm_us = t_fdm * 1e6;
t_tdm_us = t_tdm * 1e6;
idx_fdm = (t_fdm_us >= T_START) & (t_fdm_us <= T_END);
idx_tdm = (t_tdm_us >= T_START) & (t_tdm_us <= T_END);

%% ==================== MODE 1: AWGN ====================
if MODE == 1
    mode_name = 'AWGN Noise';
    noise_label = sprintf('AWGN, SNR = %d dB', SNR_dB);
    
    rng(1);
    v_fdm_noisy = v_fdm_clean + noise_std * randn(1, N_fdm);
    rng(1);
    v_tdm_noisy = v_tdm_clean + noise_std * randn(1, N_total);
    
    savename = 'fig_timedomain_awgn_stacked';
    
    % 调用绘图函数
    plot_stacked_single(t_fdm_us, v_fdm_clean, v_fdm_noisy, idx_fdm, ...
                        t_tdm_us, v_tdm_clean, v_tdm_noisy, idx_tdm, ...
                        noise_label, color_clean, color_noisy_fdm, color_noisy_tdm, ...
                        T_START, T_END, FIG_WIDTH_CM, FIG_HEIGHT_CM, ...
                        FONTSIZE, FONTSIZE_LEGEND, FONTSIZE_TICK, FONTSIZE_LABEL, ...
                        LINE_WIDTH, LINE_WIDTH_AXIS, SHOW_GRID);

%% ==================== MODE 2: 带内噪声 ====================
elseif MODE == 2
    mode_name = 'In-band Noise';
    noise_label = sprintf('In-band, SNR = %d dB', SNR_dB);
    
    f_inband_low = 30e3;
    f_inband_high = max(freqs_Hz) + 20e3;
    
    rng(1);
    noise_white = noise_std * randn(1, max(N_fdm, N_total));
    f_low_norm = f_inband_low / (Fs/2);
    f_high_norm = min(f_inband_high / (Fs/2), 0.99);
    [b, a] = butter(4, [f_low_norm, f_high_norm], 'bandpass');
    noise_inband_full = filter(b, a, noise_white);
    noise_inband_full = noise_inband_full * sqrt(noise_variance / var(noise_inband_full));
    
    v_fdm_noisy = v_fdm_clean + noise_inband_full(1:N_fdm);
    v_tdm_noisy = v_tdm_clean + noise_inband_full(1:N_total);
    
    savename = 'fig_timedomain_inband_stacked';
    
    plot_stacked_single(t_fdm_us, v_fdm_clean, v_fdm_noisy, idx_fdm, ...
                        t_tdm_us, v_tdm_clean, v_tdm_noisy, idx_tdm, ...
                        noise_label, color_clean, color_noisy_fdm, color_noisy_tdm, ...
                        T_START, T_END, FIG_WIDTH_CM, FIG_HEIGHT_CM, ...
                        FONTSIZE, FONTSIZE_LEGEND, FONTSIZE_TICK, FONTSIZE_LABEL, ...
                        LINE_WIDTH, LINE_WIDTH_AXIS, SHOW_GRID);

%% ==================== MODE 3: 多音噪声 ====================
elseif MODE == 3
    mode_name = 'Multi-tone Noise';
    
    guard_band_list = [1e3, 5e3, 10e3];
    n_guard = length(guard_band_list);
    M = 10;
    
    freqs_sorted = sort(freqs_Hz);
    
    % 每个Δf一组颜色（带噪线）
    colors_noisy = [
        0.85, 0.35, 0.25;   % 红 — Δf=1kHz
        0.20, 0.60, 0.30;   % 绿 — Δf=5kHz
        0.20, 0.45, 0.70;   % 蓝 — Δf=10kHz
    ];
    
    fig = figure('Units', 'centimeters', 'Position', [2, 2, FIG_WIDTH_CM, FIG_HEIGHT_CM], 'Color', 'w');
    set(fig, 'PaperUnits', 'centimeters', 'PaperSize', [FIG_WIDTH_CM, FIG_HEIGHT_CM], ...
        'PaperPosition', [0, 0, FIG_WIDTH_CM, FIG_HEIGHT_CM]);
    
    % ---- 上子图: FDM ----
    ax1 = subplot(2, 1, 1);
    hold on; box on;
    
    h_fdm_clean = plot(t_fdm_us(idx_fdm), v_fdm_clean(idx_fdm), '-', ...
        'LineWidth', LINE_WIDTH + 0.3, 'Color', color_clean);
    
    h_fdm_noisy = gobjects(n_guard, 1);
    legend_fdm = cell(n_guard + 1, 1);
    legend_fdm{1} = 'Noiseless';
    
    for g = 1:n_guard
        guard_band = guard_band_list(g);
        f_noise = freqs_sorted(1:min(M, length(freqs_sorted))) + guard_band;
        
        rng(1);
        phi_noise = 2 * pi * rand(1, M);
        
        noise_fdm = zeros(1, N_fdm);
        for j = 1:M
            noise_fdm = noise_fdm + cos(2*pi*f_noise(j)*t_fdm + phi_noise(j));
        end
        noise_fdm = noise_fdm * sqrt(noise_variance / var(noise_fdm));
        
        v_fdm_noisy_g = v_fdm_clean + noise_fdm;
        
        h_fdm_noisy(g) = plot(t_fdm_us(idx_fdm), v_fdm_noisy_g(idx_fdm), '-', ...
            'LineWidth', LINE_WIDTH, 'Color', colors_noisy(g,:));
        legend_fdm{g+1} = sprintf('\\Deltaf = %d kHz', guard_band/1e3);
    end
    
    ylabel('Amplitude (a.u.)', 'FontSize', FONTSIZE_LABEL, 'FontName', 'Arial');
    leg1 = legend([h_fdm_clean; h_fdm_noisy], legend_fdm, ...
        'Location', 'northeast', 'FontSize', FONTSIZE_LEGEND - 2);
    leg1.Box = 'off';
    set(ax1, 'FontSize', FONTSIZE_TICK, 'FontName', 'Arial', 'LineWidth', LINE_WIDTH_AXIS);
    set(ax1, 'XTickLabel', []);  % 隐藏上子图X刻度标签
    xlim([T_START, T_END]);
    if SHOW_GRID, grid on; set(ax1, 'GridLineStyle', ':', 'GridAlpha', 0.3); end
    
    % ---- 下子图: TDM ----
    ax2 = subplot(2, 1, 2);
    hold on; box on;
    
    h_tdm_clean = plot(t_tdm_us(idx_tdm), v_tdm_clean(idx_tdm), '-', ...
        'LineWidth', LINE_WIDTH + 0.3, 'Color', color_clean);
    
    h_tdm_noisy = gobjects(n_guard, 1);
    legend_tdm = cell(n_guard + 1, 1);
    legend_tdm{1} = 'Noiseless';
    
    for g = 1:n_guard
        guard_band = guard_band_list(g);
        f_noise = freqs_sorted(1:min(M, length(freqs_sorted))) + guard_band;
        
        rng(1);
        phi_noise = 2 * pi * rand(1, M);
        
        noise_tdm = zeros(1, N_total);
        for j = 1:M
            noise_tdm = noise_tdm + cos(2*pi*f_noise(j)*t_tdm + phi_noise(j));
        end
        noise_tdm = noise_tdm * sqrt(noise_variance / var(noise_tdm));
        
        v_tdm_noisy_g = v_tdm_clean + noise_tdm;
        
        h_tdm_noisy(g) = plot(t_tdm_us(idx_tdm), v_tdm_noisy_g(idx_tdm), '-', ...
            'LineWidth', LINE_WIDTH, 'Color', colors_noisy(g,:));
        legend_tdm{g+1} = sprintf('\\Deltaf = %d kHz', guard_band/1e3);
    end
    
    xlabel('Time (μs)', 'FontSize', FONTSIZE_LABEL, 'FontName', 'Arial');
    ylabel('Amplitude (a.u.)', 'FontSize', FONTSIZE_LABEL, 'FontName', 'Arial');
    leg2 = legend([h_tdm_clean; h_tdm_noisy], legend_tdm, ...
        'Location', 'northeast', 'FontSize', FONTSIZE_LEGEND - 2);
    leg2.Box = 'off';
    set(ax2, 'FontSize', FONTSIZE_TICK, 'FontName', 'Arial', 'LineWidth', LINE_WIDTH_AXIS);
    xlim([T_START, T_END]);
    if SHOW_GRID, grid on; set(ax2, 'GridLineStyle', ':', 'GridAlpha', 0.3); end
    
    % 联动X轴
    linkaxes([ax1, ax2], 'x');
    
    % 减小子图间距
    set(ax1, 'Position', [0.12, 0.54, 0.83, 0.40]);
    set(ax2, 'Position', [0.12, 0.10, 0.83, 0.40]);
    
    savename = 'fig_timedomain_multitone_stacked';
    
else
    error('Unknown MODE: %d. Use 1, 2, or 3.', MODE);
end

%% 通用保存
print(gcf, savename, '-dpng', '-r300');
print(gcf, savename, '-depsc', '-r300');
fprintf('Saved: %s.png and %s.eps\n', savename, savename);

%% 打印信息
fprintf('\n============================================================\n');
fprintf('MODE %d: %s\n', MODE, mode_name);
fprintf('============================================================\n');
fprintf('总时间: %.0f μs\n', T_total*1e6);
fprintf('显示时间: %.0f - %.0f μs\n', T_START, T_END);
fprintf('采样率: %.0f MHz\n', Fs/1e6);
fprintf('SNR: %d dB\n', SNR_dB);
fprintf('FDM调制频率: %.0f - %.0f kHz\n', min(freqs_Hz)/1e3, max(freqs_Hz)/1e3);
if MODE == 3
    fprintf('噪声音调数: %d\n', M);
    fprintf('频率间隔: 1, 5, 10 kHz\n');
end
fprintf('============================================================\n');


%% =====================================================================
%  局部函数: MODE 1 & 2 共用的堆叠子图绘制
%  =====================================================================
function plot_stacked_single(t_fdm_us, v_fdm_clean, v_fdm_noisy, idx_fdm, ...
                             t_tdm_us, v_tdm_clean, v_tdm_noisy, idx_tdm, ...
                             noise_label, color_clean, color_noisy_fdm, color_noisy_tdm, ...
                             T_START, T_END, FIG_WIDTH_CM, FIG_HEIGHT_CM, ...
                             FONTSIZE, FONTSIZE_LEGEND, FONTSIZE_TICK, FONTSIZE_LABEL, ...
                             LINE_WIDTH, LINE_WIDTH_AXIS, SHOW_GRID)

    fig = figure('Units', 'centimeters', 'Position', [2, 2, FIG_WIDTH_CM, FIG_HEIGHT_CM], 'Color', 'w');
    set(fig, 'PaperUnits', 'centimeters', 'PaperSize', [FIG_WIDTH_CM, FIG_HEIGHT_CM], ...
        'PaperPosition', [0, 0, FIG_WIDTH_CM, FIG_HEIGHT_CM]);
    
    % ---- 上子图: FDM ----
    ax1 = subplot(2, 1, 1);
    hold on; box on;
    
    h1 = plot(t_fdm_us(idx_fdm), v_fdm_clean(idx_fdm), '-', ...
        'LineWidth', LINE_WIDTH + 0.3, 'Color', color_clean);
    h2 = plot(t_fdm_us(idx_fdm), v_fdm_noisy(idx_fdm), '-', ...
        'LineWidth', LINE_WIDTH, 'Color', color_noisy_fdm);
    
    ylabel('Amplitude (a.u.)', 'FontSize', FONTSIZE_LABEL, 'FontName', 'Arial');
    leg1 = legend([h1, h2], {'Noiseless', noise_label}, ...
        'Location', 'northeast', 'FontSize', FONTSIZE_LEGEND);
    leg1.Box = 'off';
    set(ax1, 'FontSize', FONTSIZE_TICK, 'FontName', 'Arial', 'LineWidth', LINE_WIDTH_AXIS);
    set(ax1, 'XTickLabel', []);  % 隐藏上子图X刻度标签
    xlim([T_START, T_END]);
    if SHOW_GRID, grid on; set(ax1, 'GridLineStyle', ':', 'GridAlpha', 0.3); end
    
    % ---- 下子图: TDM ----
    ax2 = subplot(2, 1, 2);
    hold on; box on;
    
    h3 = plot(t_tdm_us(idx_tdm), v_tdm_clean(idx_tdm), '-', ...
        'LineWidth', LINE_WIDTH + 0.3, 'Color', color_clean);
    h4 = plot(t_tdm_us(idx_tdm), v_tdm_noisy(idx_tdm), '-', ...
        'LineWidth', LINE_WIDTH, 'Color', color_noisy_tdm);
    
    xlabel('Time (μs)', 'FontSize', FONTSIZE_LABEL, 'FontName', 'Arial');
    ylabel('Amplitude (a.u.)', 'FontSize', FONTSIZE_LABEL, 'FontName', 'Arial');
    leg2 = legend([h3, h4], {'Noiseless', noise_label}, ...
        'Location', 'northeast', 'FontSize', FONTSIZE_LEGEND);
    leg2.Box = 'off';
    set(ax2, 'FontSize', FONTSIZE_TICK, 'FontName', 'Arial', 'LineWidth', LINE_WIDTH_AXIS);
    xlim([T_START, T_END]);
    if SHOW_GRID, grid on; set(ax2, 'GridLineStyle', ':', 'GridAlpha', 0.3); end
    
    % 联动X轴 + 统一Y轴范围
    linkaxes([ax1, ax2], 'x');
    
    % 统一Y轴范围（取两个子图的极值）
    yl1 = ax1.YLim;
    yl2 = ax2.YLim;
    y_common = [min(yl1(1), yl2(1)), max(yl1(2), yl2(2))];
    ylim(ax1, y_common);
    ylim(ax2, y_common);
    
    % 减小子图间距，最大化绘图面积
    set(ax1, 'Position', [0.12, 0.54, 0.83, 0.40]);
    set(ax2, 'Position', [0.12, 0.10, 0.83, 0.40]);
end
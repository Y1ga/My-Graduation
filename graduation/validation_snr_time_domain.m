%% TDM vs FDM 时域信号对比
% MODE 1: AWGN噪声时域信号
% MODE 2: 带内噪声时域信号  
% MODE 3: 多音噪声时域信号 (不同Δf)
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

SNR_dB = 25;  % 噪声信噪比

%% 显示时间范围 (μs)
T_START = 0;
T_END = 20;  % 显示前20μs

%% 图形参数
FIG_WIDTH_CM = 18;
FIG_HEIGHT_CM = 14;

FONTSIZE = 18;
FONTSIZE_LEGEND = FONTSIZE - 2;
FONTSIZE_TICK = FONTSIZE - 2;
LINE_WIDTH = 1.5;
LINE_WIDTH_AXIS = 0.5;
SHOW_GRID = false;

%% 生成无噪声FDM信号（所有MODE共用）
[v_fdm_clean, t_fdm, params_fdm] = fdm_generate_signal(y_theory, ...
    'FreqMode', 'auto', 'T', T_fdm, 'Fs', Fs, ...
    'SNR_dB', Inf, 'Seed', 1, 'Waveform', 'sine');
P_signal_fdm = var(v_fdm_clean);
freqs_Hz = params_fdm.FreqsHz;

%% 生成无噪声TDM信号（所有MODE共用）
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

%% ==================== MODE 1: AWGN ====================
if MODE == 1
    mode_name = 'AWGN Noise';
    
    % FDM + AWGN
    rng(1);
    v_fdm_noisy = v_fdm_clean + noise_std * randn(1, N_fdm);
    
    % TDM + AWGN
    rng(1);
    v_tdm_noisy = v_tdm_clean + noise_std * randn(1, N_total);
    
    % 颜色定义
    color_fdm_clean = [0.15, 0.15, 0.15];     % 深黑
    color_tdm_clean = [0.85, 0.20, 0.20];     % 鲜红
    color_fdm_noisy = [0.20, 0.45, 0.85];     % 鲜蓝
    color_tdm_noisy = [0.20, 0.70, 0.30];     % 鲜绿
    
    %% 绘图
    fig = figure('Units', 'centimeters', 'Position', [2, 2, FIG_WIDTH_CM, FIG_HEIGHT_CM], 'Color', 'w');
    set(fig, 'PaperUnits', 'centimeters', 'PaperSize', [FIG_WIDTH_CM, FIG_HEIGHT_CM], ...
        'PaperPosition', [0, 0, FIG_WIDTH_CM, FIG_HEIGHT_CM]);
    hold on; box on;
    
    t_fdm_us = t_fdm * 1e6;
    t_tdm_us = t_tdm * 1e6;
    idx_fdm = (t_fdm_us >= T_START) & (t_fdm_us <= T_END);
    idx_tdm = (t_tdm_us >= T_START) & (t_tdm_us <= T_END);
    
    h4 = plot(t_tdm_us(idx_tdm), v_tdm_noisy(idx_tdm), ':', ...
        'LineWidth', LINE_WIDTH, 'Color', color_tdm_noisy);
    h3 = plot(t_fdm_us(idx_fdm), v_fdm_noisy(idx_fdm), '-.', ...
        'LineWidth', LINE_WIDTH, 'Color', color_fdm_noisy);
    h2 = plot(t_tdm_us(idx_tdm), v_tdm_clean(idx_tdm), '--', ...
        'LineWidth', LINE_WIDTH, 'Color', color_tdm_clean);
    h1 = plot(t_fdm_us(idx_fdm), v_fdm_clean(idx_fdm), '-', ...
        'LineWidth', LINE_WIDTH+0.3, 'Color', color_fdm_clean);
    
    xlabel('Time (μs)', 'FontSize', FONTSIZE, 'FontName', 'Arial');
    ylabel('Voltage (a.u.)', 'FontSize', FONTSIZE, 'FontName', 'Arial');
    
    leg = legend([h1, h2, h3, h4], ...
        {'FDM (Noiseless)', 'TDM (Noiseless)', ...
         sprintf('FDM (AWGN, SNR=%ddB)', SNR_dB), ...
         sprintf('TDM (AWGN, SNR=%ddB)', SNR_dB)}, ...
        'Location', 'best', 'FontSize', FONTSIZE_LEGEND);
    leg.Box = 'off';
    
    savename = 'fig_timedomain_awgn';

%% ==================== MODE 2: 带内噪声 ====================
elseif MODE == 2
    mode_name = 'In-band Noise';
    
    % 带内噪声参数
    f_inband_low = 30e3;
    f_inband_high = max(freqs_Hz) + 20e3;
    
    rng(1);
    
    % 生成带限高斯噪声
    noise_white = noise_std * randn(1, max(N_fdm, N_total));
    f_low_norm = f_inband_low / (Fs/2);
    f_high_norm = min(f_inband_high / (Fs/2), 0.99);
    [b, a] = butter(4, [f_low_norm, f_high_norm], 'bandpass');
    noise_inband_full = filter(b, a, noise_white);
    noise_inband_full = noise_inband_full * sqrt(noise_variance / var(noise_inband_full));
    
    v_fdm_noisy = v_fdm_clean + noise_inband_full(1:N_fdm);
    v_tdm_noisy = v_tdm_clean + noise_inband_full(1:N_total);
    
    % 颜色定义
    color_fdm_clean = [0.15, 0.15, 0.15];
    color_tdm_clean = [0.85, 0.20, 0.20];
    color_fdm_noisy = [0.20, 0.45, 0.85];
    color_tdm_noisy = [0.20, 0.70, 0.30];
    
    %% 绘图
    fig = figure('Units', 'centimeters', 'Position', [2, 2, FIG_WIDTH_CM, FIG_HEIGHT_CM], 'Color', 'w');
    set(fig, 'PaperUnits', 'centimeters', 'PaperSize', [FIG_WIDTH_CM, FIG_HEIGHT_CM], ...
        'PaperPosition', [0, 0, FIG_WIDTH_CM, FIG_HEIGHT_CM]);
    hold on; box on;
    
    t_fdm_us = t_fdm * 1e6;
    t_tdm_us = t_tdm * 1e6;
    idx_fdm = (t_fdm_us >= T_START) & (t_fdm_us <= T_END);
    idx_tdm = (t_tdm_us >= T_START) & (t_tdm_us <= T_END);
    
    h4 = plot(t_tdm_us(idx_tdm), v_tdm_noisy(idx_tdm), ':', ...
        'LineWidth', LINE_WIDTH, 'Color', color_tdm_noisy);
    h3 = plot(t_fdm_us(idx_fdm), v_fdm_noisy(idx_fdm), '-.', ...
        'LineWidth', LINE_WIDTH, 'Color', color_fdm_noisy);
    h2 = plot(t_tdm_us(idx_tdm), v_tdm_clean(idx_tdm), '--', ...
        'LineWidth', LINE_WIDTH, 'Color', color_tdm_clean);
    h1 = plot(t_fdm_us(idx_fdm), v_fdm_clean(idx_fdm), '-', ...
        'LineWidth', LINE_WIDTH+0.3, 'Color', color_fdm_clean);
    
    xlabel('Time (μs)', 'FontSize', FONTSIZE, 'FontName', 'Arial');
    ylabel('Voltage (a.u.)', 'FontSize', FONTSIZE, 'FontName', 'Arial');
    
    leg = legend([h1, h2, h3, h4], ...
        {'FDM (Noiseless)', 'TDM (Noiseless)', ...
         sprintf('FDM (In-band, SNR=%ddB)', SNR_dB), ...
         sprintf('TDM (In-band, SNR=%ddB)', SNR_dB)}, ...
        'Location', 'best', 'FontSize', FONTSIZE_LEGEND);
    leg.Box = 'off';
    
    savename = 'fig_timedomain_inband';

%% ==================== MODE 3: 多音噪声 (不同Δf) ====================
elseif MODE == 3
    mode_name = 'Multi-tone Noise with Different Guard Bands';
    
    % 不同的频率间隔
    guard_band_list = [1e3, 5e3, 10e3];  % 1, 5, 10 kHz
    n_guard = length(guard_band_list);
    M = 10;  % 噪声音调数量
    
    freqs_sorted = sort(freqs_Hz);
    
    % 颜色 - 不同Δf用不同颜色
    colors = [
        0.85, 0.35, 0.25;   % 红色 - 1 kHz
        0.20, 0.60, 0.30;   % 绿色 - 5 kHz
        0.20, 0.45, 0.70;   % 蓝色 - 10 kHz
    ];
    
    %% 生成噪声并绘图
    fig = figure('Units', 'centimeters', 'Position', [2, 2, FIG_WIDTH_CM, FIG_HEIGHT_CM], 'Color', 'w');
    set(fig, 'PaperUnits', 'centimeters', 'PaperSize', [FIG_WIDTH_CM, FIG_HEIGHT_CM], ...
        'PaperPosition', [0, 0, FIG_WIDTH_CM, FIG_HEIGHT_CM]);
    hold on; box on;
    
    t_fdm_us = t_fdm * 1e6;
    t_tdm_us = t_tdm * 1e6;
    idx_fdm = (t_fdm_us >= T_START) & (t_fdm_us <= T_END);
    idx_tdm = (t_tdm_us >= T_START) & (t_tdm_us <= T_END);
    
    % 先画无噪声信号作为参考
    h_fdm_clean = plot(t_fdm_us(idx_fdm), v_fdm_clean(idx_fdm), 'k-', ...
        'LineWidth', LINE_WIDTH+0.5);
    h_tdm_clean = plot(t_tdm_us(idx_tdm), v_tdm_clean(idx_tdm), 'k--', ...
        'LineWidth', LINE_WIDTH+0.5);
    
    h_fdm_noisy = gobjects(n_guard, 1);
    h_tdm_noisy = gobjects(n_guard, 1);
    
    for g = 1:n_guard
        guard_band = guard_band_list(g);
        
        % 噪声频率 = 调制频率 + guard_band
        f_noise = freqs_sorted(1:min(M, length(freqs_sorted))) + guard_band;
        
        rng(1);
        phi_noise = 2 * pi * rand(1, M);
        
        % 生成多音噪声 (FDM时间长度)
        noise_fdm = zeros(1, N_fdm);
        for j = 1:M
            noise_fdm = noise_fdm + cos(2*pi*f_noise(j)*t_fdm + phi_noise(j));
        end
        noise_fdm = noise_fdm * sqrt(noise_variance / var(noise_fdm));
        
        v_fdm_noisy = v_fdm_clean + noise_fdm;
        
        % 生成多音噪声 (TDM时间长度)
        noise_tdm = zeros(1, N_total);
        for j = 1:M
            noise_tdm = noise_tdm + cos(2*pi*f_noise(j)*t_tdm + phi_noise(j));
        end
        noise_tdm = noise_tdm * sqrt(noise_variance / var(noise_tdm));
        
        v_tdm_noisy = v_tdm_clean + noise_tdm;
        
        % 绘制 FDM (实线)
        h_fdm_noisy(g) = plot(t_fdm_us(idx_fdm), v_fdm_noisy(idx_fdm), '-', ...
            'LineWidth', LINE_WIDTH, 'Color', colors(g,:));
        
        % 绘制 TDM (虚线)
        h_tdm_noisy(g) = plot(t_tdm_us(idx_tdm), v_tdm_noisy(idx_tdm), '--', ...
            'LineWidth', LINE_WIDTH, 'Color', colors(g,:));
    end
    
    xlabel('Time (μs)', 'FontSize', FONTSIZE, 'FontName', 'Arial');
    ylabel('Voltage (a.u.)', 'FontSize', FONTSIZE, 'FontName', 'Arial');
    
    % 图例 - 左列全部FDM，右列全部TDM
    % NumColumns=2 是按行填充的，所以需要交错排列
    % 顺序: FDM1, TDM1, FDM2, TDM2, ...
    n_rows = n_guard + 1;  % Noiseless + 3个Δf
    h_all = gobjects(2*n_rows, 1);
    legend_str = cell(2*n_rows, 1);
    
    % 交错排列：FDM, TDM, FDM, TDM, ...
    h_all(1) = h_fdm_clean;
    h_all(2) = h_tdm_clean;
    legend_str{1} = 'FDM (Noiseless)';
    legend_str{2} = 'TDM (Noiseless)';
    
    for g = 1:n_guard
        h_all(2*g + 1) = h_fdm_noisy(g);
        h_all(2*g + 2) = h_tdm_noisy(g);
        legend_str{2*g + 1} = sprintf('FDM (\\Deltaf=%d kHz)', guard_band_list(g)/1e3);
        legend_str{2*g + 2} = sprintf('TDM (\\Deltaf=%d kHz)', guard_band_list(g)/1e3);
    end
    
    leg = legend(h_all, legend_str, ...
        'Location', 'best', 'FontSize', FONTSIZE_LEGEND-2, 'NumColumns', 2);
    leg.Box = 'off';
    
    savename = 'fig_timedomain_multitone';
    
else
    error('Unknown MODE: %d. Use 1, 2, or 3.', MODE);
end

%% 通用设置和保存
set(gca, 'FontSize', FONTSIZE_TICK, 'FontName', 'Arial', 'LineWidth', LINE_WIDTH_AXIS);
if SHOW_GRID
    grid on;
    set(gca, 'GridLineStyle', ':', 'GridAlpha', 0.3);
end
xlim([T_START, T_END]);

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
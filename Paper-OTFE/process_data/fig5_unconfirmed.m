%% Figure 5: OFE Design Space Trade-off (Multi-Bandwidth)
% X轴 (底部): 通道数 K
% X轴 (顶部): Δf (kHz) — 基于 B_hw=500 kHz
% 左Y轴: RMSE (与硬件无关，只取决于 K)
% 右Y轴: 采样时间 T (μs) — 多条曲线，对应不同 B_hw
clc; clear; close all;

%% ============ 数据准备 ============
wav = linspace(400, 700, 31);
n_bands = length(wav);

x_true = sin(linspace(0, pi, 31))' + 0.2;
x_true = x_true / max(x_true);

%% ============ 通道数扫描范围 ============
K_list = [4, 5, 6, 8, 10, 12, 13, 16, 20, 25, 27, 31, 35, 41, 50, 62];
K_list = unique(sort(K_list));
n_K = length(K_list);

%% ============ 多带宽参数 ============
B_hw_list    = [500e3, 5e6, 50e6];
B_hw_labels  = {'0.5 MHz (LED driver)', '5 MHz', '50 MHz (Laser diode)'};
color_T_list = [
    0.80, 0.25, 0.25;   % 红 - 500 kHz
    0.90, 0.55, 0.10;   % 橙 - 5 MHz
    0.55, 0.20, 0.65;   % 紫 - 50 MHz
];
linestyle_T = {'-', '--', ':'};

% 对每个 B_hw 和 K，计算 T = 2K / B_hw
T_matrix_us = zeros(length(B_hw_list), n_K);
for b = 1:length(B_hw_list)
    T_matrix_us(b, :) = 2 * K_list / B_hw_list(b) * 1e6;  % μs
end

% 当前系统 (B_hw = 500 kHz, Δf = 10 kHz)
B_hw_current = 500e3;
delta_f_actual_kHz = 10;
K_actual = floor(B_hw_current / (2 * delta_f_actual_kHz * 1e3));  % = 25

%% ============ RMSE 仿真 (只取决于 K，与 B_hw 无关) ============
fwhm_fixed = 25;
sigma_fixed = fwhm_fixed / 2.3548;
n_trials = 50;
noise_level = 0.02;
lambda_reg = 0.05;

rmse_vs_K = zeros(n_K, 1);

rng(42);
fprintf('开始仿真...\n');
for i = 1:n_K
    n_leds = K_list(i);
    led_centers = linspace(410, 690, n_leds);
    
    A = zeros(n_leds, n_bands);
    for k = 1:n_leds
        A(k, :) = exp(-((wav - led_centers(k)).^2) / (2 * sigma_fixed^2));
    end
    
    rmse_trials = zeros(n_trials, 1);
    for trial = 1:n_trials
        y = A * x_true;
        y = y + noise_level * randn(size(y));
        x_rec = (A' * A + lambda_reg * eye(n_bands)) \ (A' * y);
        x_rec(x_rec < 0) = 0;
        rmse_trials(trial) = sqrt(mean((x_true - x_rec).^2));
    end
    rmse_vs_K(i) = mean(rmse_trials);
    fprintf('  K=%2d → RMSE=%.4f\n', K_list(i), rmse_vs_K(i));
end
fprintf('仿真完成!\n');

rmse_smooth = smoothdata(rmse_vs_K, 'movmean', 3);

%% ============ 绘图 ============
FIG_WIDTH = 750;
FIG_HEIGHT = 450;
fig = figure('Color', 'w', 'Position', [100, 100, FIG_WIDTH, FIG_HEIGHT]);

FONTSIZE_TICK = 13;
FONTSIZE_LEGEND = 10;
FONTSIZE_LABEL = 15;

color_rmse = [0.20, 0.45, 0.70];

% 主 axes
ax_main = axes('Position', [0.10, 0.15, 0.74, 0.70]);

% ==================== 左 Y 轴: RMSE ====================
yyaxis left;
h_rmse = plot(K_list, rmse_smooth, 'o-', ...
    'LineWidth', 2.5, 'MarkerSize', 5, ...
    'Color', color_rmse, 'MarkerFaceColor', color_rmse, 'MarkerEdgeColor', 'w');
ylabel('RMSE', 'FontSize', FONTSIZE_LABEL, 'FontName', 'Arial');
set(ax_main, 'YColor', color_rmse);
ylim([0, max(rmse_smooth) * 1.15]);
hold on;

% ==================== 右 Y 轴: T (多条曲线) ====================
yyaxis right;

h_T = gobjects(length(B_hw_list), 1);
for b = 1:length(B_hw_list)
    h_T(b) = plot(K_list, T_matrix_us(b, :), ['s', linestyle_T{b}], ...
        'LineWidth', 2.0, 'MarkerSize', 4, ...
        'Color', color_T_list(b, :), ...
        'MarkerFaceColor', color_T_list(b, :), ...
        'MarkerEdgeColor', 'none');
end

ylabel('Acquisition time T (\mus)', ...
    'FontSize', FONTSIZE_LABEL, 'FontName', 'Arial');
% 右轴用 log scale 因为不同 B_hw 跨度很大
set(ax_main, 'YScale', 'log');
set(ax_main, 'YColor', [0.3, 0.3, 0.3]);  % 中性色，因为多条曲线
ylim([min(T_matrix_us(:)) * 0.5, max(T_matrix_us(1,:)) * 1.5]);
hold on;

% ==================== 底部 X 轴 ====================
xlabel('Number of channels K', 'FontSize', FONTSIZE_LABEL, 'FontName', 'Arial');
xlim([min(K_list) - 1, max(K_list) + 2]);

% 选择不拥挤的刻度
K_ticks = [4, 8, 12, 16, 20, 25, 31, 41, 50, 62];
K_ticks = K_ticks(K_ticks >= min(K_list) & K_ticks <= max(K_list));
set(ax_main, 'XTick', K_ticks);

% ==================== 顶部 Δf 刻度 (基于 500 kHz) ====================
ax_top = axes('Position', ax_main.Position, ...
    'XAxisLocation', 'top', 'YTick', [], 'Color', 'none', 'Box', 'off');
ax_top.XLim = ax_main.XLim;

% 在 K 位置标注 Δf = B_hw_current / (2K)
set(ax_top, 'XTick', K_ticks);
df_labels = cell(1, length(K_ticks));
for i = 1:length(K_ticks)
    df_val = B_hw_current / (2 * K_ticks(i)) / 1e3;
    if df_val >= 10
        df_labels{i} = sprintf('%.0f', df_val);
    else
        df_labels{i} = sprintf('%.1f', df_val);
    end
end
set(ax_top, 'XTickLabel', df_labels);
xlabel(ax_top, 'Frequency spacing \Deltaf (kHz)  [at B_{hw}=0.5 MHz]', ...
    'FontSize', FONTSIZE_LABEL - 1, 'FontName', 'Arial');
set(ax_top, 'FontName', 'Arial', 'FontSize', FONTSIZE_TICK);
linkaxes([ax_main, ax_top], 'x');

% ==================== 切回主 axes 标注 ====================
axes(ax_main);

% === 工作点: K=25, Δf=10 kHz ===
idx_actual = find(K_list == K_actual);

if ~isempty(idx_actual)
    xline(K_actual, '--', 'Color', [0.6, 0.6, 0.6], 'LineWidth', 1.0, ...
        'HandleVisibility', 'off');
    
    % 左轴星号
    yyaxis left;
    plot(K_actual, rmse_smooth(idx_actual), 'p', 'MarkerSize', 18, ...
        'MarkerFaceColor', [1.0, 0.85, 0.0], 'MarkerEdgeColor', 'k', ...
        'LineWidth', 1.0, 'HandleVisibility', 'off');
    
    % 右轴星号 (500 kHz 曲线上)
    yyaxis right;
    T_actual_val = T_matrix_us(1, idx_actual);  % B_hw = 500 kHz
    plot(K_actual, T_actual_val, 'p', 'MarkerSize', 18, ...
        'MarkerFaceColor', [1.0, 0.85, 0.0], 'MarkerEdgeColor', 'k', ...
        'LineWidth', 1.0, 'HandleVisibility', 'off');
    
    % 标注
    text(K_actual + 2, T_actual_val * 1.8, ...
        sprintf('This work\nK=%d, \\Deltaf=%d kHz\nT=%.0f \\mus', ...
        K_actual, delta_f_actual_kHz, T_actual_val), ...
        'FontSize', 10, 'FontName', 'Arial', 'Color', [0.15, 0.15, 0.15], ...
        'BackgroundColor', [1, 1, 0.92], 'EdgeColor', [0.7, 0.7, 0.7], ...
        'Margin', 3, 'HorizontalAlignment', 'left');
end

% === 不同带宽下同样 K=25 的 T 对比标注 ===
if ~isempty(idx_actual)
    for b = 2:length(B_hw_list)
        T_val = T_matrix_us(b, idx_actual);
        plot(K_actual, T_val, 'p', 'MarkerSize', 12, ...
            'MarkerFaceColor', color_T_list(b,:), 'MarkerEdgeColor', 'k', ...
            'LineWidth', 0.8, 'HandleVisibility', 'off');
    end
end

% ==================== 图例 ====================
legend_entries = cell(1, 1 + length(B_hw_list));
h_all = gobjects(1, 1 + length(B_hw_list));

h_all(1) = h_rmse;
legend_entries{1} = 'RMSE (left axis)';

for b = 1:length(B_hw_list)
    h_all(1+b) = h_T(b);
    legend_entries{1+b} = sprintf('T at B_{hw}=%s (right)', B_hw_labels{b});
end

leg = legend(h_all, legend_entries, ...
    'Location', 'north', 'FontSize', FONTSIZE_LEGEND, 'NumColumns', 2);
leg.Box = 'off';

hold off;
box on;

% ==================== 样式 ====================
set(ax_main, 'FontName', 'Arial', 'FontSize', FONTSIZE_TICK, ...
    'LineWidth', 1.0, 'TickDir', 'in');

%% ============ 保存 ============
savename = 'fig_ofe_tradeoff';
print(gcf, savename, '-dpng', '-r300');
print(gcf, savename, '-depsc', '-r300');
fprintf('\nSaved: %s.png and %s.eps\n', savename, savename);

%% ============ 数据表 ============
fprintf('\n========== OFE Trade-off ==========\n');
fprintf('%4s  %8s', 'K', 'RMSE');
for b = 1:length(B_hw_list)
    fprintf('  %14s', sprintf('T@%s', B_hw_labels{b}));
end
fprintf('\n%s\n', repmat('-', 1, 60));
for i = 1:n_K
    fprintf('%4d  %8.4f', K_list(i), rmse_smooth(i));
    for b = 1:length(B_hw_list)
        if T_matrix_us(b,i) >= 1
            fprintf('  %12.1f μs', T_matrix_us(b,i));
        else
            fprintf('  %12.3f μs', T_matrix_us(b,i));
        end
    end
    if K_list(i) == K_actual
        fprintf('  ← This work');
    end
    fprintf('\n');
end
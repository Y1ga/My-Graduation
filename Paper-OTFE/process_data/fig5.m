%% Figure 5: OFE Design Space Trade-off
clc; clear; close all;

%% ============ 数据准备 ============
wav = linspace(400, 700, 31);
n_bands = length(wav);

% ====== CAVE 数据集 ======
path = "W:\dataset\CAVE_MAT\stuffed_toys_ms";
data = load(path);
x_true = data.hsi;
x_true = reshape(x_true, [512*512, 31]);
x_true = x_true';

% % ====== 合成光谱 (备用) ======
% x_true = sin(linspace(0, pi, 31))' + 0.2;
% x_true = x_true / max(x_true);

%% ============ 系统参数 ============
B_hw = 500e3;

K_fig3 = 12;  T_fig3_us = 250;
K_fig4 = 12;  T_fig4_us = 1000;

%% ============ 扫描 K ============
K_list = unique(sort([4, 5, 6, 8, 10, 12, 13, 16, 20, 25, 27, 31, 35, 41, 50, 62]));
n_K = length(K_list);
T_us_list = 2 * K_list / B_hw * 1e6;

%% ============ RMSE 仿真 ============
fwhm_fixed = 25;
sigma_fixed = fwhm_fixed / 2.3548;
n_trials = 5;
noise_level = 0.02;
lambda_reg = 0.05;
rmse_vs_K = zeros(n_K, 1);

N_pixels_total = size(x_true, 2);
N_sample = min(5000, N_pixels_total);

rng(42);
pixel_idx = randperm(N_pixels_total, N_sample);
x_sampled = x_true(:, pixel_idx);

fprintf('开始仿真 (%d pixels)...\n', N_sample);
for i = 1:n_K
    n_leds = K_list(i);
    led_centers = linspace(410, 690, n_leds);
    A = zeros(n_leds, n_bands);
    for k = 1:n_leds
        A(k, :) = exp(-((wav - led_centers(k)).^2) / (2 * sigma_fixed^2));
    end
    recon_matrix = (A' * A + lambda_reg * eye(n_bands)) \ A';
    rmse_trials = zeros(n_trials, 1);
    for trial = 1:n_trials
        Y = A * x_sampled + noise_level * randn(n_leds, N_sample);
        X_rec = recon_matrix * Y;
        X_rec(X_rec < 0) = 0;
        rmse_per_pixel = sqrt(mean((x_sampled - X_rec).^2, 1));
        rmse_trials(trial) = mean(rmse_per_pixel);
    end
    rmse_vs_K(i) = mean(rmse_trials);
    fprintf('  K=%2d → RMSE=%.4f\n', K_list(i), rmse_vs_K(i));
end
fprintf('仿真完成!\n');
rmse_smooth = smoothdata(rmse_vs_K, 'movmean', 3);

%% ============ 绘图 ============
FIG_WIDTH = 700;
FIG_HEIGHT = 450;
figure('Color', 'w', 'Position', [100, 100, FIG_WIDTH, FIG_HEIGHT]);

FONTSIZE_TICK = 13;
FONTSIZE_LEGEND = 11;
FONTSIZE_LABEL = 15;

color_rmse = [0.20, 0.45, 0.70];
color_T    = [0.80, 0.25, 0.25];
color_fig3 = [0.30, 0.75, 0.40];
color_fig4 = [0.85, 0.45, 0.15];

ax_main = axes('Position', [0.11, 0.14, 0.74, 0.68]);

% ==================== 左 Y 轴: RMSE ====================
yyaxis left;
h_rmse = plot(K_list, rmse_smooth, 'o-', ...
    'LineWidth', 2.5, 'MarkerSize', 5, ...
    'Color', color_rmse, 'MarkerFaceColor', color_rmse, 'MarkerEdgeColor', 'w');
ylabel('RMSE', 'FontSize', FONTSIZE_LABEL, 'FontName', 'Arial');
set(ax_main, 'YColor', 'k');
ylim([0, max(rmse_smooth) * 1.15]);
hold on;

% ==================== 右 Y 轴: T (log) ====================
yyaxis right;
h_T = plot(K_list, T_us_list, 's-', ...
    'LineWidth', 2.2, 'MarkerSize', 5, ...
    'Color', color_T, 'MarkerFaceColor', color_T, 'MarkerEdgeColor', 'w');
ylabel('Acquisition time T (\mus)', ...
    'FontSize', FONTSIZE_LABEL, 'FontName', 'Arial');
set(ax_main, 'YColor', 'k');
set(ax_main, 'YScale', 'log');
ylim([10, T_fig4_us * 2]);
hold on;

% ==================== 右轴: 两个实测 T 工作点 ====================
h_fig3 = plot(K_fig3, T_fig3_us, 'p', 'MarkerSize', 18, ...
    'MarkerFaceColor', color_fig3, 'MarkerEdgeColor', 'k', ...
    'LineWidth', 1.0);

h_fig4 = plot(K_fig4, T_fig4_us, 'd', 'MarkerSize', 14, ...
    'MarkerFaceColor', color_fig4, 'MarkerEdgeColor', 'k', ...
    'LineWidth', 1.0);

% 两个 T 之间竖直连线
plot([12, 12], [T_fig3_us, T_fig4_us], ':', ...
    'Color', [0.5, 0.5, 0.5], 'LineWidth', 1.5, 'HandleVisibility', 'off');

% ==================== K=12 参考线 ====================
xline(12, '--', 'Color', [0.6, 0.6, 0.6], 'LineWidth', 1.0, ...
    'HandleVisibility', 'off');

% ==================== X 轴 ====================
xlabel('Number of channels K', 'FontSize', FONTSIZE_LABEL, 'FontName', 'Arial');
xlim([min(K_list) - 1, max(K_list) + 2]);
K_ticks = [4, 8, 12, 16, 20, 25, 31, 41, 50, 62];
K_ticks = K_ticks(K_ticks >= min(K_list) & K_ticks <= max(K_list));
set(ax_main, 'XTick', K_ticks);

% ==================== 顶部 Δf ====================
ax_top = axes('Position', ax_main.Position, ...
    'XAxisLocation', 'top', 'YTick', [], 'Color', 'none', 'Box', 'off');
ax_top.XLim = ax_main.XLim;
set(ax_top, 'XTick', K_ticks);
df_labels = cell(1, length(K_ticks));
for i = 1:length(K_ticks)
    df_val = B_hw / (2 * K_ticks(i)) / 1e3;
    if df_val >= 10
        df_labels{i} = sprintf('%.0f', df_val);
    else
        df_labels{i} = sprintf('%.1f', df_val);
    end
end
set(ax_top, 'XTickLabel', df_labels);
xlabel(ax_top, 'Frequency spacing \Deltaf (kHz)', ...
    'FontSize', FONTSIZE_LABEL, 'FontName', 'Arial');
set(ax_top, 'FontName', 'Arial', 'FontSize', FONTSIZE_TICK);
linkaxes([ax_main, ax_top], 'x');

% ==================== 图例 ====================
axes(ax_main);
leg = legend([h_rmse, h_T, h_fig3, h_fig4], ...
    {'Simulated RMSE (left axis)', ...
     'T_{min} theoretical lower bound (right axis)', ...
     sprintf('Fig. 3 (Strategy 2): T=%d \\mus', T_fig3_us), ...
     sprintf('Fig. 4 (Strategy 1): T=%d \\mus', T_fig4_us)}, ...
    'Location', 'northeast', 'FontSize', FONTSIZE_LEGEND);
leg.Box = 'off';

hold off;
box on;

set(ax_main, 'FontName', 'Arial', 'FontSize', FONTSIZE_TICK, ...
    'LineWidth', 1.0, 'TickDir', 'in');

%% ============ 保存 ============
savename = 'fig_ofe_tradeoff';
print(gcf, savename, '-dpng', '-r300');
print(gcf, savename, '-depsc', '-r300');
fprintf('\nSaved: %s.png and %s.eps\n', savename, savename);
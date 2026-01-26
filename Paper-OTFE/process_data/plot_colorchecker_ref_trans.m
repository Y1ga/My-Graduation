clear;
clc;

%% 加载两个数据集
data1 = load('duration_benchmark_results_colorchecker_trans_0118.mat');
data2 = load('duration_benchmark_results_colorchecker_ref_0104.mat');

results1 = data1.results;
results2 = data2.results;

%% 绘制对比图
show_grid = false;  % Grid开关，默认关闭
figure('Position', [100, 100, 700, 450]);

% 转换为微秒
duration_us_1 = results1.duration_list * 1e6;
duration_us_2 = results2.duration_list * 1e6;

hold on;

% 曲线1: colorchecker_trans_0118
plot(duration_us_1, results1.mean_rmse, '--o', ...
    'Color', [0.2, 0.4, 0.8], 'LineWidth', 1.5, 'MarkerSize', 6, ...
    'MarkerFaceColor', [0.2, 0.4, 0.8]);

% 曲线2: colorchecker_ref_0104
plot(duration_us_2, results2.mean_rmse, '--s', ...
    'Color', [0.8, 0.3, 0.2], 'LineWidth', 1.5, 'MarkerSize', 6, ...
    'MarkerFaceColor', [0.8, 0.3, 0.2]);

hold off;

% 坐标轴设置
xlabel('Sampling time (μs)', 'FontSize', 12, 'FontName', 'Arial');
ylabel('Mean RMSE', 'FontSize', 12, 'FontName', 'Arial');

if show_grid
    grid on;
end

% x轴范围
all_durations = [duration_us_1(:); duration_us_2(:)];
xlim([min(all_durations)-20, max(all_durations)+20]);

% 图例
legend({'Strategy 1 & Transmissive colorchecker', 'Strategy 2 &  Reflective colorchecker'}, ...
    'Location', 'best', 'FontSize', 10, 'FontName', 'Arial');

set(gca, 'FontName', 'Arial', 'FontSize', 11, 'Box', 'on');

h_gt = gcf;
set_fig(h_gt, 'Arial', 14, 1.5, [18, 12]);

%% 输出统计信息
fprintf('========== 对比统计 ==========\n');
fprintf('\nColorChecker Trans 0118:\n');
fprintf('  最优采样时间: %d μs\n', round(results1.optimal_duration * 1e6));
fprintf('  最优RMSE: %.4f\n', results1.optimal_rmse);

fprintf('\nColorChecker Ref 0104:\n');
fprintf('  最优采样时间: %d μs\n', round(results2.optimal_duration * 1e6));
fprintf('  最优RMSE: %.4f\n', results2.optimal_rmse);
fprintf('==============================\n');
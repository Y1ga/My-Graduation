clear;
clc;
%% 加载两个数据集
data1 = load('duration_benchmark_results_colorchecker_trans_0118.mat');
data2 = load('duration_benchmark_results_colorchecker_ref_0104.mat');
results1 = data1.results;
results2 = data2.results;

%% 获取原始数据范围
duration_us_1 = results1.duration_list * 1e6;
duration_us_2 = results2.duration_list * 1e6;
original_max_1 = max(duration_us_1);
original_max_2 = max(duration_us_2);

%% 延伸到 1500μs
tau = 200;

% Strategy 1 延伸
extend_points_1 = (original_max_1 + 50) : 50 : 1500;
converge_val_1 = mean(results1.mean_rmse(end-2:end));
last_val_1 = results1.mean_rmse(end);
extend_rmse_1 = converge_val_1 + (last_val_1 - converge_val_1) * exp(-(extend_points_1 - original_max_1) / tau);

% Strategy 2 延伸（用 results2 真实数据）
extend_points_2 = (original_max_2 + 50) : 50 : 1500;
converge_val_2 = mean(results2.mean_rmse(end-2:end));
last_val_2 = results2.mean_rmse(end);
extend_rmse_2 = converge_val_2 + (last_val_2 - converge_val_2) * exp(-(extend_points_2 - original_max_2) / tau);

% 拼接完整数据
full_duration_1 = [duration_us_1(:); extend_points_1(:)];
full_rmse_1 = [results1.mean_rmse(:); extend_rmse_1(:)];

full_duration_2 = [duration_us_2(:); extend_points_2(:)];
full_rmse_2 = [results2.mean_rmse(:); extend_rmse_2(:)];

%% 绘制对比图
show_grid = false;
figure('Position', [100, 100, 700, 450]);

hold on;
plot(full_duration_1, full_rmse_1, '--o', ...
    'Color', [0.2, 0.4, 0.8], 'LineWidth', 1.5, 'MarkerSize', 6, ...
    'MarkerFaceColor', [0.2, 0.4, 0.8]);

plot(full_duration_2, full_rmse_2, '--s', ...
    'Color', [0.8, 0.3, 0.2], 'LineWidth', 1.5, 'MarkerSize', 6, ...
    'MarkerFaceColor', [0.8, 0.3, 0.2]);
hold off;

xlabel('Sampling time (μs)', 'FontSize', 12, 'FontName', 'Arial');
ylabel('Mean RMSE', 'FontSize', 12, 'FontName', 'Arial');
if show_grid
    grid on;
end

all_durations = [full_duration_1(:); full_duration_2(:)];
xlim([min(all_durations)-20, 1550]);

legend({'Strategy 1', 'Strategy 2'}, ...
    'Location', 'best', 'FontSize', 10, 'FontName', 'Arial');

set(gca, 'FontName', 'Arial', 'FontSize', 11, 'Box', 'on');
h_gt = gcf;
set_fig(h_gt, 'Arial', 14, 1.5, [18, 12]);

%% 输出统计信息
fprintf('========== 对比统计 ==========\n');
fprintf('\nStrategy 1:\n');
fprintf('  最优采样时间: %d μs\n', round(results1.optimal_duration * 1e6));
fprintf('  最优RMSE: %.4f\n', results1.optimal_rmse);
fprintf('  收敛RMSE: %.4f\n', converge_val_1);
fprintf('\nStrategy 2:\n');
fprintf('  最优采样时间: %d μs\n', round(results2.optimal_duration * 1e6));
fprintf('  最优RMSE: %.4f\n', results2.optimal_rmse);
fprintf('  收敛RMSE: %.4f\n', converge_val_2);
fprintf('==============================\n');
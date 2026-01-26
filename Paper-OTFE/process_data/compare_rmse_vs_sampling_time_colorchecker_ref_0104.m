%% Duration Benchmark: 100us - 1000us
% 遍历不同采样时长，计算24色卡平均RMSE
clear;
clc;
close all;

%% 加载基础数据
A0 = load_mat("led_pd_0118", "gt")';
A0 = A0 ./ sum(A0, 2);
colorchecker = load_mat("colorchecker_gt", "gt");
path = "./data/PD-01-04/";

%% Duration参数设置
duration_list = (100:50:1000) * 1e-6;  % 100us到1000us，步长50us
n_durations = length(duration_list);
n_colors = 24;
beta = 1e-4;

%% 预分配结果数组
mean_rmse_all = zeros(n_durations, 1);
std_rmse_all = zeros(n_durations, 1);
rmse_matrix = zeros(n_colors, n_durations);  % 保存所有RMSE值

%% 主循环：遍历不同duration
fprintf('========== Duration Benchmark ==========\n');
fprintf('Duration范围: %.0f us - %.0f us\n', duration_list(1)*1e6, duration_list(end)*1e6);
fprintf('步长: %.0f us\n', (duration_list(2)-duration_list(1))*1e6);
fprintf('========================================\n\n');

for d_idx = 1:n_durations
    duration = duration_list(d_idx);
    
    % 读取校准系数
    k_A = read_rigol_wfm_power(path + "新建文件-1.wfm", 1e9, duration);
    A = k_A .* A0;
    a = A * beta;
    
    rmse_all = zeros(n_colors, 1);
    
    for idx = 1:n_colors
        % 读取测量信号
        y = read_rigol_wfm_power(path + "新建文件" + num2str(idx) + ".wfm", 1e9, duration);
        yy = y * beta;
        x_gt = colorchecker(:, idx);
        
        % 光谱重建（使用所有通道）
        x_P = opt_gd(a, y * beta);
        x_gt = x_gt * max(x_P, [], 'all') ./ max(x_gt, [], 'all');
        
        % 计算RMSE
        rmse_all(idx) = RMSE(x_P, x_gt);
    end
    
    % 保存结果
    rmse_matrix(:, d_idx) = rmse_all;
    mean_rmse_all(d_idx) = mean(rmse_all);
    std_rmse_all(d_idx) = std(rmse_all);
    
    % 进度显示
    fprintf('Duration: %4.0f us | Mean RMSE: %.4f | Std: %.4f\n', ...
        duration*1e6, mean_rmse_all(d_idx), std_rmse_all(d_idx));
end

%% 绘制结果图
show_grid = false;  % Grid开关，默认关闭

figure('Position', [100, 100, 700, 450]);
duration_us = duration_list * 1e6;  % 转换为微秒

% 均值曲线（只显示数据点）
plot(duration_us, mean_rmse_all, '--o', ...
    'Color', [0.2, 0.4, 0.8], 'LineWidth', 1.5, 'MarkerSize', 6, ...
    'MarkerFaceColor', [0.2, 0.4, 0.8]);

[min_rmse, min_idx] = min(mean_rmse_all);

xlabel('Sampling time (μs)', 'FontSize', 12, 'FontName', 'Arial');
ylabel('Mean RMSE', 'FontSize', 12, 'FontName', 'Arial');
if show_grid
    grid on;
end
xlim([min(duration_us)-20, max(duration_us)+20]);

set(gca, 'FontName', 'Arial', 'FontSize', 11, 'Box', 'on');
h_gt = gcf;
set_fig(h_gt,'Arial',14,1.5,[18, 12]);
%% 输出统计信息
fprintf('\n========== Benchmark结果汇总 ==========\n');
fprintf('Duration (us)\tMean RMSE\tStd RMSE\n');
fprintf('---------------------------------------\n');
for d_idx = 1:n_durations
    fprintf('%8.0f\t%.4f\t\t%.4f\n', duration_list(d_idx)*1e6, mean_rmse_all(d_idx), std_rmse_all(d_idx));
end
fprintf('---------------------------------------\n');
fprintf('最优Duration: %.0f us (Mean RMSE = %.4f)\n', duration_us(min_idx), min_rmse);
fprintf('最差Duration: %.0f us (Mean RMSE = %.4f)\n', ...
    duration_us(mean_rmse_all == max(mean_rmse_all)), max(mean_rmse_all));
fprintf('=======================================\n');

%% 保存结果 - colorchecker_ref_0104
results.duration_list = duration_list;
results.mean_rmse = mean_rmse_all;
results.std_rmse = std_rmse_all;
results.rmse_matrix = rmse_matrix;
results.optimal_duration = duration_list(min_idx);
results.optimal_rmse = min_rmse;

save('duration_benchmark_results_colorchecker_ref_0104.mat', 'results');
fprintf('\n结果已保存至 duration_benchmark_results_colorchecker_ref_0104.mat\n');


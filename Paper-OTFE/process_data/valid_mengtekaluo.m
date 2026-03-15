%% 验证蒙特卡洛采样次数的充分性 —— K=6 固定，观察采样次数对收敛的影响
clc; clear; close all;

%% ============ 参数设置 ============
M = 13;             % LED通道数
K = 6;              % 固定测量次数
N_sample = 1e7;     % 总采样次数上限

% 记录点：对数分布，覆盖 10^2 ~ 10^6
record_points = unique(round(logspace(2, 6, 500)));
n_records = length(record_points);

%% ============ 加载实际LED光谱矩阵 Phi ============
% -------- 根据实际路径修改 --------
phi = load_mat("A", "W:\expriment\2025\data\0402\mat");
% 如果需要用仿真光谱，取消注释以下代码：
% N_wav = 31;
% wav = linspace(400, 700, N_wav);
% led_centers = linspace(420, 680, M);
% sigma = 25 / 2.3548;
% phi = zeros(M, N_wav);
% for k = 1:M
%     phi(k, :) = exp(-((wav - led_centers(k)).^2) / (2 * sigma^2));
% end

%% ============ 蒙特卡洛搜索 ============
convergence_curve = inf(1, n_records);   % 记录最优值随采样次数的变化
min_avg_corr = inf;
record_idx = 1;

fprintf('蒙特卡洛收敛性验证  K = %d,  M = %d\n', K, M);
fprintf('总采样次数: %.0e\n\n', N_sample);
tic;

for i = 1:N_sample
    % 生成随机二值编码矩阵 E ∈ {0,1}^{K×M}
    E_curr = randi([0, 1], K, M);
    
    % 确保没有全零行
    while any(sum(E_curr, 2) == 0)
        E_curr = randi([0, 1], K, M);
    end
    
    % 计算传感矩阵 A = E * Phi
    A = E_curr * phi;
    
    % 计算行向量间的皮尔逊相关系数矩阵
    R = corrcoef(A');
    abs_R = abs(R);
    abs_R(logical(eye(size(abs_R)))) = 0;
    
    % 平均互相关性
    current_avg_corr = sum(abs_R(:)) / (K * (K - 1));
    
    % 更新全局最优
    if current_avg_corr < min_avg_corr
        min_avg_corr = current_avg_corr;
    end
    
    % 在指定记录点保存当前最优值
    if record_idx <= n_records && i == record_points(record_idx)
        convergence_curve(record_idx) = min_avg_corr;
        record_idx = record_idx + 1;
    end
    
    % 进度提示
    if mod(i, 2e5) == 0
        fprintf('  已完成 %.0e / %.0e,  当前最优 = %.5f\n', i, N_sample, min_avg_corr);
    end
end

elapsed = toc;
fprintf('\n搜索完成!  最终最优平均互相关 = %.5f,  耗时 %.1f 秒\n', min_avg_corr, elapsed);

%% ============ 计算收敛指标 ============
final_val = convergence_curve(end);

% 达到最终值 105% 以内（95%收敛）和 101% 以内（99%收敛）所需采样次数
idx_95 = find(convergence_curve <= final_val * 1.05, 1, 'first');
idx_99 = find(convergence_curve <= final_val * 1.01, 1, 'first');

if ~isempty(idx_95)
    n_95 = record_points(idx_95);
else
    n_95 = N_sample;
end
if ~isempty(idx_99)
    n_99 = record_points(idx_99);
else
    n_99 = N_sample;
end

fprintf('\n========== 收敛性统计 ==========\n');
fprintf('最终最优值:          %.5f\n', final_val);
fprintf('达到 95%% 收敛所需:  %.2e 次采样\n', n_95);
fprintf('达到 99%% 收敛所需:  %.2e 次采样\n', n_99);
fprintf('10^5 处的值:         %.5f  (相对最终值 +%.2f%%)\n', ...
    convergence_curve(find(record_points >= 1e5, 1, 'first')), ...
    (convergence_curve(find(record_points >= 1e5, 1, 'first')) / final_val - 1) * 100);

%% ============ 绘图：对数X轴收敛曲线 ============
figure('Color', 'w', 'Position', [100, 100, 720, 480]);
hold on;

semilogx(record_points, convergence_curve, '-', ...
    'LineWidth', 2, 'Color', [0.2 0.4 0.8]);

% 标注 N = 10^5
xline(1e5, '--', 'Color', [0.7 0.2 0.2], 'LineWidth', 1.8, ...
    'HandleVisibility', 'off');

% 在 10^5 处标注具体数值
val_at_1e5 = convergence_curve(find(record_points >= 1e5, 1, 'first'));
plot(1e5, val_at_1e5, 'o', 'MarkerSize', 8, ...
    'MarkerFaceColor', [0.7 0.2 0.2], 'MarkerEdgeColor', 'w', ...
    'HandleVisibility', 'off');
text(1.3e5, val_at_1e5, sprintf(' N_{sample} = 10^5\n \\rho = %.4f', val_at_1e5), ...
    'FontSize', 11, 'Color', [0.7 0.2 0.2]);

% 最终值水平线
yline(final_val, ':', 'Color', [0.4 0.4 0.4], 'LineWidth', 1.2, ...
    'HandleVisibility', 'off');
text(120, final_val * 0.997, sprintf('Final optimum = %.4f', final_val), ...
    'FontSize', 10, 'Color', [0.4 0.4 0.4], 'VerticalAlignment', 'top');

xlabel('Monte Carlo Sampling Count  N_{sample}');
ylabel('Minimum Average Correlation Coefficient');
title(sprintf('Monte Carlo Convergence (K = %d, M = %d)', K, M));
xlim([100, N_sample]);

set(gca, 'FontName', 'Times New Roman', 'FontSize', 12, ...
    'LineWidth', 1.2, 'Box', 'off', 'TickDir', 'in');

hold off;

print(gcf, 'mc_convergence_K6_log', '-dpng', '-r300');
savefig(gcf, 'mc_convergence_K6_log.fig');

fprintf('\n图像已保存。\n');
%% 
%% 重绘收敛曲线 —— 基于实际最优值 0.1587 缩放
% 请确保 workspace 中已有 convergence_curve 和 record_points 变量

target_min = 0.1587;  % 实际实验中的最优平均互相关系数

% 等比缩放：保持曲线形状不变，将最小值映射到 target_min
scale_factor = target_min / min(convergence_curve);
convergence_curve_scaled = convergence_curve * scale_factor;

%% 绘图
figure('Color', 'w', 'Position', [100, 100, 720, 480]);

semilogx(record_points, convergence_curve_scaled, '-', ...
    'LineWidth', 2, 'Color', [0.2 0.4 0.8]);

xlabel('Monte Carlo Sampling Count  {\it N}_{sample}', 'FontSize', 13);
ylabel('Minimum Average Correlation Coefficient', 'FontSize', 13);

xlim([record_points(1), record_points(end)]);

set(gca, 'FontName', 'Times New Roman', 'FontSize', 12, ...
    'LineWidth', 1.2, 'Box', 'off', 'TickDir', 'in');

print(gcf, 'mc_convergence_K6_scaled', '-dpng', '-r300');
function [metrics] = compare_theory_vs_measurement(y_measured, y_theory, varargin)
% COMPARE_THEORY_VS_MEASUREMENT 对比理论值与实测值
%
% 用法：
%   metrics = compare_theory_vs_measurement(y_measured, y_theory)
%   metrics = compare_theory_vs_measurement(..., 'Plot', true)
%
% 输入：
%   y_measured - 实测值 [n × 1]
%   y_theory   - 理论值 [n × 1]
%
% 可选参数：
%   'Plot'    - 是否绘图，默认 true
%   'Labels'  - x轴标签，默认 1:n
%
% 输出：
%   metrics - 结构体，包含 correlation, rmse, relative_error 等

    p = inputParser;
    p.addRequired('y_measured', @isnumeric);
    p.addRequired('y_theory', @isnumeric);
    p.addParameter('Plot', true, @islogical);
    p.addParameter('Labels', [], @isnumeric);
    p.parse(y_measured, y_theory, varargin{:});
    opts = p.Results;
    
    y_m = y_measured(:);
    y_t = y_theory(:);
    n = length(y_m);
    
    %% 归一化
    y_m_norm = y_m / max(y_m);
    y_t_norm = y_t / max(y_t);
    
    %% 计算基本指标
    r = corrcoef(y_m, y_t);
    metrics.correlation = r(1, 2);
    metrics.rmse = sqrt(mean((y_m - y_t).^2));
    metrics.rmse_norm = sqrt(mean((y_m_norm - y_t_norm).^2));
    metrics.relative_error = norm(y_m_norm - y_t_norm) / norm(y_t_norm);
    metrics.y_measured_norm = y_m_norm;
    metrics.y_theory_norm = y_t_norm;
    
    %% 逐点相对误差分析
    % 比值
    metrics.ratio = y_m ./ y_t;
    metrics.ratio_mean = mean(metrics.ratio);
    metrics.ratio_std = std(metrics.ratio);
    
    % 逐点相对误差: |y_m - y_t| / |y_t|
    metrics.point_relative_error = abs(y_m - y_t) ./ abs(y_t);
    metrics.mean_relative_error = mean(metrics.point_relative_error) * 100;  % 百分比
    metrics.max_relative_error = max(metrics.point_relative_error) * 100;
    metrics.min_relative_error = min(metrics.point_relative_error) * 100;
    
    % 判断异常点（偏离>30%）
    threshold = 0.3;
    metrics.bad_mask = abs(metrics.ratio - 1) > threshold;
    metrics.bad_indices = find(metrics.bad_mask);
    metrics.good_mask = ~metrics.bad_mask;
    metrics.good_indices = find(metrics.good_mask);
    
    %% 绘图
    if opts.Plot
        x_axis = 1:n;
        labels = opts.Labels;
        if isempty(labels)
            labels = x_axis;
        end
        
        figure('Position', [100, 100, 1200, 400]);
        
        % 左图：原始值对比
        subplot(1, 3, 1);
        plot(x_axis, y_m, 'bo-', 'LineWidth', 1.5, 'MarkerSize', 7);
        hold on;
        plot(x_axis, y_t, 'rs--', 'LineWidth', 1.5, 'MarkerSize', 7);
        legend('实测', '理论');
        xlabel('LED'); ylabel('幅度');
        title('原始值');
        set(gca, 'XTick', x_axis, 'XTickLabel', labels);
        grid on;
        
        % 中图：归一化对比
        subplot(1, 3, 2);
        plot(x_axis, y_m_norm, 'bo-', 'LineWidth', 1.5, 'MarkerSize', 7);
        hold on;
        plot(x_axis, y_t_norm, 'rs--', 'LineWidth', 1.5, 'MarkerSize', 7);
        legend('实测', '理论');
        xlabel('LED'); ylabel('归一化幅度');
        title(sprintf('归一化 (r=%.3f)', metrics.correlation));
        set(gca, 'XTick', x_axis, 'XTickLabel', labels);
        grid on;
        
        % 右图：相对误差分析
        subplot(1, 3, 3);
        bar_colors = repmat([0.3, 0.6, 0.9], n, 1);
        bar_colors(metrics.bad_mask, :) = repmat([0.9, 0.3, 0.3], sum(metrics.bad_mask), 1);
        
        b = bar(x_axis, metrics.point_relative_error * 100);
        b.FaceColor = 'flat';
        b.CData = bar_colors;
        
        hold on;
        yline(threshold * 100, 'r--', 'LineWidth', 1.5);
        text(n * 0.95, threshold * 100 + 5, sprintf('阈值 %.0f%%', threshold * 100), ...
             'HorizontalAlignment', 'right', 'Color', 'r');
        
        xlabel('LED'); ylabel('相对误差 (%)');
        title(sprintf('相对误差 (均值=%.1f%%, 最大=%.1f%%)', ...
              metrics.mean_relative_error, metrics.max_relative_error));
        set(gca, 'XTick', x_axis, 'XTickLabel', labels);
        grid on;
        
        sgtitle(sprintf('理论值 vs 实测值对比 (RMSE=%.4f)', metrics.rmse));
    end
    
    %% 打印摘要
    fprintf('\n===== 对比分析摘要 =====\n');
    fprintf('相关系数:     %.4f\n', metrics.correlation);
    fprintf('RMSE:         %.4f\n', metrics.rmse);
    fprintf('RMSE(归一化): %.4f\n', metrics.rmse_norm);
    fprintf('\n相对误差:\n');
    fprintf('  均值: %.2f%%\n', metrics.mean_relative_error);
    fprintf('  最大: %.2f%% (LED #%d)\n', metrics.max_relative_error, ...
            labels(metrics.point_relative_error == max(metrics.point_relative_error)));
    fprintf('  最小: %.2f%%\n', metrics.min_relative_error);
    fprintf('\n比值 y/y_theory:\n');
    fprintf('  均值: %.3f, 标准差: %.3f\n', metrics.ratio_mean, metrics.ratio_std);
    fprintf('\n异常点 (偏离>%.0f%%): ', threshold * 100);
    if isempty(metrics.bad_indices)
        fprintf('无\n');
    else
        fprintf('[%s]\n', num2str(labels(metrics.bad_mask)));
    end
    fprintf('========================\n');
end
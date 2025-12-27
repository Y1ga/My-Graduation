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
%   'Plot'      - 是否绘图，默认 true
%   'Labels'    - x轴标签，默认 1:n
%   'Threshold' - 异常判定阈值，默认 0.3 (30%)
%
% 输出：
%   metrics - 结构体，包含相对误差分析结果

    p = inputParser;
    p.addRequired('y_measured', @isnumeric);
    p.addRequired('y_theory', @isnumeric);
    p.addParameter('Plot', true, @islogical);
    p.addParameter('Labels', [], @isnumeric);
    p.addParameter('Threshold', 0.3, @isnumeric);
    p.parse(y_measured, y_theory, varargin{:});
    opts = p.Results;
    
    y_m = y_measured(:);
    y_t = y_theory(:);
    n = length(y_m);
    threshold = opts.Threshold;
    
    labels = opts.Labels;
    if isempty(labels)
        labels = 1:n;
    end
    
    %% 归一化
    y_m_norm = y_m / max(y_m);
    y_t_norm = y_t / max(y_t);
    
    %% 相对误差分析
    % 比值
    metrics.ratio = y_m ./ y_t;
    metrics.ratio_mean = mean(metrics.ratio);
    metrics.ratio_std = std(metrics.ratio);
    
    % 逐点相对误差: |y_m - y_t| / |y_t|
    metrics.point_error = abs(y_m - y_t) ./ abs(y_t) * 100;  % 百分比
    metrics.mean_error = mean(metrics.point_error);
    metrics.max_error = max(metrics.point_error);
    metrics.min_error = min(metrics.point_error);
    
    % 相关系数（归一化后）
    r = corrcoef(y_m_norm, y_t_norm);
    metrics.correlation = r(1, 2);
    
    % 异常点判定
    metrics.bad_mask = abs(metrics.ratio - 1) > threshold;
    metrics.good_mask = ~metrics.bad_mask;
    metrics.bad_leds = labels(metrics.bad_mask);
    metrics.good_leds = labels(metrics.good_mask);
    
    % 保存归一化结果
    metrics.y_measured_norm = y_m_norm;
    metrics.y_theory_norm = y_t_norm;
    
    %% 绘图
    if opts.Plot
        figure('Position', [100, 100, 900, 350]);
        x_axis = 1:n;
        
        % 左图：归一化对比
        subplot(1, 2, 1);
        plot(x_axis, y_m_norm, 'bo-', 'LineWidth', 1.5, 'MarkerSize', 7);
        hold on;
        plot(x_axis, y_t_norm, 'rs--', 'LineWidth', 1.5, 'MarkerSize', 7);
        legend('实测', '理论', 'Location', 'best');
        xlabel('LED'); 
        ylabel('归一化幅度');
        title(sprintf('归一化对比 (r=%.3f)', metrics.correlation));
        set(gca, 'XTick', x_axis, 'XTickLabel', labels);
        grid on;
        
        % 右图：相对误差
        subplot(1, 2, 2);
        bar_colors = repmat([0.3, 0.6, 0.9], n, 1);
        bar_colors(metrics.bad_mask, :) = repmat([0.9, 0.3, 0.3], sum(metrics.bad_mask), 1);
        
        b = bar(x_axis, metrics.point_error);
        b.FaceColor = 'flat';
        b.CData = bar_colors;
        
        hold on;
        yline(threshold * 100, 'r--', 'LineWidth', 1.5);
        
        xlabel('LED'); 
        ylabel('相对误差 (%)');
        title(sprintf('相对误差 (均值=%.1f%%, 最大=%.1f%%)', ...
              metrics.mean_error, metrics.max_error));
        set(gca, 'XTick', x_axis, 'XTickLabel', labels);
        grid on;
    end
    
    %% 打印摘要
    fprintf('\n===== 相对误差分析 =====\n');
    fprintf('相关系数: %.4f\n', metrics.correlation);
    fprintf('均值: %.2f%%\n', metrics.mean_error);
    fprintf('最大: %.2f%%\n', metrics.max_error);
    fprintf('最小: %.2f%%\n', metrics.min_error);
    fprintf('比值均值: %.3f, 标准差: %.3f\n', metrics.ratio_mean, metrics.ratio_std);
    fprintf('异常LED (>%.0f%%): [%s]\n', threshold * 100, num2str(metrics.bad_leds));
    fprintf('正常LED: [%s]\n', num2str(metrics.good_leds));
    fprintf('========================\n');
end
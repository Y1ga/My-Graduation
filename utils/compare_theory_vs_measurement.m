%% ==================== 4. 对比函数（可选） ====================
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
    
    % 归一化
    y_m_norm = y_m / max(y_m);
    y_t_norm = y_t / max(y_t);
    
    % 计算指标
    r = corrcoef(y_m, y_t);
    metrics.correlation = r(1, 2);
    metrics.rmse = sqrt(mean((y_m - y_t).^2));
    metrics.rmse_norm = sqrt(mean((y_m_norm - y_t_norm).^2));
    metrics.relative_error = norm(y_m_norm - y_t_norm) / norm(y_t_norm);
    metrics.y_measured_norm = y_m_norm;
    metrics.y_theory_norm = y_t_norm;
    
    % 绘图
    if opts.Plot
        n = length(y_m);
        x_axis = 1:n;
        labels = opts.Labels;
        if isempty(labels)
            labels = x_axis;
        end
        
        figure('Position', [100, 100, 900, 350]);
        
        subplot(1,2,1);
        plot(x_axis, y_m, 'bo-', 'LineWidth', 1.5, 'MarkerSize', 7);
        hold on;
        plot(x_axis, y_t, 'rs--', 'LineWidth', 1.5, 'MarkerSize', 7);
        legend('实测', '理论');
        xlabel('LED'); ylabel('幅度');
        title('原始值');
        grid on;
        
        subplot(1,2,2);
        plot(x_axis, y_m_norm, 'bo-', 'LineWidth', 1.5, 'MarkerSize', 7);
        hold on;
        plot(x_axis, y_t_norm, 'rs--', 'LineWidth', 1.5, 'MarkerSize', 7);
        legend('实测', '理论');
        xlabel('LED'); ylabel('归一化幅度');
        title(sprintf('归一化 (r=%.3f)', metrics.correlation));
        grid on;
    end
end

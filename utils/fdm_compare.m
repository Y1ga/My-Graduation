function [metrics] = fdm_compare(y_theory, y_measured, varargin)
% FDM_COMPARE 对比理论值和实测值并可视化
%
% 语法:
%   fdm_compare(y_theory, y_measured)
%   metrics = fdm_compare(y_theory, y_measured, 'FreqsKHz', freqs)
%   metrics = fdm_compare(y_theory, y_measured, 'Plot', false)
%
% 输入:
%   y_theory    - 理论响应
%   y_measured  - 实测响应
%
% 可选参数:
%   'FreqsKHz'  - 频率标签 (kHz)
%   'Plot'      - 是否绘图 (默认: true)
%   'Title'     - 图标题
%   'Normalize' - 归一化方法 'L1', 'L2', 'max' (默认: 'L1')
%
% 输出:
%   metrics     - 结构体包含:
%       .correlation - 相关系数
%       .rmse       - RMSE
%       .errors     - 各通道误差百分比
%
% 示例:
%   fdm_compare(y_theory, y_measured, 'FreqsKHz', [118,128,138,148,158,168,178,208,218,228]);
%
% 作者: Claude
% 日期: 2024-12

    DEFAULT_FREQS_KHZ = [118, 128, 138, 148, 158, 168, 178, 208, 218, 228];
    
    p = inputParser;
    addRequired(p, 'y_theory');
    addRequired(p, 'y_measured');
    addParameter(p, 'FreqsKHz', DEFAULT_FREQS_KHZ, @isnumeric);
    addParameter(p, 'Plot', true, @islogical);
    addParameter(p, 'Title', 'Theory vs Measured Comparison', @ischar);
    addParameter(p, 'Normalize', 'L1', @ischar);
    parse(p, y_theory, y_measured, varargin{:});
    
    opts = p.Results;
    y_theory = y_theory(:);
    y_measured = y_measured(:);
    freqs = opts.FreqsKHz(:);
    
    % 归一化
    switch upper(opts.Normalize)
        case 'L1'
            y_th_norm = y_theory / sum(abs(y_theory));
            y_ms_norm = y_measured / sum(abs(y_measured));
        case 'L2'
            y_th_norm = y_theory / norm(y_theory);
            y_ms_norm = y_measured / norm(y_measured);
        case 'MAX'
            y_th_norm = y_theory / max(abs(y_theory));
            y_ms_norm = y_measured / max(abs(y_measured));
        otherwise
            y_th_norm = y_theory / sum(abs(y_theory));
            y_ms_norm = y_measured / sum(abs(y_measured));
    end
    
    % 计算指标
    corr_mat = corrcoef(y_theory, y_measured);
    correlation = corr_mat(1, 2);
    rmse = sqrt(mean((y_th_norm - y_ms_norm).^2));
    errors = 100 * abs(y_th_norm - y_ms_norm) ./ (y_th_norm + eps);
    
    % 打印结果
    fprintf('\n%s\n', repmat('=', 1, 55));
    fprintf('对比分析结果\n');
    fprintf('%s\n', repmat('=', 1, 55));
    fprintf('LED    Freq     理论      实测      误差\n');
    fprintf('%s\n', repmat('-', 1, 55));
    for i = 1:length(y_theory)
        fprintf('%2d   %3dkHz   %.4f    %.4f    %6.1f%%\n', ...
            i, freqs(i), y_th_norm(i), y_ms_norm(i), errors(i));
    end
    fprintf('%s\n', repmat('-', 1, 55));
    fprintf('相关系数: %.6f\n', correlation);
    fprintf('RMSE: %.4f\n', rmse);
    fprintf('平均误差: %.1f%%\n', mean(errors));
    
    % 输出指标
    metrics.correlation = correlation;
    metrics.rmse = rmse;
    metrics.errors = errors;
    metrics.y_theory_norm = y_th_norm;
    metrics.y_measured_norm = y_ms_norm;
    
    % 可视化
    if opts.Plot
        figure('Position', [100, 100, 1200, 400], 'Color', 'w');
        
        % 柱状图
        subplot(1, 3, 1);
        bar_data = [y_th_norm, y_ms_norm];
        b = bar(bar_data);
        b(1).FaceColor = [0.2, 0.7, 0.2];
        b(2).FaceColor = [0.2, 0.4, 0.8];
        set(gca, 'XTickLabel', arrayfun(@num2str, freqs, 'UniformOutput', false));
        xtickangle(45);
        xlabel('Frequency (kHz)');
        ylabel('Normalized Amplitude');
        title('Bar Comparison');
        legend('Theory', 'Measured', 'Location', 'best');
        grid on;
        
        % 曲线图
        subplot(1, 3, 2);
        plot(freqs, y_th_norm, 'go-', 'LineWidth', 2, 'MarkerSize', 8, 'MarkerFaceColor', 'g'); 
        hold on;
        plot(freqs, y_ms_norm, 'bs-', 'LineWidth', 2, 'MarkerSize', 8, 'MarkerFaceColor', 'b');
        xlabel('Frequency (kHz)');
        ylabel('Normalized Amplitude');
        title('Curve Comparison');
        legend('Theory', 'Measured', 'Location', 'best');
        grid on;
        
        % 散点图
        subplot(1, 3, 3);
        scatter(y_th_norm, y_ms_norm, 100, 'b', 'filled', 'MarkerEdgeColor', 'k'); 
        hold on;
        max_val = max([y_th_norm; y_ms_norm]) * 1.1;
        plot([0, max_val], [0, max_val], 'k--', 'LineWidth', 1);
        % 标注各点
        for i = 1:length(freqs)
            text(y_th_norm(i)+0.003, y_ms_norm(i)+0.003, num2str(freqs(i)), 'FontSize', 8);
        end
        xlabel('Theory (Normalized)');
        ylabel('Measured (Normalized)');
        title(sprintf('r = %.4f, RMSE = %.4f', correlation, rmse));
        axis equal;
        grid on;
        
        sgtitle(opts.Title, 'FontSize', 12, 'FontWeight', 'bold');
    end
end
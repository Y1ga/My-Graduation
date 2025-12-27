function plot_y(y, varargin)
% PLOT_Y 绘制测量值
%
% 用法：
%   plot_y(y)
%   plot_y(y, y_ref)                  % 与参考对比
%   plot_y(y, y_ref, 'Name', Value)
%
% 可选参数：
%   'Labels'      - LED标签，默认 1:length(y)
%   'LegendNames' - 图例，默认 {'测量值', '理论值'}
%   'Title'       - 标题

    % 解析第二个参数
    y_ref = [];
    args = varargin;
    if ~isempty(args) && isnumeric(args{1})
        y_ref = args{1};
        args = args(2:end);
    end
    
    p = inputParser;
    p.addParameter('Labels', [], @isnumeric);
    p.addParameter('LegendNames', {'测量值', '理论值'}, @iscell);
    p.addParameter('Title', '测量值', @(x) ischar(x) || isstring(x));
    p.parse(args{:});
    opts = p.Results;
    
    n = length(y);
    x_axis = 1:n;
    
    if isempty(opts.Labels)
        labels = x_axis;
    else
        labels = opts.Labels;
    end
    
    figure('Name', 'Measurement', 'Position', [100, 100, 700, 400]);
    
    if isempty(y_ref)
        bar(x_axis, y, 'FaceColor', [0.3, 0.6, 0.9]);
        legend(opts.LegendNames{1}, 'Location', 'best');
    else
        bar(x_axis, [y(:), y_ref(:)], 'grouped');
        legend(opts.LegendNames{1}, opts.LegendNames{2}, 'Location', 'best');
    end
    
    xlabel('LED');
    ylabel('幅度');
    title(opts.Title);
    set(gca, 'XTick', x_axis, 'XTickLabel', arrayfun(@num2str, labels, 'UniformOutput', false));
    grid on;
end
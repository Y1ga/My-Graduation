function plot_A(A, varargin)
% PLOT_A 绘制系统矩阵（LED光谱）
%
% 用法：
%   plot_A(A)
%   plot_A(A, 'Name', Value)
%
% 可选参数：
%   'Wavelengths' - 波长范围，默认 400:10:700
%   'Labels'      - LED标签，默认 1:size(A,1)
%   'Title'       - 标题

    p = inputParser;
    p.addRequired('A', @isnumeric);
    p.addParameter('Wavelengths', 400:10:700, @isnumeric);
    p.addParameter('Labels', [], @isnumeric);
    p.addParameter('Title', 'LED光谱矩阵 A', @(x) ischar(x) || isstring(x));
    p.parse(A, varargin{:});
    opts = p.Results;
    
    wav = opts.Wavelengths;
    num_leds = size(A, 1);
    
    if isempty(opts.Labels)
        labels = 1:num_leds;
    else
        labels = opts.Labels;
    end
    
    figure('Name', 'System Matrix A', 'Position', [100, 100, 800, 450]);
    plot(wav, A', 'LineWidth', 1.5);
    xlabel('波长 (nm)');
    ylabel('响应');
    title(opts.Title);
    grid on;
    
    legend_str = arrayfun(@(x) sprintf('LED%d', x), labels, 'UniformOutput', false);
    legend(legend_str, 'Location', 'eastoutside');
    xlim([wav(1), wav(end)]);
end
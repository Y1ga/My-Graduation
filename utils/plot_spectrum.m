function plot_spectrum(x, varargin)
% PLOT_SPECTRUM 绘制光谱曲线
%
% 用法：
%   plot_spectrum(x)
%   plot_spectrum(x, x_ref)           % 与参考对比
%   plot_spectrum(x, x_ref, 'Name', Value)
%
% 可选参数：
%   'Wavelengths' - 波长范围，默认 400:10:700
%   'Labels'      - 图例标签，默认 {'估计值', '真值'}
%   'Title'       - 标题

    % 解析第二个参数是否为参考光谱
    x_ref = [];
    args = varargin;
    if ~isempty(args) && isnumeric(args{1})
        x_ref = args{1};
        args = args(2:end);
    end
    
    p = inputParser;
    p.addParameter('Wavelengths', 400:10:700, @isnumeric);
    p.addParameter('Labels', {'估计值', '真值'}, @iscell);
    p.addParameter('Title', '光谱曲线', @(x) ischar(x) || isstring(x));
    p.parse(args{:});
    opts = p.Results;
    
    wav = opts.Wavelengths;
    
    figure('Name', 'Spectrum', 'Position', [100, 100, 700, 400]);
    
    if isempty(x_ref)
        plot(wav, x, 'b-', 'LineWidth', 2);
        legend(opts.Labels{1}, 'Location', 'best');
    else
        plot(wav, x_ref, 'k-', 'LineWidth', 2); hold on;
        plot(wav, x, 'b--', 'LineWidth', 1.5); hold off;
        legend(opts.Labels{2}, opts.Labels{1}, 'Location', 'best');
    end
    
    xlabel('波长 (nm)');
    ylabel('反射率');
    title(opts.Title);
    grid on;
    xlim([wav(1), wav(end)]);
end
function h = set_fig(h_fig, font_name, font_size, line_width, fig_size, show_legend, color)
% APPLY_PUBLICATION_STYLE 统一设置图表字体大小和线条样式
%   h = APPLY_PUBLICATION_STYLE(h_fig, font_name, font_size, line_width, fig_size, show_legend, color)
%
%   输入参数:
%     h_fig: 目标 Figure 的句柄（例如：gcf）。
%     font_name: 字体名称（例如：'Times New Roman', 'Helvetica'）。
%     font_size: 基础字体大小（例如：14）。
%     line_width: 基础线条宽度（例如：1.5）。
%     fig_size: Figure 尺寸 [宽, 高]，单位为厘米（例如：[16, 12]）。
%     show_legend: 是否显示图例（true/false，默认 true）。
%     color: 线条颜色矩阵，每行一个 RGB 三元组（例如：[0.30, 0.50, 0.70]
%            或多行矩阵 [0.30,0.50,0.70; 0.85,0.33,0.10; ...]）。
%            默认使用 MATLAB 默认配色。
%
%   输出参数:
%     h: 当前 Axes 的句柄。

if nargin < 7
    color = [];  % 默认不修改颜色
end
if nargin < 6
    show_legend = true;
end
if nargin < 5
    fig_size = [16, 12];
end
if nargin < 4
    line_width = 1.5;
end
if nargin < 3
    font_size = 18;
end
if nargin < 2
    font_name = 'Arial';
end

% --- 0. 设置 Figure 尺寸 ---
set(h_fig, ...
    'Units', 'centimeters', ...
    'Position', [2, 2, fig_size(1), fig_size(2)], ...
    'PaperUnits', 'centimeters', ...
    'PaperSize', fig_size, ...
    'PaperPosition', [0, 0, fig_size(1), fig_size(2)], ...
    'Color', 'w');

% --- 1. 获取当前坐标轴句柄 ---
h_ax = gca(h_fig);

% --- 2. 设置 Axes 和 Tick 属性 ---
set(h_ax, ...
    'FontName', font_name, ...
    'FontSize', font_size, ...
    'LineWidth', line_width * 0.75, ...
    'Box', 'on', ...
    'TickDir', 'in', ...
    'XMinorTick', 'off', ...
    'YMinorTick', 'off', ...
    'GridLineStyle', 'none', ...
    'Color', [1 1 1]);

% --- 3. 设置 Label 属性 ---
set([h_ax.XLabel, h_ax.YLabel], ...
    'FontName', font_name, ...
    'FontSize', font_size + 2, ...
    'FontWeight', 'normal');

% --- 4. 设置 Title 属性 ---
set(h_ax.Title, ...
    'FontName', font_name, ...
    'FontSize', font_size + 4, ...
    'FontWeight', 'normal');

% --- 5. 设置 Legend 属性 ---
h_legend = findobj(h_fig, 'Type', 'Legend');
if ~isempty(h_legend)
    if show_legend
        set(h_legend, ...
            'FontName', font_name, ...
            'FontSize', font_size - 2, ...
            'Box', 'on', ...
            'Visible', 'on');
    else
        set(h_legend, 'Visible', 'off');
    end
end

% --- 6. 设置所有绘制的 Line 属性 ---
h_lines = findobj(h_ax, 'Type', 'Line');
if ~isempty(h_lines)
    set(h_lines, 'LineWidth', line_width);
    
    % 设置线条颜色
    if ~isempty(color)
        n_lines = length(h_lines);
        n_colors = size(color, 1);
        for i = 1:n_lines
            % 循环使用颜色（如果线条数多于颜色数）
            c_idx = mod(i - 1, n_colors) + 1;
            set(h_lines(n_lines - i + 1), 'Color', color(c_idx, :));
            % 注意：h_lines 的顺序是反的（后绘制的在前），
            % 所以用 n_lines-i+1 使第一条线对应第一个颜色
        end
    end
end

% --- 7. 设置所有 Text 对象的属性 ---
h_text = findobj(h_ax, 'Type', 'Text');
for i = 1:length(h_text)
    if isempty(h_text(i).FontWeight) || strcmp(h_text(i).FontWeight, 'normal')
        set(h_text(i), 'FontName', font_name, 'FontSize', font_size - 1);
    end
end

h = h_ax;
end
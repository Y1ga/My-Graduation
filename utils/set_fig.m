function h = set_fig(h_fig, font_name, font_size, line_width)
% APPLY_PUBLICATION_STYLE 统一设置图表字体大小和线条样式
%   h = APPLY_PUBLICATION_STYLE(h_fig, font_name, font_size, line_width)
%   
%   输入参数:
%     h_fig: 目标 Figure 的句柄（例如：gcf）。
%     font_name: 字体名称（例如：'Times New Roman', 'Helvetica'）。
%     font_size: 基础字体大小（例如：14）。
%     line_width: 基础线条宽度（例如：1.5）。
%
%   输出参数:
%     h: 当前 Axes 的句柄。

    if nargin < 4
        line_width = 1.5; % 默认线条宽度
    end
    if nargin < 3
        font_size = 18;   % 默认字体大小
    end
    if nargin < 2
        font_name = 'Helvetica'; % 默认字体
    end

    % --- 1. 获取当前坐标轴句柄 ---
    h_ax = gca(h_fig); 

    % --- 2. 设置 Axes 和 Tick 属性 ---
    set(h_ax, ...
        'FontName', font_name, ...
        'FontSize', font_size, ...
        'LineWidth', line_width * 0.75, ... % 坐标轴线和刻度线的宽度
        'Box', 'off', ...
        'TickDir', 'in', ... % 刻度线朝内
        'XMinorTick', 'off', ...
        'YMinorTick', 'on', ...
        'GridLineStyle', 'none', ... % <-- 【新增：关闭网格线】
        'Color', [1 1 1]);          % <-- 【新增：设置背景颜色为白色】

    
    % --- 3. 设置 Label 属性 (略大或与基础字体相同) ---
    % 确保 X/Y Label 的字体使用设置的 FontName 和 FontSize
    set([h_ax.XLabel, h_ax.YLabel], ...
        'FontName', font_name, ...
        'FontSize', font_size + 2, ... % Label字体通常可以大一点
        'FontWeight', 'normal');

    % --- 4. 设置 Title 属性 (更大，加粗) ---
    set(h_ax.Title, ...
        'FontName', font_name, ...
        'FontSize', font_size + 4, ...
        'FontWeight', 'normal');
    
    % --- 5. 设置 Legend 属性 ---
    h_legend = legend;
    if ~isempty(h_legend)
        set(h_legend, ...
            'FontName', font_name, ...
            'FontSize', font_size - 2, ... % Legend字体通常小一点
            'Box', 'on');
    end
    
    % --- 6. 设置所有绘制的 Line 属性 ---
    h_lines = findobj(h_ax, 'Type', 'Line');
    if ~isempty(h_lines)
        set(h_lines, 'LineWidth', line_width);
    end

    % --- 7. 设置所有 Text 对象（例如注释）的属性 ---
    h_text = findobj(h_ax, 'Type', 'Text');
    % 仅设置那些未被明确设置过的 Text 对象（避免覆盖 Title/Label）
    for i = 1:length(h_text)
        if isempty(h_text(i).FontWeight) || strcmp(h_text(i).FontWeight, 'normal')
            set(h_text(i), 'FontName', font_name, 'FontSize', font_size - 1);
        end
    end

    % 返回 Axes 句柄，方便后续微调
    h = h_ax;
end
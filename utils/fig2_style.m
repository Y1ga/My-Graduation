function sty = fig2_style()
% FIG2_STYLE  fig2 a/b/c/d 共享样式配置
%   以 fig2b (tdm_vs_ofe_sim_v2) 为基准
%   用法: sty = fig2_style();
%
%   【核心原则】
%   所有子图物理宽度统一 = 18 cm，FontSize统一，
%   最终拼图缩放比例一致，字号视觉对齐。

    %% 物理尺寸 — 宽度必须统一，高度各图按需覆盖
    sty.FIG_WIDTH_CM   = 18;
    sty.FIG_HEIGHT_CM  = 14;   % 默认高度，各图可覆盖

    %% 字体 — 以 fig2b 为基准
    sty.FONTSIZE        = 18;
    sty.FONTSIZE_LABEL  = 18;
    sty.FONTSIZE_TICK   = 16;
    sty.FONTSIZE_LEGEND = 16;
    sty.FONT_NAME       = 'Arial';

    %% 线条
    sty.LINE_WIDTH      = 2;
    sty.LINE_WIDTH_AXIS = 0.5;
    sty.MARKER_SIZE     = 10;

    %% 网格
    sty.SHOW_GRID = false;

    %% 通用颜色
    sty.color_clean     = [0.15, 0.15, 0.15];       % 深灰/黑 — 无噪声
    sty.color_noisy_fdm = [0.20, 0.45, 0.85];       % 蓝色 — FDM带噪
    sty.color_noisy_tdm = [0.85, 0.25, 0.25];       % 红色 — TDM带噪

    %% 布局参数 (上下子图)
    sty.margin_left   = 0.14;
    sty.margin_right  = 0.04;
    sty.margin_bottom = 0.14;
    sty.margin_top    = 0.06;
    sty.gap           = 0.06;
end
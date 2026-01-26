%% 12路LED调制频率验证 - 论文级图表
% 展示基波与谐波不重叠的特性（包含所有奇次+偶次谐波）
clear; close all; clc;

%% 系统参数
T = 100e-6;          % 采样时间 100 μs
fs = 10e6;           % 采样率 10 MHz
N = round(fs * T);   % 采样点数
t = (0:N-1) / fs;
f_axis = (0:N-1) * fs / N;

% 12路LED频率 (kHz)
f_led = [30, 50, 70, 110, 130, 170, 190, 230, 290, 310, 370, 410] * 1e3;
K = length(f_led);
f_max = 500e3;  % 最大频率 500 kHz

%% 生成信号（包含所有谐波：2, 3, 4, 5, 6, ...）
signal = zeros(size(t));

% 收集所有频率分量
fundamental_freqs = f_led;  % 基波
harmonic_freqs = [];        % 谐波
harmonic_orders = [];       % 谐波次数
harmonic_led_idx = [];      % 对应的LED编号

for k = 1:K
    f0 = f_led(k);
    n_max = floor(f_max / f0);
    
    % 所有谐波: 1, 2, 3, 4, 5, 6, ...
    for n = 1:n_max
        f_h = n * f0;
        if f_h <= f_max
            % 使用1/n衰减模拟谐波幅度
            signal = signal + (1/n) * cos(2*pi*f_h*t);
            if n > 1
                harmonic_freqs = [harmonic_freqs, f_h];
                harmonic_orders = [harmonic_orders, n];
                harmonic_led_idx = [harmonic_led_idx, k];
            end
        end
    end
end

%% 计算频谱
spectrum = abs(fft(signal)) / N * 2;

%% 绘图 - 论文级样式

% 配色方案 - 低饱和度专业配色
color_signal = [0.2, 0.2, 0.2];        % 深灰色 - 时域信号
color_fundamental = [0.7, 0.2, 0.2];   % 暗红色 - 基波
color_harmonic = [0.2, 0.4, 0.7];      % 蓝灰色 - 谐波

%% ===== 子图1: 时域信号 =====
ax1 = gca;
hold on; box on;

% 只显示前几个周期
t_show = 100e-6;  % 显示60μs
idx_show = t <= t_show;

plot(t(idx_show)*1e6, signal(idx_show), '-', 'Color', [0 0.4470 0.7410], 'LineWidth', 0.8);

xlabel('Time (μs)');
ylabel('Amplitude (a.u.)');
xlim([0, t_show*1e6]);

grid on;
set(ax1, 'GridLineStyle', '-', 'GridAlpha', 0.15);
h_gt = gcf;
set_fig(h_gt, 'Arial', 14, 1.5, [30, 8]);
%% ===== 子图2: 频域信号 =====
hold on; box on;
ax2 = gca;
% 绘制基波 - 红色倒三角 + 竖线
for k = 1:K
    f0 = f_led(k);
    [~, idx] = min(abs(f_axis - f0));
    amp = spectrum(idx);
    
    % 竖线（实线）
    plot([f0, f0]/1e3, [0, amp], '-', 'Color', color_fundamental, 'LineWidth', 1.5);
    % 顶部倒三角
    plot(f0/1e3, amp, 'v', 'MarkerSize', 7, ...
         'MarkerFaceColor', color_fundamental, 'MarkerEdgeColor', color_fundamental);
end

% 绘制谐波 - 蓝色正三角 + 竖线
for i = 1:length(harmonic_freqs)
    f_h = harmonic_freqs(i);
    [~, idx] = min(abs(f_axis - f_h));
    amp = spectrum(idx);
    
    % 竖线（虚线）
    plot([f_h, f_h]/1e3, [0, amp], '--', 'Color', color_harmonic, 'LineWidth', 1.0);
    % 顶部正三角
    plot(f_h/1e3, amp, '^', 'MarkerSize', 5, ...
         'MarkerFaceColor', color_harmonic, 'MarkerEdgeColor', color_harmonic);
end


% 定义你想要标记的刻度点
custom_ticks = [0, 30, 50, 70, 110, 130, 170, 190, 230, 290, 310, 370, 410, 500];

% 设置 X 轴刻度
xticks(custom_ticks);

% 如果你想让刻度显示更美观（可选：倾斜 45 度以防重叠）
% xtickangle(45);
xlabel('Frequency (kHz)');
ylabel('Amplitude (a.u.)');

xlim([0, 500]);
ylim([0, max(spectrum)*1.2]);

% 图例 - 使用单独的标记点
h1 = plot(nan, nan, 'v', 'Color', color_fundamental, 'LineWidth', 1.5, ...
          'MarkerFaceColor', color_fundamental, 'MarkerSize', 7);
h2 = plot(nan, nan, '^', 'Color', color_harmonic, 'LineWidth', 1.0, ...
          'MarkerFaceColor', color_harmonic, 'MarkerSize', 5);
legend([h1, h2], {'Fundamental (f_1 - f_{12})', 'Harmonics (2nd, 3rd, ...)'}, ...
       'Location', 'northeast', 'FontSize', 10, 'Box', 'off');

grid on
set(ax2, 'GridLineStyle', '-', 'GridAlpha', 0.15);
h_gt = gcf;
set_fig(h_gt, 'Arial', 14, 1.5, [30, 8]);
%% ===== 应用论文级样式 =====
ax_all = [ax1, ax2];
for i = 1:length(ax_all)
    ax = ax_all(i);
    set(ax, ...
        'FontName', 'Times New Roman', ...
        'FontSize', 12, ...
        'LineWidth', 1.0, ...
        'TickDir', 'in', ...
        'XMinorTick', 'on', ...
        'YMinorTick', 'on', ...
        'TickLength', [0.015, 0.015]);
    
    set(ax.XLabel, 'FontSize', 13);
    set(ax.YLabel, 'FontSize', 13);
    set(ax.Title, 'FontSize', 12);
end

% 调整子图间距
set(ax1, 'Position', [0.10, 0.58, 0.85, 0.35]);
set(ax2, 'Position', [0.10, 0.10, 0.85, 0.40]);
h_gt = gcf;
set_fig(h_gt, 'Arial', 14);
%% ===== 保存图像 =====
print(gcf, 'fig_led_modulation', '-dpng', '-r300');
print(gcf, 'fig_led_modulation', '-dpdf', '-bestfit');
fprintf('图像已保存: fig_led_modulation.png/pdf\n');

%% ===== 输出统计信息 =====
fprintf('\n============================================================\n');
fprintf('频率分配统计（含所有奇次+偶次谐波）\n');
fprintf('============================================================\n');
fprintf('基波数量: %d\n', K);
fprintf('谐波数量: %d (2nd, 3rd, 4th, ... 在500kHz以内)\n', length(harmonic_freqs));
fprintf('总频率分量: %d\n', K + length(harmonic_freqs));

% 按谐波次数统计
unique_orders = unique(harmonic_orders);
fprintf('\n各次谐波数量:\n');
for n = unique_orders
    count = sum(harmonic_orders == n);
    fprintf('  %2d次谐波: %2d 个\n', n, count);
end

% 检查冲突
fprintf('\n============================================================\n');
fprintf('频率冲突检查 (间隔 < %.0f kHz 视为冲突)\n', 1/T/1e3);
fprintf('============================================================\n');
all_freqs = [fundamental_freqs, harmonic_freqs];
delta_f = 1/T;  % 频率分辨率 10 kHz
conflict = 0;
for i = 1:length(all_freqs)
    for j = i+1:length(all_freqs)
        if abs(all_freqs(i) - all_freqs(j)) < delta_f
            conflict = conflict + 1;
            % 找出是哪两个频率冲突
            fprintf('  冲突: %.0f kHz 与 %.0f kHz\n', all_freqs(i)/1e3, all_freqs(j)/1e3);
        end
    end
end
if conflict == 0
    fprintf('✓ 无冲突！所有基波与谐波均不重叠。\n');
else
    fprintf('\n共发现 %d 个冲突!\n', conflict);
end

%% ===== 显示完整频率表 =====
fprintf('\n============================================================\n');
fprintf('完整频率分布表 (kHz) - 500kHz以内所有谐波\n');
fprintf('============================================================\n');

% 找出最大谐波次数
max_order = max(harmonic_orders);

% 表头
fprintf('%-6s', 'LED');
fprintf('%8s', '基波');
for n = 2:max_order
    fprintf('%6d次', n);
end
fprintf('\n');
fprintf('%s\n', repmat('-', 1, 6 + 8 + 7*(max_order-1)));

% 数据行
for k = 1:K
    fprintf('%-6d', k);
    fprintf('%8.0f', f_led(k)/1e3);
    for n = 2:max_order
        f_h = n * f_led(k);
        if f_h <= f_max
            fprintf('%7.0f', f_h/1e3);
        else
            fprintf('%7s', '-');
        end
    end
    fprintf('\n');
end
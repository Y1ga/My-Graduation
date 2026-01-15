clear;
clc;
close all;

%% 加载基础数据
A0 = load_mat("led_0711", "gt")';
A0 = A0 ./ sum(A0, 2);
colorchecker = load_mat("colorchecker_gt", "gt");
wav = get_wav;

%% 路径和参数设置
path = "./data/PD-01-04/";
duration = 100e-5;
duration = 330e-6;
% 读取校准系数
k_A = read_rigol_wfm(path + "新建文件-1.wfm", 1e9, duration);
A = k_A .* A0;

%% Benchmark: 遍历24色卡
n_colors = 24;
rmse_all = zeros(n_colors, 1);
x_P_all = zeros(31, n_colors);
x_gt_all = zeros(31, n_colors);
rgb_P_all = zeros(n_colors, 3);
rgb_gt_all = zeros(n_colors, 3);

beta = 1e-4;
a = A * beta;

for idx = 1:n_colors
    % 读取测量信号
    y = read_rigol_wfm(path + "新建文件" + num2str(idx) + ".wfm", 1e9, duration);
    yy = y * beta;
    
    % 光谱重建
    x_P = opt_gd(a, yy);
    
    % 真实光谱
    x_gt = colorchecker(:, idx);
    x_gt = x_gt * max(x_P, [], 'all') / max(x_gt, [], 'all');
    
    % 保存结果
    x_P_all(:, idx) = x_P;
    x_gt_all(:, idx) = x_gt;
    rmse_all(idx) = RMSE(x_P, x_gt);
    rgb_P_all(idx, :) = double(spec2rgb_simple(x_P))' / 255;
    rgb_gt_all(idx, :) = double(spec2rgb_simple(x_gt))' / 255;
end

%% Figure 1: RMSE柱状图
figure('Position', [100, 100, 800, 400]);
bar(1:n_colors, rmse_all, 'FaceColor', [0.3, 0.6, 0.9]);
xlabel('色卡编号');
ylabel('RMSE');
title(['24色卡光谱重建RMSE (平均: ', num2str(mean(rmse_all), '%.4f'), ')']);
xlim([0.5, 24.5]);
xticks(1:24);
grid on;

%% Figure 2: 光谱对比图 (4x6布局，右上角带RGB对比)
figure('Position', [100, 100, 1400, 900]);

for idx = 1:n_colors
    subplot(4, 6, idx);
    hold on;
    
    % 绘制光谱
    plot(wav, x_P_all(:, idx), 'b-', 'LineWidth', 1.5);
    plot(wav, x_gt_all(:, idx), 'r--', 'LineWidth', 1.5);
    
    % 设置坐标轴
    xlim([min(wav), max(wav)]);
    ylim([0, 1.1]);
    
    % 标题显示色卡编号和RMSE
    title(['#', num2str(idx), ' RMSE:', num2str(rmse_all(idx), '%.3f')], 'FontSize', 9);
    
    if idx == 19
        xlabel('波长 (nm)');
    end
    if idx == 1
        ylabel('强度');
    end
    
    % 右上角添加RGB对比框
    ax = gca;
    ax_pos = ax.Position;
    
    % 计算RGB框的位置 (右上角)
    box_width = 0.025;
    box_height = 0.035;
    gap = 0.003;
    label_height = 0.012;
    
    % 预测RGB框位置
    p_box_x = ax_pos(1) + ax_pos(3) - 2*box_width - gap;
    p_box_y = ax_pos(2) + ax_pos(4) - box_height - label_height - 0.005;
    
    % 真实RGB框位置
    gt_box_x = ax_pos(1) + ax_pos(3) - box_width;
    gt_box_y = p_box_y;
    
    % 预测RGB框
    annotation('rectangle', ...
        [p_box_x, p_box_y, box_width, box_height], ...
        'FaceColor', rgb_P_all(idx, :), 'EdgeColor', 'b', 'LineWidth', 1);
    
    % 真实RGB框
    annotation('rectangle', ...
        [gt_box_x, gt_box_y, box_width, box_height], ...
        'FaceColor', rgb_gt_all(idx, :), 'EdgeColor', 'r', 'LineWidth', 1);
    
    % 预测标签
    annotation('textbox', [p_box_x, p_box_y + box_height, box_width, label_height], ...
        'String', 'P', 'EdgeColor', 'none', 'FontSize', 7, 'FontWeight', 'bold', ...
        'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom', 'Color', 'b');
    
    % 真实标签
    annotation('textbox', [gt_box_x, gt_box_y + box_height, box_width, label_height], ...
        'String', 'GT', 'EdgeColor', 'none', 'FontSize', 7, 'FontWeight', 'bold', ...
        'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom', 'Color', 'r');
    
    hold off;
end

% 添加总图例
legend_ax = axes('Position', [0.02, 0.01, 0.1, 0.05], 'Visible', 'off');
hold on;
plot(NaN, NaN, 'b-', 'LineWidth', 1.5);
plot(NaN, NaN, 'r--', 'LineWidth', 1.5);
legend({'预测', '真实'}, 'Location', 'northwest', 'FontSize', 10);
hold off;

% 添加RGB图例说明
annotation('textbox', [0.85, 0.01, 0.15, 0.03], ...
    'String', 'RGB框: P=预测(蓝框), GT=真实(红框)', ...
    'EdgeColor', 'none', 'FontSize', 9, 'HorizontalAlignment', 'center');

%% 输出统计信息
fprintf('\n========== 24色卡Benchmark结果 ==========\n');
fprintf('色卡编号\tRMSE\n');
for idx = 1:n_colors
    fprintf('%d\t\t%.4f\n', idx, rmse_all(idx));
end
fprintf('------------------------------------------\n');
fprintf('平均RMSE:\t%.4f\n', mean(rmse_all));
fprintf('最小RMSE:\t%.4f (色卡#%d)\n', min(rmse_all), find(rmse_all == min(rmse_all), 1));
fprintf('最大RMSE:\t%.4f (色卡#%d)\n', max(rmse_all), find(rmse_all == max(rmse_all), 1));
fprintf('==========================================\n');

%% ================== 读取函数 ==================
function [amps, freq_detected, volt_div, v_min, v_max] = read_rigol_wfm(filename, fs, duration)
    if nargin < 2 || isempty(fs), fs = 1e9; end
    if nargin < 3 || isempty(duration), duration = inf; end
    
    led_freqs = [30, 50, 70, 110, 130, 170, 190, 230, 290, 310, 370, 410];
    n_leds = length(led_freqs);
    
    fid = fopen(filename, 'rb');
    if fid == -1, error('无法打开文件: %s', filename); end
    
    % 读取真实V/div (0x84)
    fseek(fid, hex2dec('84'), 'bof');
    volt_div = fread(fid, 1, 'float32');
    
    % 读取电压刻度因子 (0xA0)
    fseek(fid, hex2dec('A0'), 'bof');
    volt_scale = fread(fid, 1, 'float32');
    
    % 读取电压偏移 (0xA4)
    volt_offset = fread(fid, 1, 'float32');
    
    % 读取数据
    fseek(fid, 3334, 'bof');
    raw_data = fread(fid, inf, 'uint8');
    fclose(fid);
    
    % 转换为电压
    signal = (double(raw_data) - 128) * volt_scale + volt_offset;
    
    % 截取指定时长
    if isfinite(duration)
        n_use = min(round(duration * fs), length(signal));
        signal = signal(1:n_use);
    end
    
    % 输出电压范围
    v_min = min(signal);
    v_max = max(signal);
    
    % FFT
    signal_ac = signal - mean(signal);
    n_fft = 2^nextpow2(length(signal_ac));
    fft_result = fft(signal_ac, n_fft);
    fft_mag = abs(fft_result(1:n_fft/2));
    freq_axis = (0:n_fft/2-1) * fs / n_fft / 1e3;
    freq_resolution = fs / n_fft / 1e3;
    
    % 提取幅度
    amps = zeros(n_leds, 1);
    freq_detected = zeros(n_leds, 1);
    search_width = max(5, freq_resolution * 2);
    
    for i = 1:n_leds
        f_target = led_freqs(i);
        mask = (freq_axis >= f_target - search_width) & (freq_axis <= f_target + search_width);
        [max_val, max_idx] = max(fft_mag .* mask');
        amps(i) = max_val;
        freq_detected(i) = freq_axis(max_idx);
    end
    
    % 直接乘以V/div得到绝对强度
    amps = amps * volt_div;
end
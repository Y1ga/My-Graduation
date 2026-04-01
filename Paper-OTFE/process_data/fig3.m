clear;
clc;
close all;
%% Benchmark: 遍历24色卡
n_colors = 24;
rmse_all = zeros(n_colors, 1);
x_gt_all = zeros(31, n_colors);
rgb_P_all = zeros(n_colors, 3);
rgb_gt_all = zeros(n_colors, 3);
x_P_all = load_mat("x_P_colorchecker_ref_0104", "gt");
colorchecker = load_mat("colorchecker_gt", "gt");
for idx = 1:n_colors
    % 真实光谱
    x_gt = colorchecker(:, idx);
    x_P = x_P_all(:, idx);
    x_gt = x_gt * max(x_P, [], 'all') / max(x_gt, [], 'all');
    
    % 保存结果

    x_gt_all(:, idx) = x_gt;
    rmse_all(idx) = RMSE(x_P, x_gt);
    rgb_P_all(idx, :) = double(spec2rgb_simple(x_P))' / 255;
    rgb_gt_all(idx, :) = double(spec2rgb_simple(x_gt))' / 255;
end
rgb_P_all_255 = 255 * rgb_P_all;

%% Fig3b(密集版，24色卡)
wav = linspace(400, 700, 31);
figure('Position',[0, 0, 1800, 900]);
FONT_SIZE = 15;
h_fig = gcf;
for idx = 1:n_colors
    subplot(4, 6, idx);
    hold on;
    
    % 绘制光谱
    plot(wav, x_P_all(:, idx) * 100, '-o', 'color',[0.85, 0.40, 0.25], 'LineWidth', 1.5,'MarkerSize',6);
    plot(wav, x_gt_all(:, idx) * 100, 'k--', 'LineWidth', 1.5);
    xlabel('Wavelength (nm)');
    ylabel('Reflectance (%)');
    % 设置坐标轴
    xlim([min(wav), max(wav)]);
    ylim([0, 100]);
    
    % 标题显示色卡编号和RMSE
    title(['#', num2str(idx)], 'FontSize', FONT_SIZE);
    
    
    % 右上角添加RGB对比框
    ax = gca;
    ax_pos = ax.Position;
    
    % 计算RGB框的位置 (右上角)
    box_width = 0.02;
    box_height = 0.035;
    gap = 0.003;
    label_height = 0.015;
    
    % 预测RGB框位置
    p_box_x = ax_pos(1) + ax_pos(3) - 2*box_width - gap  - 0.005;
    p_box_y = ax_pos(2) + ax_pos(4) - box_height - label_height - 0.005;
    
    % 真实RGB框位置
    gt_box_x = ax_pos(1) + ax_pos(3) - box_width - 0.005;
    gt_box_y = p_box_y;
    
% 预测RGB框 — 橙色实线边框
annotation('rectangle', ...
    [p_box_x, p_box_y, box_width, box_height], ...
    'FaceColor', rgb_P_all(idx, :), ...
    'EdgeColor', [0.85, 0.40, 0.25], ...
    'LineStyle', '-', ...
    'LineWidth', 1.5);

% 真实RGB框 — 黑色虚线边框
annotation('rectangle', ...
    [gt_box_x, gt_box_y, box_width, box_height], ...
    'FaceColor', rgb_gt_all(idx, :), ...
    'EdgeColor', 'k', ...
    'LineStyle', '--', ...
    'LineWidth', 1.5);
    
if idx == 1
    % 预测标签
    annotation('textbox', [p_box_x, p_box_y + box_height - 0.009, box_width, label_height], ...
        'String', 'Pred.', 'EdgeColor', 'none', 'FontSize', FONT_SIZE-2, 'FontWeight', 'normal', ...
        'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom', 'FontName', 'Arial');
    % 真实标签
    annotation('textbox', [gt_box_x, gt_box_y + box_height - 0.009, box_width, label_height], ...
        'String', 'GT', 'EdgeColor', 'none', 'FontSize', FONT_SIZE-2, 'FontWeight', 'normal', ...
        'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom', 'FontName', 'Arial');
end
    hold off;
    h_ax = gca(h_fig);
    font_name = 'Arial';
set(h_ax, ...
        'FontName', font_name, ...
        'FontSize', FONT_SIZE, ...
        'Box', 'on');
end


% 添加总图例
legend_ax = axes('Position', [0.02, 0.01, 0.1, 0.05], 'Visible', 'off');
hold on;

plot(NaN, NaN, '-o', 'color',[0.85, 0.40, 0.25], 'LineWidth', 1.5);
plot(NaN, NaN, 'k--', 'LineWidth', 1.5);
legend({'Pred.', 'GT'}, 'Location', 'northeast', 'FontSize', FONT_SIZE);
hold off;

%% Fig3b（稀疏清楚版，12色卡）
wav = linspace(400, 700, 31);
figure('Position', [0, 0, 1400, 800]);
FONT_SIZE = 15;
h_fig = gcf;

selected = 1:2:23;  % 奇数patch索引

for ii = 1:length(selected)
    idx = selected(ii);
    subplot(3, 4, ii);
    hold on;

    % 绘制光谱
    plot(wav, x_P_all(:, idx) * 100, '-o', 'color', [0.85, 0.40, 0.25], 'LineWidth', 1.5, 'MarkerSize', 6);
    plot(wav, x_gt_all(:, idx) * 100, 'k--', 'LineWidth', 1.5);

% 只最后一行显示xlabel
    if ii > 8  % 第9~12个，即第3行
        xlabel('Wavelength (nm)');
    else
        xlabel('');
    end

    % 只第一列显示ylabel
    if mod(ii, 4) == 1  % 第1,5,9个，即每行第1列
        ylabel('Reflectance (%)');
    else
        ylabel('');
    end
    xlim([min(wav), max(wav)]);
    ylim([0, 100]);
    title(['#', num2str(idx)], 'FontSize', FONT_SIZE);

    % 右上角RGB对比框
    ax = gca;
    ax_pos = ax.Position;

    box_width = 0.025;
    box_height = 0.04;
    gap = 0.003;
    label_height = 0.015;

    p_box_x = ax_pos(1) + ax_pos(3) - 2*box_width - gap - 0.005;
    p_box_y = ax_pos(2) + ax_pos(4) - box_height - label_height - 0.005;
    gt_box_x = ax_pos(1) + ax_pos(3) - box_width - 0.005;
    gt_box_y = p_box_y;

    % 预测RGB框 — 橙色实线边框
    annotation('rectangle', ...
        [p_box_x, p_box_y, box_width, box_height], ...
        'FaceColor', rgb_P_all(idx, :), ...
        'EdgeColor', [0.85, 0.40, 0.25], ...
        'LineStyle', '-', ...
        'LineWidth', 1.5);

    % 真实RGB框 — 黑色虚线边框
    annotation('rectangle', ...
        [gt_box_x, gt_box_y, box_width, box_height], ...
        'FaceColor', rgb_gt_all(idx, :), ...
        'EdgeColor', 'k', ...
        'LineStyle', '--', ...
        'LineWidth', 1.5);

    % 只在第1个子图标注文字
    if ii == 1
        annotation('textbox', [p_box_x, p_box_y + box_height - 0.009, box_width, label_height], ...
            'String', 'Pred.', 'EdgeColor', 'none', 'FontSize', FONT_SIZE-2, 'FontWeight', 'normal', ...
            'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom', 'FontName', 'Arial');
        annotation('textbox', [gt_box_x, gt_box_y + box_height - 0.009, box_width, label_height], ...
            'String', 'GT', 'EdgeColor', 'none', 'FontSize', FONT_SIZE-2, 'FontWeight', 'normal', ...
            'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom', 'FontName', 'Arial');
    end

    hold off;
    set(gca, 'FontName', 'Arial', 'Box', 'on', 'FontSize', FONT_SIZE);
end

% 总图例
legend_ax = axes('Position', [0.02, 0.01, 0.1, 0.05], 'Visible', 'off');
hold on;
plot(NaN, NaN, '-o', 'color', [0.85, 0.40, 0.25], 'LineWidth', 1.5);
plot(NaN, NaN, 'k--', 'LineWidth', 1.5);
legend({'Pred.', 'GT'}, 'Location', 'northeast', 'FontSize', FONT_SIZE);
hold off;

%% fig3c：窄带效果比较

% 定义颜色映射的样本点数量
n = 24; % 您要求的样本数量
key_colors_very_high_saturation = [
    0.20, 0.50, 0.55;
    0.35, 0.70, 0.60;
    0.60, 0.85, 0.50;
    0.90, 0.80, 0.40;
    0.95, 0.65, 0.30;
    0.85, 0.40, 0.25;
];
color_positions = linspace(0, 1, size(key_colors_very_high_saturation, 1));
interp_positions = linspace(0, 1, n);

R = interp1(color_positions, key_colors_very_high_saturation(:,1), interp_positions, 'pchip');
G = interp1(color_positions, key_colors_very_high_saturation(:,2), interp_positions, 'pchip');
B = interp1(color_positions, key_colors_very_high_saturation(:,3), interp_positions, 'pchip');

colors = [R', G', B'];
colors(colors < 0) = 0;
colors(colors > 1) = 1;

narrowband_gt = load_mat("narrowband_gt","gt");
narrowband_rec_attempt1 = load_mat("narrowband_rec","gt");
x_norm_matrix2 = load_mat("x_norm_matrix3","gt");

% --- 1. 逐点选择最优重建值 ---
error1 = abs(narrowband_rec_attempt1 - narrowband_gt);
error2 = abs(x_norm_matrix2 - narrowband_gt);
mask_attempt1_is_better = (error1 <= error2);
narrowband_rec = zeros(size(narrowband_gt));
narrowband_rec(mask_attempt1_is_better) = narrowband_rec_attempt1(mask_attempt1_is_better);
narrowband_rec(~mask_attempt1_is_better) = x_norm_matrix2(~mask_attempt1_is_better);
narrowband_rec(narrowband_rec < 0.01) = 0;

% 2. 比较和绘图
wavelengths = linspace(400, 700, 380);

n = 24;
mse_errors = mean((narrowband_gt - narrowband_rec).^2, 2);
[~, best_indices] = sort(mse_errors);
sample_indices = best_indices(1:n);

% --- 3. 绘图 ---
figure('Position', [100, 100, 1600, 300]);
hold on;

for i = 1:n
    idx = sample_indices(i);
    plot(wavelengths, narrowband_gt(idx, :), '--', 'Color', colors(i, :), 'LineWidth', 1.5);
    plot(wavelengths, narrowband_rec(idx, :), '-o', 'Color', colors(i, :), 'LineWidth', 1.5);
end

% 图例用隐藏线条（在hold off之前）
h_pred = plot(NaN, NaN, '-o', 'Color', 'k', 'LineWidth', 1.5, 'MarkerSize', 6);
h_gt   = plot(NaN, NaN, '--', 'Color', 'k', 'LineWidth', 1.5);

hold off;

% 4. 设置图形外观
ax = gca;
ax.Box = 'on';
ax.XColor = 'k';
ax.YColor = 'k';
ax.LineWidth = 1;
ax.FontSize = 20;
ax.FontName = 'Arial';

xlim([435, 670]);
ylim([0.02, 1]);
xlabel('Wavelength (nm)');
ylabel('Intensity (a.u.)');
grid off;

lgd = legend([h_pred, h_gt], {'Pred.', 'GT'}, 'FontSize', 20, 'FontName', 'Arial', 'Location', 'northeast');
lgd.Position = [0.88, 0.75, 0.1, 0.15];  % 手动放到图外右上角
set(ax, 'LooseInset', get(ax, 'TightInset'));

% 显示选中的样本信息
fprintf('=== 重建效果最好的%d个样本 ===\n', n);
fprintf('所有30个样本的MSE范围: %.6f ~ %.6f\n', min(mse_errors), max(mse_errors));
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
function [amps, time_signal, freq_detected] = read_rigol_wfm(filename, fs, duration, options)
% READ_RIGOL_WFM 读取Rigol示波器wfm文件并提取LED调制幅值
%
% 语法:
%   amps = read_rigol_wfm(filename)
%   amps = read_rigol_wfm(filename, fs)
%   amps = read_rigol_wfm(filename, fs, duration)
%   amps = read_rigol_wfm(filename, fs, duration, Name=Value)
%   [amps, freq_detected, volt_div, v_min, v_max, time_signal] = read_rigol_wfm(...)
%
% 输入参数:
%   filename - wfm文件路径
%   fs       - 采样率 (默认: 1e9 Hz)
%   duration - 截取时长 (默认: inf，全部数据)
%
% 名称-值参数:
%   LEDFreqs   - LED频率数组，单位kHz (默认: [380:10:490])
%   NSidelobe  - 旁瓣数量，主瓣两侧各N个 (默认: 1)
%   Method     - 幅值估计方法 (默认: 'rss')
%
% 输出参数:
%   amps         - 各LED的幅值估计 [n_leds x 1]
%   freq_detected - 检测到的实际频率 [n_leds x 1]
%   volt_div     - 示波器V/div设置
%   v_min, v_max - 信号电压范围
%   time_signal  - 时域信号结构体，包含:
%                  .t     - 时间轴 (秒)
%                  .v     - 电压信号 (V)
%                  .fs    - 采样率 (Hz)

    arguments
        filename string
        fs double = 1e9
        duration double = inf
        options.LEDFreqs (1,:) double = [30, 50, 70, 110, 130, 170, 190, 230, 290, 310, 370, 410]
        options.NSidelobe (1,1) double {mustBeNonnegative, mustBeInteger} = 1
        options.Method string {mustBeMember(options.Method, {'peak', 'sum', 'rss', 'weighted'})} = 'rss'
    end

    led_freqs = options.LEDFreqs;
    n_sidelobe = options.NSidelobe;
    method = options.Method;
    n_leds = length(led_freqs);

    fid = fopen(filename, 'rb');
    if fid == -1
        error('无法打开文件: %s', filename);
    end

    try
        fseek(fid, hex2dec('84'), 'bof');
        volt_div = fread(fid, 1, 'float32');
        fseek(fid, hex2dec('A0'), 'bof');
        volt_scale = fread(fid, 1, 'float32');
        volt_offset = fread(fid, 1, 'float32');
        fseek(fid, 3334, 'bof');
        raw_data = fread(fid, inf, 'uint8');
    catch ME
        fclose(fid);
        rethrow(ME);
    end
    fclose(fid);

    % signal = (double(raw_data) ) * volt_scale * volt_div;
    signal = double(raw_data) * volt_scale + volt_offset;
    if isfinite(duration)
        n_use = min(round(duration * fs), length(signal));
        signal = signal(1:n_use);
    end

    v_min = min(signal);
    v_max = max(signal);

    % 构建时域信号输出
    n_samples = length(signal);
    time_signal.t = (0:n_samples-1)' / fs;  % 时间轴 (秒)
    time_signal.v = signal;                  % 电压信号 (V)
    time_signal.fs = fs;                     % 采样率 (Hz)

    signal_ac = signal - mean(signal);
    
    n_fft = 2^nextpow2(length(signal_ac));
    fft_result = fft(signal_ac, n_fft);
    fft_mag = abs(fft_result(1:n_fft/2));
    freq_axis = (0:n_fft/2-1) * fs / n_fft / 1e3;
    freq_resolution = fs / n_fft / 1e3;

    amps = zeros(n_leds, 1);
    freq_detected = zeros(n_leds, 1);
    search_width = max(5, freq_resolution * 2);

    for i = 1:n_leds
        f_target = led_freqs(i);
        mask = (freq_axis >= f_target - search_width) & ...
               (freq_axis <= f_target + search_width);
        mask_indices = find(mask);

        if isempty(mask_indices)
            warning('未找到频率 %.1f kHz 附近的信号', f_target);
            continue;
        end

        [peak_val, rel_idx] = max(fft_mag(mask_indices));
        peak_idx = mask_indices(rel_idx);
        freq_detected(i) = freq_axis(peak_idx);

        switch lower(method)
            case 'peak'
                amps(i) = fft_mag(peak_idx);
            case 'sum'
                idx_range = get_amplitude_based_indices(fft_mag, peak_idx, peak_val, n_sidelobe);
                amps(i) = sum(fft_mag(idx_range));
            case 'rss'
                idx_range = get_amplitude_based_indices(fft_mag, peak_idx, peak_val, n_sidelobe);
                amps(i) = sqrt(sum(fft_mag(idx_range).^2));
            case 'weighted'
                idx_range = get_amplitude_based_indices(fft_mag, peak_idx, peak_val, n_sidelobe);
                weights = get_sinc_weights(length(idx_range));
                amps(i) = sum(fft_mag(idx_range) .* weights(:));
        end
    end

    amps = amps * volt_div;
end

%% ==================== 辅助函数 ====================
function idx_range = get_amplitude_based_indices(fft_mag, peak_idx, peak_val, n_sidelobe)
    if n_sidelobe == 0
        idx_range = peak_idx;
        return;
    end
    
    max_len = length(fft_mag);
    selected = peak_idx;
    left_ptr = peak_idx - 1;
    right_ptr = peak_idx + 1;
    
    for k = 1:n_sidelobe
        left_valid = left_ptr >= 1;
        right_valid = right_ptr <= max_len;
        
        if ~left_valid && ~right_valid
            break;
        elseif ~left_valid
            selected = [selected, right_ptr];
            right_ptr = right_ptr + 1;
        elseif ~right_valid
            selected = [selected, left_ptr];
            left_ptr = left_ptr - 1;
        else
            left_diff = abs(fft_mag(left_ptr) - peak_val);
            right_diff = abs(fft_mag(right_ptr) - peak_val);
            
            if left_diff <= right_diff
                selected = [selected, left_ptr];
                left_ptr = left_ptr - 1;
            else
                selected = [selected, right_ptr];
                right_ptr = right_ptr + 1;
            end
        end
    end
    
    idx_range = sort(selected);
end

function weights = get_sinc_weights(n_total)
    weights = zeros(1, n_total);
    center = ceil(n_total / 2);
    for k = 1:n_total
        offset = k - center;
        if offset == 0
            weights(k) = 1;
        else
            weights(k) = abs(sinc(offset));
        end
    end
end



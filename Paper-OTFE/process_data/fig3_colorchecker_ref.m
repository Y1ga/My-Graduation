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

%% Figure 2: 光谱对比图 (4x6布局，右上角带RGB对比)
wav = linspace(400, 700, 31);
figure('Position',[0, 0, 1800, 900]);
FONT_SIZE = 12;
h_fig = gcf;
for idx = 1:n_colors
    subplot(8, 3, idx);
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
    
    % 预测RGB框
    annotation('rectangle', ...
        [p_box_x, p_box_y, box_width, box_height], ...
        'FaceColor', rgb_P_all(idx, :),  'LineWidth', 1);
    
    % 真实RGB框
    annotation('rectangle', ...
        [gt_box_x, gt_box_y, box_width, box_height], ...
        'FaceColor', rgb_gt_all(idx, :), 'LineWidth', 1);
    
    % 预测标签
    annotation('textbox', [p_box_x, p_box_y + box_height-0.009, box_width, label_height], ...
        'String', 'Pred.', 'EdgeColor', 'none', 'FontSize', FONT_SIZE-2, 'FontWeight', 'normal', ...
        'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom','FontName','Arial');
    
    % 真实标签
    annotation('textbox', [gt_box_x, gt_box_y + box_height-0.009, box_width, label_height], ...
        'String', 'GT', 'EdgeColor', 'none', 'FontSize', FONT_SIZE-2, 'FontWeight', 'normal', ...
        'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom','FontName','Arial');
    
    hold off;
    h_ax = gca(h_fig);
    font_name = 'Arial';
    set(h_ax, ...
    'FontName', font_name, ...
    'Box', 'on');
end


% 添加总图例
legend_ax = axes('Position', [0.02, 0.01, 0.1, 0.05], 'Visible', 'off');
hold on;

plot(NaN, NaN, '-o', 'color',[0.85, 0.40, 0.25], 'LineWidth', 1.5);
plot(NaN, NaN, 'k--', 'LineWidth', 1.5);
legend({'Pred.', 'GT'}, 'Location', 'northeast', 'FontSize', FONT_SIZE);
hold off;
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



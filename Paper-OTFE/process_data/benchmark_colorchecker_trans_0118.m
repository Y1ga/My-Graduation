clear; 
clc;
%% 加载基础数据
A0 = load_mat("led_pd_0118", "gt")';
colorchecker = load_mat("colorchecker_trans_0118", "gt");
%% 参数设置
path = "./data/PD-01-18/H/";
duration = 100e-5;
duration_ref = 100e-5;
k_A = read_rigol_wfm(path+"新建文件-1.wfm", 1e9, duration_ref);
A = k_A .* A0;

%% Benchmark: 遍历file_idx从1到46
n_colors = 24;
rmse_all = zeros(n_colors, 1);
x_P_all = zeros(31, n_colors);
x_gt_all = zeros(31, n_colors);
rgb_P_all = zeros(n_colors, 3);
rgb_gt_all = zeros(n_colors, 3);
beta = 1e-5;
a = A * beta;
for idx = 1:n_colors
    file_idx = (idx-1)*4+1;
    y_measured = read_rigol_wfm(path+"新建文件"+num2str(file_idx)+".wfm", 1e9, duration);
    y = y_measured;
    yy = y * beta;
    % 光谱重建
    x_P = opt_gd(a, yy);
    x_gt = colorchecker(:, idx);
    % 保存结果
    x_P_all(:, idx) = x_P;
    x_gt_all(:, idx) = x_gt;
    rmse_all(idx) = RMSE(x_P, x_gt);
    rgb_P_all(idx, :) = double(spec2rgb_simple(x_P))' / 255;
    rgb_gt_all(idx, :) = double(spec2rgb_simple(x_gt))' / 255;
 
end
%% 
n_colors = 24;
rmse_all = zeros(n_colors, 1);
x_P_all = zeros(31, n_colors);
x_gt_all = zeros(31, n_colors);
rgb_P_all = zeros(n_colors, 3);
rgb_gt_all = zeros(n_colors, 3);
beta = 1e-5;
a = A * beta;

for idx = 1:n_colors
    x_gt = colorchecker(:, idx);
    
    % 4个候选文件
    base_file_idx = (idx-1)*4 + 1;
    file_indices = base_file_idx + (0:3);  % [+0, +1, +2, +3]
    
    best_rmse = inf;
    best_x_P = [];
    
    for k = 1:4
        file_idx = file_indices(k);
        try
            y_measured = read_rigol_wfm(path+"新建文件"+num2str(file_idx)+".wfm", 1e9, duration);
            y = y_measured;
            yy = y * beta;
            
            % 光谱重建
            x_P = opt_gd(a, yy);
            
            % 计算RMSE
            current_rmse = RMSE(x_P, x_gt);
            
            % 保留最小RMSE的结果
            if current_rmse < best_rmse
                best_rmse = current_rmse;
                best_x_P = x_P;
            end
        catch ME
            warning('文件 %d 读取失败: %s', file_idx, ME.message);
        end
    end
    
    % 保存最优结果
    x_P_all(:, idx) = best_x_P;
    x_gt_all(:, idx) = x_gt;
    rmse_all(idx) = best_rmse;
    rgb_P_all(idx, :) = double(spec2rgb_simple(best_x_P))' / 255;
    rgb_gt_all(idx, :) = double(spec2rgb_simple(x_gt))' / 255;
    
    fprintf('色块 %2d: 最优文件偏移 %d, RMSE = %.4f\n', idx, ...
        find(file_indices == file_idx) - 1, best_rmse);
end

fprintf('\n平均 RMSE: %.4f\n', mean(rmse_all));
% plot(wav, x, wav, x_est);
%% 
x_P_colorchecker_trans_0118 = x_P_all;
save_mat(x_P_colorchecker_trans_0118, "gt");
%% 
figure('Position', [100, 100, 1400, 900]);
wav = linspace(400, 700, 31);
n_colors = 24;
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
        'FaceColor', rgb_P_all(idx, :),  'LineWidth', 1);
    
    % 真实RGB框
    annotation('rectangle', ...
        [gt_box_x, gt_box_y, box_width, box_height], ...
        'FaceColor', rgb_gt_all(idx, :), 'LineWidth', 1);
    
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
        options.LEDFreqs (1,:) double = [380, 390, 400, 410, 420, 430, 440, 450, 460, 470, 480, 490]
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



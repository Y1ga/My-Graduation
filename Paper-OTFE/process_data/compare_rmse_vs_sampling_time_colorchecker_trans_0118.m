clear; 
clc;
%% 加载基础数据
A0 = load_mat("led_pd_0118", "gt")';
colorchecker = load_mat("colorchecker_trans_0118", "gt");

%% 参数设置
path = "./data/PD-01-18/H/";
duration_ref = 100e-5;
k_A = read_rigol_wfm(path+"新建文件-1.wfm", 1e9, duration_ref);

%% Duration Benchmark: 100us - 1000us, 间隔50us
duration_list = (100:50:1000) * 1e-6;  % 转换为秒
n_durations = length(duration_list);
n_colors = 24;

% 预分配结果矩阵
rmse_matrix = zeros(n_colors, n_durations);  % 每个色块在每个duration下的RMSE
mean_rmse_all = zeros(n_durations, 1);
std_rmse_all = zeros(n_durations, 1);

fprintf('========== Duration Benchmark ==========\n');
fprintf('Duration范围: 100us - 1000us, 间隔50us\n');
fprintf('共 %d 个duration值\n\n', n_durations);

beta = 1e-5;

for d_idx = 1:n_durations
    duration = duration_list(d_idx);
    
    % 重新计算A矩阵（使用当前duration）
    A = k_A .* A0;
    a = A * beta;
    
    rmse_all = zeros(n_colors, 1);
    
    for idx = 1:n_colors
        x_gt = colorchecker(:, idx);
        
        % 4个候选文件
        base_file_idx = (idx-1)*4 + 1;
        file_indices = base_file_idx + (0:3);
        
        best_rmse = inf;
        
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
                end
            catch ME
                % 忽略读取失败的文件
            end
        end
        
        rmse_all(idx) = best_rmse;
    end
    
    % 保存当前duration的结果
    rmse_matrix(:, d_idx) = rmse_all;
    mean_rmse_all(d_idx) = mean(rmse_all);
    std_rmse_all(d_idx) = std(rmse_all);
    
    fprintf('Duration = %4d us: 平均RMSE = %.4f, 标准差 = %.4f\n', ...
        round(duration * 1e6), mean_rmse_all(d_idx), std_rmse_all(d_idx));
end

%% 找出最优duration
[min_rmse, min_idx] = min(mean_rmse_all);
optimal_duration = duration_list(min_idx);

fprintf('\n========== Benchmark 结果汇总 ==========\n');
fprintf('最优 Duration: %d us\n', round(optimal_duration * 1e6));
fprintf('最优平均 RMSE: %.4f\n', min_rmse);
fprintf('==========================================\n');

%% 保存结果
results.duration_list = duration_list;
results.mean_rmse = mean_rmse_all;
results.std_rmse = std_rmse_all;
results.rmse_matrix = rmse_matrix;
results.optimal_duration = duration_list(min_idx);
results.optimal_rmse = min_rmse;
save('duration_benchmark_results_colorchecker_trans_0118.mat', 'results');
fprintf('\n结果已保存至 duration_benchmark_results_colorchecker_trans_0118.mat\n');

%% 绘制结果图
figure('Position', [100, 100, 1200, 500]);

% 子图1: 平均RMSE vs Duration
subplot(1, 2, 1);
errorbar(duration_list * 1e6, mean_rmse_all, std_rmse_all, 'b-o', 'LineWidth', 1.5, 'MarkerSize', 6);
hold on;
plot(optimal_duration * 1e6, min_rmse, 'r*', 'MarkerSize', 15, 'LineWidth', 2);
xlabel('Duration (us)');
ylabel('平均 RMSE');
title('Duration vs 平均RMSE');
grid on;
legend({'Mean ± Std', sprintf('最优: %dus, RMSE=%.4f', round(optimal_duration*1e6), min_rmse)}, ...
    'Location', 'best');
xlim([50, 1050]);

% 子图2: 热力图显示每个色块在不同duration下的RMSE
subplot(1, 2, 2);
imagesc(duration_list * 1e6, 1:n_colors, rmse_matrix);
colorbar;
xlabel('Duration (us)');
ylabel('色块编号');
title('各色块RMSE热力图');
colormap('jet');

% 添加最优duration标记
hold on;
xline(optimal_duration * 1e6, 'w--', 'LineWidth', 2);
hold off;

sgtitle('Duration Benchmark Results - ColorChecker Trans 0118');

%% 输出详细统计表
fprintf('\n========== 详细统计表 ==========\n');
fprintf('Duration(us)\t平均RMSE\t标准差\t\t最小RMSE\t最大RMSE\n');
for d_idx = 1:n_durations
    fprintf('%4d\t\t%.4f\t\t%.4f\t\t%.4f\t\t%.4f\n', ...
        round(duration_list(d_idx) * 1e6), ...
        mean_rmse_all(d_idx), ...
        std_rmse_all(d_idx), ...
        min(rmse_matrix(:, d_idx)), ...
        max(rmse_matrix(:, d_idx)));
end
fprintf('================================\n');

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
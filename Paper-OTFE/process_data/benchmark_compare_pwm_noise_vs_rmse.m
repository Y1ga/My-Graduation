clear; 
clc;
%% 加载基础数据
A0 = load_mat("led_pd_0118", "gt")';
colorchecker = load_mat("colorchecker_trans_0118", "gt");
idx = 15;
x = colorchecker(:, idx);

%% 参数设置
path = "./data/PD-01-18/I/";
duration = 100e-5;
duration_ref = 100e-5;
k_A = read_rigol_wfm(path+"新建文件-1.wfm", 1e9, duration_ref);
A = k_A .* A0;

%% Benchmark: 遍历file_idx从1到46
n_files = 46;
noise_ratios = zeros(n_files, 1);
rmse_values = zeros(n_files, 1);
psnr_values = zeros(n_files, 1);
valid_mask = true(n_files, 1);
y_measured_list_0118 = zeros(n_files, 12);

fprintf('开始Benchmark测试...\n');
fprintf('%-10s %-20s %-15s %-15s\n', 'File_idx', 'Noise/Signal Ratio', 'RMSE', 'PSNR(dB)');
fprintf('%s\n', repmat('-', 1, 60));

for file_idx = 1:n_files
    try
        % 读取测量数据
        y_measured = read_rigol_wfm(path+"新建文件"+num2str(file_idx)+".wfm", 1e9, duration);

        % 计算FFT并提取噪声
        fft_data = plot_rigol_fft(path+"新建文件"+num2str(file_idx)+".wfm", 1e9, duration);
        n_points = size(fft_data, 1);
        noise_mask = false(n_points, 1);
        noise_mask(2:390) = true;
        fft_mag = fft_data(:, 2);
        noise_mag = fft_mag(noise_mask);
        noise_mag_sum = sum(noise_mag);
        sig_mag_sum = sum(y_measured);
        noise_to_signal_ratio = noise_mag_sum / sig_mag_sum;
        
        % 光谱重建
        k_beta = 1;
        y = y_measured * k_beta;
        y_measured_list_0118(file_idx, :) = y_measured ./ k_A;
        x_est = fdm_reconstruct(y ./ k_A, A0, 'Method', 'tv');
        
        % 计算RMSE和PSNR
        rmse = RMSE(x_est, x);
        psnr = PSNR(rmse);
        
        % 存储结果
        noise_ratios(file_idx) = noise_to_signal_ratio;
        rmse_values(file_idx) = rmse;
        psnr_values(file_idx) = psnr;
        
        fprintf('%-10d %-20.4f %-15.4f %-15.1f\n', file_idx, noise_to_signal_ratio, rmse, psnr);
    catch ME
        warning('文件 %d 处理失败: %s', file_idx, ME.message);
        valid_mask(file_idx) = false;
    end
end
% save_mat(y_measured_list_0118, "gt");
%% 过滤有效数据
noise_ratios = noise_ratios(valid_mask);
rmse_values = rmse_values(valid_mask);
psnr_values = psnr_values(valid_mask);
file_indices = find(valid_mask);

%% 第一次线性拟合，用于检测异常点（基于PSNR）
% 同样噪声比下，PSNR高的是正常数据；PSNR低于预测值的是异常点
p_initial_psnr = polyfit(noise_ratios, psnr_values, 1);
psnr_predicted = polyval(p_initial_psnr, noise_ratios);

% 找出拟合线以下的异常点（PSNR实际值 < 拟合预测值）
outlier_mask = psnr_values < psnr_predicted;
n_outliers = sum(outlier_mask);

fprintf('\n检测到 %d 个异常点（位于PSNR拟合线以下，性能异常差）:\n', n_outliers);
outlier_indices = file_indices(outlier_mask);
outlier_noise = noise_ratios(outlier_mask);
outlier_psnr = psnr_values(outlier_mask);
outlier_psnr_pred = psnr_predicted(outlier_mask);
for i = 1:length(outlier_indices)
    fprintf('  File %d: Noise Ratio=%.4f, PSNR=%.1f dB (预测值=%.1f dB)\n', ...
        outlier_indices(i), outlier_noise(i), outlier_psnr(i), outlier_psnr_pred(i));
end

% 过滤掉异常点
inlier_mask = ~outlier_mask;
noise_ratios_clean = noise_ratios(inlier_mask);
rmse_values_clean = rmse_values(inlier_mask);
psnr_values_clean = psnr_values(inlier_mask);
file_indices_clean = file_indices(inlier_mask);

fprintf('\n过滤后剩余 %d 个数据点\n', sum(inlier_mask));

%% 绘图: Noise/Signal Ratio vs RMSE（包含异常点标记）
figure(1);
clf;
% 绘制正常点
scatter(noise_ratios_clean, rmse_values_clean, 60, 'b', 'filled', 'MarkerFaceAlpha', 0.7);
hold on;
% 绘制异常点（用红色×标记）
scatter(noise_ratios(outlier_mask), rmse_values(outlier_mask), 80, 'r', 'x', 'LineWidth', 2);

% 使用过滤后的数据进行线性拟合
p = polyfit(noise_ratios_clean, rmse_values_clean, 1);
x_fit = linspace(min(noise_ratios), max(noise_ratios), 100);
y_fit = polyval(p, x_fit);
plot(x_fit, y_fit, 'r-', 'LineWidth', 2);

% 计算相关系数（使用过滤后的数据）
R = corrcoef(noise_ratios_clean, rmse_values_clean);
r_value = R(1,2);

xlabel('Noise/Signal Ratio');
ylabel('RMSE');
title(sprintf('Noise/Signal Ratio vs RMSE (R = %.3f, 去除%d个异常点)', r_value, n_outliers));
legend('正常数据点', '异常点（PSNR拟合线以下）', sprintf('线性拟合 (y = %.4fx + %.4f)', p(1), p(2)), 'Location', 'best');
grid on;
hold off;

%% 绘图: Noise/Signal Ratio vs PSNR（使用过滤后的数据）
figure(2);
clf;
scatter(noise_ratios_clean, psnr_values_clean, 60, 'b', 'filled', 'MarkerFaceAlpha', 0.7);
hold on;
scatter(noise_ratios(outlier_mask), psnr_values(outlier_mask), 80, 'r', 'x', 'LineWidth', 2);
noise_psnr_data = zeros(46, 2);
% noise_psnr_data(:, 1) = noise_ratios;
% noise_psnr_data(:, 2) = psnr_values;
% save_mat(noise_psnr_data, "gt");
% 线性拟合（使用过滤后的数据）
p2 = polyfit(noise_ratios_clean, psnr_values_clean, 1);
x_fit2 = linspace(min(noise_ratios), max(noise_ratios), 100);
y_fit2 = polyval(p2, x_fit2);
plot(x_fit2, y_fit2, 'r-', 'LineWidth', 2);

% 计算相关系数（使用过滤后的数据）
R2 = corrcoef(noise_ratios_clean, psnr_values_clean);
r_value2 = R2(1,2);

xlabel('Noise/Signal Ratio');
ylabel('PSNR (dB)');
title(sprintf('Noise/Signal Ratio vs PSNR (R = %.3f, 去除%d个异常点)', r_value2, n_outliers));
legend('正常数据点', '异常点', sprintf('线性拟合 (y = %.4fx + %.4f)', p2(1), p2(2)), 'Location', 'best');
grid on;
hold off;

%% 打印统计摘要
fprintf('\n%s\n', repmat('=', 1, 60));
fprintf('统计摘要:\n');
fprintf('有效文件数: %d / %d\n', sum(valid_mask), n_files);
fprintf('异常点数: %d\n', n_outliers);
fprintf('过滤后数据点数: %d\n', length(noise_ratios_clean));
fprintf('\n--- 过滤后统计 ---\n');
fprintf('Noise/Signal Ratio: 均值=%.4f, 范围=[%.4f, %.4f]\n', ...
    mean(noise_ratios_clean), min(noise_ratios_clean), max(noise_ratios_clean));
fprintf('RMSE: 均值=%.4f, 范围=[%.4f, %.4f]\n', ...
    mean(rmse_values_clean), min(rmse_values_clean), max(rmse_values_clean));
fprintf('PSNR: 均值=%.1f dB, 范围=[%.1f, %.1f] dB\n', ...
    mean(psnr_values_clean), min(psnr_values_clean), max(psnr_values_clean));
fprintf('相关系数 (Noise Ratio vs RMSE): R = %.4f\n', r_value);
fprintf('相关系数 (Noise Ratio vs PSNR): R = %.4f\n', r_value2);

%% 保存结果到表格（包含异常点标记）
is_outlier = outlier_mask;
results_table = table(file_indices, noise_ratios, rmse_values, psnr_values, is_outlier, ...
    'VariableNames', {'FileIndex', 'NoiseSignalRatio', 'RMSE', 'PSNR_dB', 'IsOutlier'});
writetable(results_table, 'benchmark_results.csv');
fprintf('\n结果已保存到 benchmark_results.csv\n');

% 另存过滤后的干净数据
results_clean = table(file_indices_clean, noise_ratios_clean, rmse_values_clean, psnr_values_clean, ...
    'VariableNames', {'FileIndex', 'NoiseSignalRatio', 'RMSE', 'PSNR_dB'});
writetable(results_clean, 'benchmark_results_clean.csv');
fprintf('过滤后结果已保存到 benchmark_results_clean.csv\n');

%% ================== 读取函数（修正校正方向） ==================
function [amps, freq_detected, volt_div, v_min, v_max] = read_rigol_wfm(filename, fs, duration, options)
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

    signal = (double(raw_data) - 128) * volt_scale + volt_offset;
    
    if isfinite(duration)
        n_use = min(round(duration * fs), length(signal));
        signal = signal(1:n_use);
    end

    v_min = min(signal);
    v_max = max(signal);

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

function fft_data = plot_rigol_fft(filename, fs, duration, freq_max, do_plot)
    if nargin < 2 || isempty(fs), fs = 1e9; end
    if nargin < 3 || isempty(duration), duration = inf; end
    if nargin < 4 || isempty(freq_max), freq_max = 500; end
    if nargin < 5 || isempty(do_plot), do_plot = false; end

    fid = fopen(filename, 'rb');
    if fid == -1, error('无法打开文件: %s', filename); end

    fseek(fid, hex2dec('84'), 'bof');
    volt_div = fread(fid, 1, 'float32');
    fseek(fid, hex2dec('A0'), 'bof');
    volt_scale = fread(fid, 1, 'float32');
    volt_offset = fread(fid, 1, 'float32');
    fseek(fid, 3334, 'bof');
    raw_data = fread(fid, inf, 'uint8');
    fclose(fid);

    signal = (double(raw_data) - 128) * volt_scale + volt_offset;
    
    if isfinite(duration)
        n_use = min(round(duration * fs), length(signal));
        signal = signal(1:n_use);
    end

    signal_ac = signal - mean(signal);
    n_fft = 2^nextpow2(length(signal_ac));
    fft_result = fft(signal_ac, n_fft);
    fft_mag = abs(fft_result(1:n_fft/2));
    freq_axis = (0:n_fft/2-1) * fs / n_fft / 1e3;

    fft_mag = fft_mag * volt_div;

    valid_idx = freq_axis <= freq_max;
    freq_plot = freq_axis(valid_idx);
    mag_plot = fft_mag(valid_idx);

    fft_data = [freq_plot(:), mag_plot(:)];

    if do_plot
        figure;
        plot(freq_plot, mag_plot, 'LineWidth', 1);
        xlabel('频率 (kHz)');
        ylabel('幅值');
        title(sprintf('FFT频谱 (0-%d kHz)', freq_max));
        xlim([0, freq_max]);
        grid on;

        led_freqs = [380, 390, 400, 410, 420, 430, 440, 450, 460, 470, 480, 490];
        hold on;
        for i = 1:length(led_freqs)
            if led_freqs(i) <= freq_max
                xline(led_freqs(i), '--r', sprintf('%d', led_freqs(i)), ...
                    'LabelHorizontalAlignment', 'center', ...
                    'LabelVerticalAlignment', 'bottom', ...
                    'FontSize', 8, 'Alpha', 0.5);
            end
        end
        hold off;
    end
end
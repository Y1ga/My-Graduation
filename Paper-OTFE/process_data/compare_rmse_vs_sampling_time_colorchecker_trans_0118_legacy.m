%% Benchmark: RMSE vs Sampling Time
% 测试不同采样时间 (duration) 对光谱重建 RMSE 的影响
clear; 
clc;
close all;

%% 加载数据
A0 = load_mat("led_pd_0118", "gt")';
colorchecker = load_mat("colorchecker_trans_0118", "gt");
idx = 14;
x = colorchecker(:, idx);  % 真实光谱

%% 设置路径和参数
path = "./data/PD-01-18/H/";

% 读取校正系数 (使用固定duration)
duration_ref = 100e-5;
k_A = read_rigol_wfm(path + "新建文件-3.wfm", 1e9, duration_ref);
A = k_A .* A0;

%% Benchmark参数
durations = 100e-6 : 50e-6 : 1000e-6;  % 100us 到 1200us
n_durations = length(durations);
rmse_values = zeros(n_durations, 1);
psnr_values = zeros(n_durations, 1);

%% 运行benchmark
fprintf('开始benchmark测试...\n');
fprintf('测试 %d 个不同的采样时间\n', n_durations);
fprintf('========================================\n');

for i = 1:n_durations
    duration = durations(i);
    
    % 读取测量数据
    try
        y_measured = read_rigol_wfm(path + "新建文件" + num2str((idx-1)*4+1) + ".wfm", 1e9, duration);
        
        % 重建光谱
        k_beta = 1;
        y = y_measured * k_beta;
        x_est = fdm_reconstruct(y ./ k_A, A0, 'Method', 'tv');
        
        % 计算RMSE
        rmse_values(i) = RMSE(x_est, x);
        psnr_values(i) = PSNR(rmse_values(i));
        
        fprintf('Duration: %6.0f us, RMSE: %.4f, PSNR: %.1f dB\n', ...
            duration * 1e6, rmse_values(i), psnr_values(i));
    catch ME
        fprintf('Duration: %6.0f us, 错误: %s\n', duration * 1e6, ME.message);
        rmse_values(i) = NaN;
        psnr_values(i) = NaN;
    end
end

fprintf('========================================\n');
fprintf('Benchmark完成!\n');

%% 绘制结果
figure('Position', [100, 100, 800, 500]);

% 转换为微秒显示
durations_us = durations * 1e6;

% 绘制RMSE曲线
plot(durations_us, rmse_values, '-o', 'LineWidth', 1.5, 'MarkerSize', 6, ...
    'MarkerFaceColor', 'auto');


% 均值曲线（只显示数据点）
plot(durations_us, mean_rmse_all, '--o', ...
    'Color', [0.2, 0.4, 0.8], 'LineWidth', 1.5, 'MarkerSize', 6, ...
    'MarkerFaceColor', [0.2, 0.4, 0.8]);

[min_rmse, min_idx] = min(mean_rmse_all);

xlabel('Sampling time (μs)', 'FontSize', 12, 'FontName', 'Arial');
ylabel('Mean RMSE', 'FontSize', 12, 'FontName', 'Arial');
if show_grid
    grid on;
end
xlim([min(duration_us)-20, max(duration_us)+20]);

set(gca, 'FontName', 'Arial', 'FontSize', 11, 'Box', 'on');
h_gt = gcf;
set_fig(h_gt,'Arial',14,1.5,[18, 12]);

%% 保存数据
results = table(durations_us', rmse_values, psnr_values, ...
    'VariableNames', {'SamplingTime_us', 'RMSE', 'PSNR_dB'});
writetable(results, 'benchmark_results.csv');
fprintf('数据已保存到 benchmark_results.csv\n');

%% ================== 辅助函数 ==================
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
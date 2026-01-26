%% Benchmark: RMSE vs Sampling Time (遍历所有24个色块)
% 测试不同采样时间 (duration) 对光谱重建 RMSE 的影响
clear; 
clc;
close all;

%% 加载数据
A0 = load_mat("led_pd_0118", "gt")';
colorchecker = load_mat("colorchecker_trans_0118", "gt");

%% 设置路径和参数
path = "./data/PD-01-18/H/";

% 读取校正系数 (使用固定duration)
duration_ref = 100e-5;
k_A = read_rigol_wfm(path + "新建文件-1.wfm", 1e9, duration_ref);
A = k_A .* A0;

%% Benchmark参数
durations = 100e-6 : 100e-6 : 1200e-6;  % 100us 到 1200us
n_durations = length(durations);
n_colors = 24;  % 24个色块

% 存储所有结果
rmse_all = zeros(n_durations, n_colors);
psnr_all = zeros(n_durations, n_colors);

%% 运行benchmark
fprintf('开始benchmark测试...\n');
fprintf('测试 %d 个色块 × %d 个采样时间 = %d 次测试\n', ...
    n_colors, n_durations, n_colors * n_durations);
fprintf('========================================\n');

for idx = 1:n_colors
    x = colorchecker(:, idx);  % 真实光谱
    
    fprintf('\n色块 %02d/%02d:\n', idx, n_colors);
    
    for i = 1:n_durations
        duration = durations(i);
        
        try
            % 读取测量数据
            y_measured = read_rigol_wfm(path + "新建文件" + num2str((idx-1)*4+1) + ".wfm", 1e9, duration);
            
            % 重建光谱
            y = y_measured;
            x_est = fdm_reconstruct(y ./ k_A, A0, 'Method', 'tv');
            
            % 计算RMSE
            rmse_all(i, idx) = RMSE(x_est, x);
            psnr_all(i, idx) = PSNR(rmse_all(i, idx));
            
        catch ME
            rmse_all(i, idx) = NaN;
            psnr_all(i, idx) = NaN;
        end
    end
    
    % 打印该色块的最优结果
    [min_rmse, min_idx] = min(rmse_all(:, idx));
    fprintf('  最优: Duration = %d us, RMSE = %.4f, PSNR = %.1f dB\n', ...
        round(durations(min_idx) * 1e6), min_rmse, psnr_all(min_idx, idx));
end

fprintf('\n========================================\n');
fprintf('Benchmark完成!\n');

%% 绘制结果 - 所有色块叠加
figure('Position', [100, 100, 1000, 600]);
durations_us = durations * 1e6;

% 使用colormap区分不同色块
colors = lines(n_colors);

subplot(1,2,1);
hold on;
for idx = 1:n_colors
    plot(durations_us, rmse_all(:, idx), '-o', 'LineWidth', 1, ...
        'MarkerSize', 4, 'Color', colors(idx,:), 'DisplayName', sprintf('色块%02d', idx));
end
hold off;
xlabel('Sampling Time (\mus)', 'FontSize', 12);
ylabel('RMSE', 'FontSize', 12);
title('各色块 RMSE vs Sampling Time', 'FontSize', 14);
grid on;
xlim([min(durations_us), max(durations_us)]);
legend('Location', 'eastoutside', 'FontSize', 7);

% 绘制平均RMSE
subplot(1,2,2);
rmse_mean = mean(rmse_all, 2, 'omitnan');
rmse_std = std(rmse_all, 0, 2, 'omitnan');

errorbar(durations_us, rmse_mean, rmse_std, '-o', 'LineWidth', 1.5, ...
    'MarkerSize', 6, 'MarkerFaceColor', 'auto', 'CapSize', 8);
xlabel('Sampling Time (\mus)', 'FontSize', 12);
ylabel('RMSE', 'FontSize', 12);
title('平均 RMSE vs Sampling Time (误差棒=标准差)', 'FontSize', 14);
grid on;
xlim([min(durations_us), max(durations_us)]);

% 标注最优点
[min_rmse_mean, min_idx] = min(rmse_mean);
hold on;
plot(durations_us(min_idx), min_rmse_mean, 'rp', 'MarkerSize', 15, 'MarkerFaceColor', 'r');
text(durations_us(min_idx) + 30, min_rmse_mean + 0.005, ...
    sprintf('Min = %.4f\n@ %d \\mus', min_rmse_mean, round(durations_us(min_idx))), ...
    'FontSize', 10, 'Color', 'r');
hold off;

sgtitle('Benchmark: RMSE vs Sampling Time (24色块)', 'FontSize', 16);

% 保存图像
saveas(gcf, 'benchmark_rmse_all_colors.png');
saveas(gcf, 'benchmark_rmse_all_colors.fig');

%% 绘制热力图
figure('Position', [100, 100, 900, 500]);
imagesc(1:n_colors, durations_us, rmse_all);
colorbar;
xlabel('色块编号', 'FontSize', 12);
ylabel('Sampling Time (\mus)', 'FontSize', 12);
title('RMSE 热力图 (色块 × 采样时间)', 'FontSize', 14);
colormap('jet');
set(gca, 'YDir', 'normal');

% 保存热力图
saveas(gcf, 'benchmark_rmse_heatmap.png');
saveas(gcf, 'benchmark_rmse_heatmap.fig');

%% 统计分析
fprintf('\n========== 统计分析 ==========\n');

% 每个duration的平均RMSE
fprintf('\n各采样时间的平均RMSE:\n');
for i = 1:n_durations
    fprintf('  %4d us: RMSE = %.4f ± %.4f\n', ...
        round(durations_us(i)), rmse_mean(i), rmse_std(i));
end

% 找出每个色块的最优duration
fprintf('\n各色块的最优采样时间:\n');
optimal_durations = zeros(n_colors, 1);
for idx = 1:n_colors
    [~, opt_idx] = min(rmse_all(:, idx));
    optimal_durations(idx) = durations_us(opt_idx);
    fprintf('  色块%02d: %4d us (RMSE = %.4f)\n', idx, round(optimal_durations(idx)), rmse_all(opt_idx, idx));
end

fprintf('\n最优采样时间分布:\n');
fprintf('  平均值: %.0f us\n', mean(optimal_durations));
fprintf('  中位数: %.0f us\n', median(optimal_durations));
fprintf('  众数: %.0f us\n', mode(optimal_durations));

%% 保存数据
% 保存完整矩阵
save('benchmark_results_all.mat', 'durations', 'rmse_all', 'psnr_all', 'rmse_mean', 'rmse_std');

% 保存CSV (平均值)
results_mean = table(durations_us', rmse_mean, rmse_std, ...
    'VariableNames', {'SamplingTime_us', 'RMSE_mean', 'RMSE_std'});
writetable(results_mean, 'benchmark_results_mean.csv');

% 保存CSV (完整数据)
T = array2table([durations_us', rmse_all], ...
    'VariableNames', ['SamplingTime_us', arrayfun(@(x) sprintf('Color%02d', x), 1:n_colors, 'UniformOutput', false)]);
writetable(T, 'benchmark_results_full.csv');

fprintf('\n数据已保存!\n');

%% ================== 辅助函数 ==================
function [amps, freq_detected, volt_div, v_min, v_max] = read_rigol_wfm(filename, fs, duration)
    if nargin < 2 || isempty(fs), fs = 1e9; end
    if nargin < 3 || isempty(duration), duration = inf; end

    led_freqs = [380, 390, 400, 410, 420, 430, 440, 450, 460, 470, 480, 490];
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
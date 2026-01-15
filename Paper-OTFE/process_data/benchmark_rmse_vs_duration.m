clear;
clc;
close all;

%% 加载基础数据
A0 = load_mat("led_0711", "gt")';
A0 = A0 ./ sum(A0, 2);
colorchecker = load_mat("colorchecker_gt", "gt");

%% 路径和参数设置
path = "./data/PD-01-04/";

% duration范围: 100e-6 到 100e-5 (即 1e-4 到 1e-3)
n_durations = 20;
durations = logspace(-6, -4, n_durations) * 100;  % 100e-6 到 100e-5

n_colors = 24;
beta = 1e-4;

%% 存储结果
rmse_mean = zeros(n_durations, 1);
psnr_mean = zeros(n_durations, 1);
rmse_std = zeros(n_durations, 1);
psnr_std = zeros(n_durations, 1);

%% 遍历不同duration
for d_idx = 1:n_durations
    duration = durations(d_idx);
    fprintf('Processing duration: %.2e s (%d/%d)\n', duration, d_idx, n_durations);
    
    % 读取校准系数
    k_A = read_rigol_wfm(path + "新建文件-1.wfm", 1e9, duration);
    A = k_A .* A0;
    a = A * beta;
    
    rmse_all = zeros(n_colors, 1);
    psnr_all = zeros(n_colors, 1);
    
    for idx = 1:n_colors
        % 读取测量信号
        y = read_rigol_wfm(path + "新建文件" + num2str(idx) + ".wfm", 1e9, duration);
        yy = y * beta;
        
        % 光谱重建
        x_P = opt_gd(a, yy);
        
        % 真实光谱
        x_gt = colorchecker(:, idx);
        x_gt = x_gt * max(x_P, [], 'all') / max(x_gt, [], 'all');
        
        % 计算指标
        rmse_all(idx) = RMSE(x_P, x_gt);
        psnr_all(idx) = PSNR(x_P, x_gt);
    end
    
    % 保存平均值和标准差
    rmse_mean(d_idx) = mean(rmse_all);
    psnr_mean(d_idx) = mean(psnr_all);
    rmse_std(d_idx) = std(rmse_all);
    psnr_std(d_idx) = std(psnr_all);
end

%% Figure 1: Duration vs RMSE
figure('Position', [100, 100, 600, 450]);
errorbar(durations * 1e6, rmse_mean, rmse_std, 'b-o', 'LineWidth', 1.5, 'MarkerSize', 6, 'MarkerFaceColor', 'b');
set(gca, 'XScale', 'log');
xlabel('Duration (μs)');
ylabel('平均 RMSE');
title('采样时间 vs 光谱重建RMSE');
grid on;
xlim([min(durations) * 1e6 * 0.8, max(durations) * 1e6 * 1.2]);

%% Figure 2: Duration vs PSNR
figure('Position', [750, 100, 600, 450]);
errorbar(durations * 1e6, psnr_mean, psnr_std, 'r-s', 'LineWidth', 1.5, 'MarkerSize', 6, 'MarkerFaceColor', 'r');
set(gca, 'XScale', 'log');
xlabel('Duration (μs)');
ylabel('平均 PSNR (dB)');
title('采样时间 vs 光谱重建PSNR');
grid on;
xlim([min(durations) * 1e6 * 0.8, max(durations) * 1e6 * 1.2]);

%% 输出统计信息
fprintf('\n========== Duration Benchmark结果 ==========\n');
fprintf('Duration(μs)\tRMSE\t\tPSNR(dB)\n');
for d_idx = 1:n_durations
    fprintf('%.1f\t\t%.4f±%.4f\t%.2f±%.2f\n', ...
        durations(d_idx) * 1e6, rmse_mean(d_idx), rmse_std(d_idx), ...
        psnr_mean(d_idx), psnr_std(d_idx));
end
fprintf('=============================================\n');

%% 保存数据
save('benchmark_duration_results.mat', 'durations', 'rmse_mean', 'rmse_std', 'psnr_mean', 'psnr_std');

%% ================== PSNR函数 ==================
function p = PSNR(x_pred, x_gt)
    mse = mean((x_pred(:) - x_gt(:)).^2);
    max_val = max(x_gt(:));
    p = 10 * log10(max_val^2 / mse);
end

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
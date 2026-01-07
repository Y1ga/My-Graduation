%% ==================== E2E网络仿真数据集生成器（修复版） ====================
% 
% 方案C（R=0.9862）:
%   实测预处理: y_input = y_raw / max(y_raw)        ← 不除k_A！
%   仿真生成:   sim = k_A .* (A0 * x) / max(...)
%
clear; clc; close all;

%% ==================== 配置参数 ====================
config = struct();

% 数据集大小
config.N_train = 50000;
config.N_val = 5000;
config.N_test = 5000;

% LED配置
config.f_led = [30, 50, 70, 110, 130, 170, 190, 230, 290, 310, 370, 410] * 1e3;
config.N_led = length(config.f_led);

% 采样参数
config.fs = 1e9;
config.T = 350e-6;
config.downsample = 100;
config.fs_ds = config.fs / config.downsample;
config.N_points = round(config.fs * config.T);
config.N_points_ds = config.N_points / config.downsample;

% 光谱参数
config.wav = linspace(400, 700, 31);
config.N_channels = 31;

% 噪声参数
config.snr_range = [20, 40];
config.add_quantization = true;
config.quant_bits = 8;

% 输出配置
config.output_type = 'fft';        % 'time' 或 'fft'
config.normalize = 'max';          % 方案C: max归一化

% 保存路径
config.save_path = './dataset/';

fprintf('========================================\n');
fprintf('   E2E网络仿真数据集生成器（修复版）\n');
fprintf('========================================\n');
fprintf('方案C: 实测=y/max(y), 仿真=k_A.*(A0*x)/max\n');
fprintf('训练集: %d, 验证集: %d, 测试集: %d\n', ...
        config.N_train, config.N_val, config.N_test);

%% ==================== 加载基础数据 ====================
fprintf('\n[1] 加载基础数据...\n');

% LED光谱矩阵
A0 = load_mat("led_0711", "gt")';
fprintf('  A0: [%d × %d]\n', size(A0));

% 实测k_A
data_path = "./data/PD-01-04/";
[k_A, ~, ~] = read_rigol_wfm(fullfile(data_path, "新建文件-1.wfm"), config.fs, config.T);
fprintf('  k_A: [%.2f ~ %.2f]\n', min(k_A), max(k_A));

% ColorChecker
colorchecker = load_mat("colorchecker", "gt");
if size(colorchecker, 1) == 31
    colorchecker = colorchecker';
end
fprintf('  ColorChecker: [%d × %d]\n', size(colorchecker));

%% ==================== 预计算调制矩阵 ====================
fprintf('\n[2] 预计算调制矩阵...\n');
t_ds = (0:config.N_points_ds-1) / config.fs_ds;
modulation_matrix = zeros(config.N_led, config.N_points_ds);
for k = 1:config.N_led
    sq_wave = square(2 * pi * config.f_led(k) * t_ds);
    modulation_matrix(k, :) = (sq_wave + 1) / 2;
end
fprintf('  调制矩阵: [%d × %d]\n', size(modulation_matrix));

%% ==================== 生成数据集 ====================
fprintf('\n[3] 生成数据集...\n');

if ~exist(config.save_path, 'dir')
    mkdir(config.save_path);
end

datasets = {'train', 'val', 'test'};
sizes = [config.N_train, config.N_val, config.N_test];

for d = 1:3
    dataset_name = datasets{d};
    N_samples = sizes(d);
    
    fprintf('\n  生成 %s 集 (%d 样本)...\n', dataset_name, N_samples);
    
    % 预分配
    if strcmp(config.output_type, 'time')
        X_data = zeros(N_samples, config.N_points_ds, 'single');
    else
        X_data = zeros(N_samples, config.N_led, 'single');
    end
    Y_data = zeros(N_samples, config.N_channels, 'single');
    
    progress_step = max(1, floor(N_samples / 10));
    
    for i = 1:N_samples
        if mod(i, progress_step) == 0
            fprintf('    进度: %d/%d (%.0f%%)\n', i, N_samples, i/N_samples*100);
        end
        
        % 1. 生成随机光谱
        x = generate_random_spectrum(colorchecker, config.wav);
        Y_data(i, :) = x';
        
        % 2. 计算LED响应: k_A .* (A0 * x) ← 方案C关键！
        led_response = k_A .* (A0 * x);
        
        % 3. 生成时域信号
        signal_time = led_response' * modulation_matrix;
        
        % 4. 添加噪声
        snr_db = config.snr_range(1) + rand() * diff(config.snr_range);
        signal_time = add_noise(signal_time, snr_db, config);
        
        % 5. 提取FFT或时域
        if strcmp(config.output_type, 'time')
            % 时域: max归一化
            signal_out = signal_time / max(abs(signal_time));
            X_data(i, :) = signal_out;
        else
            % FFT提取
            fft_amps = extract_fft_amplitudes(signal_time, config);
            % max归一化 ← 方案C关键！
            fft_out = fft_amps / max(fft_amps);
            X_data(i, :) = fft_out';
        end
    end
    
    % 保存
    save_file = fullfile(config.save_path, sprintf('%s_dataset.mat', dataset_name));
    save(save_file, 'X_data', 'Y_data', 'config', '-v7.3');
    fprintf('  已保存: %s\n', save_file);
end

%% ==================== 生成实测数据（方案C预处理） ====================
fprintf('\n[4] 生成实测数据（方案C预处理）...\n');

real_X = zeros(24, config.N_led, 'single');
real_Y = zeros(24, config.N_channels, 'single');

for idx = 1:24
    filename = fullfile(data_path, sprintf("新建文件%d.wfm", idx));
    if exist(filename, 'file')
        [y_raw, ~, ~] = read_rigol_wfm(filename, config.fs, config.T);
        
        % 方案C预处理: y / max(y) ← 不除k_A！
        y_norm = y_raw / max(y_raw);
        
        real_X(idx, :) = y_norm';
        real_Y(idx, :) = colorchecker(idx, :);
    end
end

save(fullfile(config.save_path, 'real_test.mat'), 'real_X', 'real_Y', 'k_A', 'A0', '-v7.3');
fprintf('  已保存: real_test.mat\n');

%% ==================== 验证相关性 ====================
fprintf('\n[5] 验证相关性...\n');

% 生成ColorChecker的仿真数据（方案C）
sim_colorchecker = zeros(24, config.N_led);
for idx = 1:24
    x = colorchecker(idx, :)';
    led_resp = k_A .* (A0 * x);
    led_resp = led_resp / max(led_resp);
    sim_colorchecker(idx, :) = led_resp';
end

% 计算相关性
overall_corr = corr(sim_colorchecker(:), real_X(:));
fprintf('  仿真 vs 实测 相关性: %.4f\n', overall_corr);

if overall_corr > 0.95
    fprintf('  ✓ 数据集质量优秀！\n');
elseif overall_corr > 0.9
    fprintf('  ○ 数据集质量良好\n');
else
    fprintf('  ✗ 数据集质量较差，请检查\n');
end

%% ==================== 可视化验证 ====================
fprintf('\n[6] 可视化验证...\n');

figure('Position', [50, 50, 1400, 600], 'Color', 'w');

% 图1: 散点图
subplot(1, 3, 1);
scatter(sim_colorchecker(:), real_X(:), 30, 'b', 'filled', 'MarkerFaceAlpha', 0.5);
hold on;
plot([0, 1], [0, 1], 'r--', 'LineWidth', 2);
xlabel('仿真: k_A.*(A0*x) / max');
ylabel('实测: y / max(y)');
title(sprintf('方案C验证 (R=%.4f)', overall_corr));
grid on; axis equal;
xlim([0, 1.1]); ylim([0, 1.1]);

% 图2: 各LED相关性
subplot(1, 3, 2);
led_corr = zeros(config.N_led, 1);
for k = 1:config.N_led
    led_corr(k) = corr(sim_colorchecker(:, k), real_X(:, k));
end
bar(led_corr, 'FaceColor', [0.3, 0.6, 0.9]);
xlabel('LED序号');
ylabel('相关系数');
title(sprintf('各LED相关性 (均值=%.3f)', mean(led_corr)));
ylim([0, 1]);
grid on;

% 图3: 典型色卡对比
subplot(1, 3, 3);
idx_show = 14;
bar([sim_colorchecker(idx_show, :); real_X(idx_show, :)]', 'grouped');
xlabel('LED序号');
ylabel('归一化幅度');
title(sprintf('色卡#%d对比', idx_show));
legend('仿真', '实测', 'Location', 'best');
grid on;

sgtitle('数据集验证（方案C修复版）', 'FontSize', 14, 'FontWeight', 'bold');
saveas(gcf, fullfile(config.save_path, 'dataset_verification_fixed.png'));
fprintf('  已保存: dataset_verification_fixed.png\n');

%% ==================== 输出总结 ====================
fprintf('\n========================================\n');
fprintf('          数据集生成完成\n');
fprintf('========================================\n');
fprintf('\n方案C配置:\n');
fprintf('  实测预处理: y / max(y)\n');
fprintf('  仿真生成:   k_A .* (A0 * x) / max(...)\n');
fprintf('\n文件列表:\n');
fprintf('  - train_dataset.mat: %d 样本\n', config.N_train);
fprintf('  - val_dataset.mat: %d 样本\n', config.N_val);
fprintf('  - test_dataset.mat: %d 样本\n', config.N_test);
fprintf('  - real_test.mat: 24 色卡\n');
fprintf('\n验证结果:\n');
fprintf('  相关性: %.4f\n', overall_corr);
fprintf('========================================\n');

%% ==================== 辅助函数 ====================

function x = generate_random_spectrum(real_spectra, wav)
    N_channels = length(wav);
    method = randi(4);
    
    switch method
        case 1  % 真实光谱混合
            n_mix = randi([2, 4]);
            idx = randperm(size(real_spectra, 1), n_mix);
            weights = rand(n_mix, 1);
            weights = weights / sum(weights);
            x = real_spectra(idx, :)' * weights;
            
        case 2  % 高斯基函数
            n_gauss = randi([2, 5]);
            x = zeros(N_channels, 1);
            for g = 1:n_gauss
                center = 400 + rand() * 300;
                sigma = 20 + rand() * 60;
                amp = 0.2 + rand() * 0.8;
                x = x + amp * exp(-((wav' - center).^2) / (2*sigma^2));
            end
            
        case 3  % 平滑随机
            x = rand(N_channels, 1);
            kernel = [0.1, 0.2, 0.4, 0.2, 0.1]';
            x = conv(x, kernel, 'same');
            
        case 4  % 真实+扰动
            idx = randi(size(real_spectra, 1));
            x = real_spectra(idx, :)';
            x = x + 0.1 * randn(N_channels, 1);
    end
    
    x = max(0, min(1, x));
    scale = 0.3 + rand() * 0.7;
    x = x * scale;
end

function signal_noisy = add_noise(signal, snr_db, config)
    signal_power = mean(signal.^2);
    noise_power = signal_power / (10^(snr_db/10));
    noise = sqrt(noise_power) * randn(size(signal));
    signal_noisy = signal + noise;
    
    mult_noise = 1 + 0.02 * randn(size(signal));
    signal_noisy = signal_noisy .* mult_noise;
    
    if config.add_quantization
        quant_levels = 2^config.quant_bits;
        signal_range = max(signal_noisy) - min(signal_noisy);
        if signal_range > 0
            quant_step = signal_range / quant_levels;
            signal_noisy = round(signal_noisy / quant_step) * quant_step;
        end
    end
    
    signal_noisy = max(0, signal_noisy);
end

function fft_amps = extract_fft_amplitudes(signal, config)
    signal_ac = signal - mean(signal);
    n_fft = length(signal_ac);
    fft_result = fft(signal_ac, n_fft);
    fft_mag = abs(fft_result(1:n_fft/2));
    freq_axis = (0:n_fft/2-1) * config.fs_ds / n_fft;
    
    fft_amps = zeros(config.N_led, 1);
    search_width = 5e3;
    
    for k = 1:config.N_led
        mask = (freq_axis >= config.f_led(k) - search_width) & ...
               (freq_axis <= config.f_led(k) + search_width);
        [max_val, ~] = max(fft_mag .* mask);
        fft_amps(k) = max_val;
    end
end

function [amps, freq_detected, volt_div] = read_rigol_wfm(filename, fs, duration)
    if nargin < 2 || isempty(fs), fs = 1e9; end
    if nargin < 3 || isempty(duration), duration = inf; end
    
    led_freqs = [30, 50, 70, 110, 130, 170, 190, 230, 290, 310, 370, 410];
    n_leds = length(led_freqs);
    
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
    freq_resolution = fs / n_fft / 1e3;
    
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
    
    amps = amps * volt_div;
end
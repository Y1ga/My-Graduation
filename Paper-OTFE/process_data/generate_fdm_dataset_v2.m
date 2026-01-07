%% generate_fdm_dataset_v2.m
% FDM 端到端数据集生成 - 优化版本
% 确保FFT分辨率能精确对准LED频率

clear; clc; close all;

%% ==================== 配置参数 ====================
fprintf('========== FDM E2E 数据集生成 (优化版) ==========\n');

% LED频率 (Hz)
f_led = [30, 50, 70, 110, 130, 170, 190, 230, 290, 310, 370, 410] * 1e3;
N_led = length(f_led);

% 关键：选择合适的采样参数，使FFT分辨率是LED频率的公约数
% LED频率的最大公约数是 10 kHz
% 所以FFT分辨率应该是 10 kHz 的因子

% 方案：采样率 1 MHz，采样 1000 点，FFT分辨率 = 1 kHz
% 这样每个LED频率都是整数个bin

fs_ds = 1e6;            % 降采样后采样率: 1 MHz
N_points_ds = 1000;     % 采样点数: 1000
duration_ds = N_points_ds / fs_ds;  % 持续时间: 1 ms

% 原始采样率和降采样因子（用于读取wfm文件）
fs = 1e9;
downsample_factor = fs / fs_ds;  % 1000

fprintf('采样参数:\n');
fprintf('  降采样后采样率: %.2f MHz\n', fs_ds / 1e6);
fprintf('  采样点数: %d\n', N_points_ds);
fprintf('  持续时间: %.1f ms\n', duration_ds * 1e3);
fprintf('  FFT分辨率: %.0f Hz = %.1f kHz\n', fs_ds / N_points_ds, fs_ds / N_points_ds / 1e3);
fprintf('  降采样因子: %d\n', downsample_factor);

% 验证LED频率是否都在FFT bin上
fft_resolution = fs_ds / N_points_ds;
fprintf('\nLED频率验证:\n');
all_integer = true;
for k = 1:N_led
    bin_idx = f_led(k) / fft_resolution;
    is_int = abs(round(bin_idx) - bin_idx) < 1e-6;
    fprintf('  LED %2d: %3d kHz -> bin %.1f %s\n', k, f_led(k)/1e3, bin_idx, char(is_int * '✓'));
    all_integer = all_integer && is_int;
end
if all_integer
    fprintf('✓ 所有LED频率都是整数bin\n');
else
    fprintf('✗ 有LED频率不是整数bin，需要调整参数\n');
end

% 检查奈奎斯特
nyquist = fs_ds / 2;
if max(f_led) < nyquist
    fprintf('✓ 最高频率 %d kHz < 奈奎斯特 %d kHz\n', max(f_led)/1e3, nyquist/1e3);
else
    fprintf('✗ 最高频率超过奈奎斯特！\n');
    return;
end

% 噪声参数
snr_db_range = [15, 35];
snr_db_mean = 27;

% 归一化方法
normalize_method = 'zscore';

% 数据路径
data_dir = 'W:\dataset\benchmark\merged_data\';
cave_file = 'CAVE_1D.mat';
kaist_file = 'KAIST_1D.mat';
wfm_path = "./data/PD-01-04/";

% 采样数量
N_train_samples = 100000;
N_val_samples = 10000;
N_test_samples = 50000;

% 数据增强参数
brightness_augment = true;
n_brightness_levels = 5;
include_colorchecker = true;
n_colorchecker_copies = 2000;

% 保存路径
save_dir = './dataset';

rng(42);

%% ==================== 加载系统参数 ====================
fprintf('\n[1/6] 加载系统参数...\n');

A0 = load_mat("led_0711", "gt")';
A0 = A0 ./ sum(A0, 2);
fprintf('  LED光谱矩阵 A0: [%d × %d]\n', size(A0));

% 读取白板获取系统增益
k_A = read_rigol_wfm(wfm_path + "新建文件-1.wfm", fs, duration_ds * downsample_factor);
fprintf('  系统增益 k_A: [%d × 1]\n', length(k_A));

n_channels = size(A0, 2);
fprintf('  LED数量: %d, 光谱通道数: %d\n', N_led, n_channels);

%% ==================== 预计算调制矩阵 ====================
fprintf('\n预计算调制矩阵...\n');

t_ds = (0:N_points_ds-1)' / fs_ds;  % [N_points_ds × 1]

% 调制矩阵 [N_points_ds × N_led]
modulation_matrix = zeros(N_points_ds, N_led);
for k = 1:N_led
    modulation_matrix(:, k) = (sign(sin(2 * pi * f_led(k) * t_ds)) + 1) / 2;
end
fprintf('  调制矩阵: [%d × %d]\n', size(modulation_matrix));

%% ==================== 加载光谱数据集 ====================
fprintf('\n[2/6] 加载CAVE数据集...\n');
tic;
cave_path = fullfile(data_dir, cave_file);
cave_data = load(cave_path);
fn = fieldnames(cave_data);
for i = 1:length(fn)
    if numel(cave_data.(fn{i})) > 1000
        cave_spectra = double(cave_data.(fn{i}));
        break;
    end
end
clear cave_data;

if size(cave_spectra, 2) ~= n_channels && size(cave_spectra, 1) == n_channels
    cave_spectra = cave_spectra';
end
N_cave = size(cave_spectra, 1);
fprintf('  CAVE: [%d × %d], 耗时: %.1f秒\n', size(cave_spectra), toc);

fprintf('\n[3/6] 加载KAIST数据集...\n');
tic;
kaist_path = fullfile(data_dir, kaist_file);
kaist_data = load(kaist_path);
fn = fieldnames(kaist_data);
for i = 1:length(fn)
    if numel(kaist_data.(fn{i})) > 1000
        kaist_spectra = double(kaist_data.(fn{i}));
        break;
    end
end
clear kaist_data;

if size(kaist_spectra, 2) ~= n_channels && size(kaist_spectra, 1) == n_channels
    kaist_spectra = kaist_spectra';
end
N_kaist = size(kaist_spectra, 1);
fprintf('  KAIST: [%d × %d], 耗时: %.1f秒\n', size(kaist_spectra), toc);

fprintf('\n  加载ColorChecker...\n');
if include_colorchecker
    colorchecker = load_mat("colorchecker_gt", "gt");
    if size(colorchecker, 1) == n_channels
        colorchecker = colorchecker';
    end
    fprintf('  ColorChecker: [%d × %d]\n', size(colorchecker));
end

%% ==================== 数据增强与采样 ====================
fprintf('\n[4/6] 数据增强与采样...\n');

n_cave_base = min(ceil(N_train_samples / n_brightness_levels), N_cave);
idx_cave = randperm(N_cave, n_cave_base);
cave_sampled = cave_spectra(idx_cave, :);
clear cave_spectra;
fprintf('  CAVE 基础采样: %d\n', size(cave_sampled, 1));

if brightness_augment
    fprintf('  亮度增强 (×%d)...\n', n_brightness_levels);
    cave_augmented = augment_brightness(cave_sampled, n_brightness_levels);
    fprintf('  增强后: %d 样本\n', size(cave_augmented, 1));
else
    cave_augmented = cave_sampled;
end

if include_colorchecker
    fprintf('  ColorChecker 增强 (×%d)...\n', n_colorchecker_copies);
    cc_augmented = augment_colorchecker(colorchecker, n_colorchecker_copies, n_channels);
    fprintf('  ColorChecker 增强后: %d 样本\n', size(cc_augmented, 1));
    all_train_spectra = [cave_augmented; cc_augmented];
else
    all_train_spectra = cave_augmented;
end

idx_kaist = randperm(N_kaist, min(N_test_samples, N_kaist));
test_spectra = kaist_spectra(idx_kaist, :);
clear kaist_spectra;

idx_shuffle = randperm(size(all_train_spectra, 1));
all_train_spectra = all_train_spectra(idx_shuffle, :);

n_train = min(N_train_samples, size(all_train_spectra, 1) - N_val_samples);
n_val = min(N_val_samples, size(all_train_spectra, 1) - n_train);

Y_train = all_train_spectra(1:n_train, :);
Y_val = all_train_spectra(n_train+1:n_train+n_val, :);
Y_test = test_spectra;

Y_train = max(min(Y_train, 1), 0);
Y_val = max(min(Y_val, 1), 0);
Y_test = max(min(Y_test, 1), 0);

Y_train(isnan(Y_train)) = 0;
Y_val(isnan(Y_val)) = 0;
Y_test(isnan(Y_test)) = 0;

fprintf('\n  最终数据集:\n');
fprintf('    训练集: %d, 验证集: %d, 测试集: %d\n', size(Y_train, 1), size(Y_val, 1), size(Y_test, 1));

%% ==================== 快速生成时域信号 ====================
fprintf('\n[5/6] 快速生成时域信号...\n');

% 系统矩阵 A = k_A .* A0, [12 × 31]
A = k_A .* A0;

% --- 训练集 ---
fprintf('\n  生成训练集 (%d 样本)...\n', size(Y_train, 1));
tic;
X_train = generate_signals_fast(Y_train, A, modulation_matrix, snr_db_range, normalize_method, true);
fprintf('    耗时: %.1f 秒\n', toc);

% --- 验证集 ---
fprintf('  生成验证集 (%d 样本)...\n', size(Y_val, 1));
tic;
X_val = generate_signals_fast(Y_val, A, modulation_matrix, snr_db_range, normalize_method, true);
fprintf('    耗时: %.1f 秒\n', toc);

% --- 测试集 ---
fprintf('  生成测试集 (%d 样本)...\n', size(Y_test, 1));
tic;
X_test = generate_signals_fast(Y_test, A, modulation_matrix, [snr_db_mean, snr_db_mean], normalize_method, false);
fprintf('    耗时: %.1f 秒\n', toc);

Y_train = single(Y_train);
Y_val = single(Y_val);
Y_test = single(Y_test);

%% ==================== 验证 ====================
fprintf('\n[6/6] 验证...\n');

% 验证：从时域信号提取FFT，看是否与理想一致
colorchecker_gt = load_mat("colorchecker_gt", "gt");
test_idx = 14;
x_gt = colorchecker_gt(:, test_idx);

% 理想FFT幅值
y_ideal = A * x_gt;

% 生成时域信号（无噪声，无归一化）
I_led = (A * x_gt)';
signal_raw = I_led * modulation_matrix';

% 提取FFT幅值
signal_ac = signal_raw - mean(signal_raw);
n_fft = N_points_ds;  % 不补零，直接用采样点数
fft_result = fft(signal_ac, n_fft);
fft_mag = abs(fft_result(1:n_fft/2));
freq_axis = (0:n_fft/2-1)' * fs_ds / n_fft;

y_extracted = zeros(N_led, 1);
for k = 1:N_led
    bin_idx = round(f_led(k) / fft_resolution) + 1;  % MATLAB 1-indexed
    if bin_idx <= length(fft_mag)
        y_extracted(k) = fft_mag(bin_idx);
    end
end

% 归一化对比
y_ideal_norm = y_ideal / sum(y_ideal);
y_extracted_norm = y_extracted / sum(y_extracted);
R = corr(y_ideal_norm, y_extracted_norm);

fprintf('\n  FFT提取验证 (色卡#%d):\n', test_idx);
fprintf('    相关系数: %.6f\n', R);

if R > 0.99
    fprintf('    ✓ 时域信号FFT提取正确\n');
else
    fprintf('    ✗ FFT提取有问题，相关系数: %.4f\n', R);
end

%% ==================== 保存 ====================
fprintf('\n保存数据...\n');

config = struct();
config.fs_ds = fs_ds;
config.N_points_ds = N_points_ds;
config.duration_ds = duration_ds;
config.downsample_factor = downsample_factor;
config.f_led = f_led;
config.N_led = N_led;
config.fft_resolution = fft_resolution;
config.snr_db_range = snr_db_range;
config.snr_db_mean = snr_db_mean;
config.normalize_method = normalize_method;
config.n_channels = n_channels;
config.A0 = A0;
config.k_A = k_A;
config.A = A;
config.modulation_matrix = modulation_matrix;

if ~exist(save_dir, 'dir')
    mkdir(save_dir);
end

save_name = sprintf('fdm_e2e_%dpts_%s_v2.mat', N_points_ds, normalize_method);
save_path = fullfile(save_dir, save_name);

save(save_path, 'X_train', 'Y_train', 'X_val', 'Y_val', 'X_test', 'Y_test', 'config', '-v7.3');

fprintf('  已保存: %s\n', save_path);
info = dir(save_path);
fprintf('  文件大小: %.1f MB\n', info.bytes/1e6);

%% ==================== 可视化 ====================
fprintf('\n生成可视化...\n');

figure('Position', [100, 100, 1400, 600]);

subplot(2, 3, 1);
histogram(Y_train(:), 50, 'Normalization', 'pdf');
xlabel('反射率'); ylabel('概率密度');
title('训练集光谱分布');
grid on;

subplot(2, 3, 2);
wav = linspace(400, 700, n_channels);
plot(wav, Y_train(1:5, :)', 'LineWidth', 1.5);
xlabel('波长 (nm)'); ylabel('反射率');
title('光谱示例');
grid on;

subplot(2, 3, 3);
t_plot = (0:min(200, N_points_ds)-1) / fs_ds * 1e6;
plot(t_plot, X_train(1:3, 1:length(t_plot))', 'LineWidth', 0.8);
xlabel('时间 (μs)'); ylabel('归一化幅值');
title('时域信号示例');
grid on;

subplot(2, 3, 4);
sample_signal = double(X_train(1, :));
Y_fft = abs(fft(sample_signal - mean(sample_signal)));
f_axis = (0:length(Y_fft)/2-1) * fs_ds / length(Y_fft) / 1e3;
plot(f_axis, Y_fft(1:length(f_axis)), 'b-');
hold on;
for k = 1:N_led
    xline(f_led(k)/1e3, 'r--', 'LineWidth', 0.5);
end
xlabel('频率 (kHz)'); ylabel('幅值');
title('FFT验证');
xlim([0, 500]);
grid on;

subplot(2, 3, 5);
bar([y_ideal_norm, y_extracted_norm]);
xlabel('LED'); ylabel('归一化幅值');
legend('理想', '提取');
title(sprintf('FFT幅值对比 (R=%.4f)', R));
grid on;

subplot(2, 3, 6);
stats_text = {
    sprintf('训练集: %d', size(Y_train, 1))
    sprintf('验证集: %d', size(Y_val, 1))
    sprintf('测试集: %d', size(Y_test, 1))
    ''
    sprintf('采样率: %.1f MHz', fs_ds/1e6)
    sprintf('采样点: %d', N_points_ds)
    sprintf('FFT分辨率: %.0f Hz', fft_resolution)
    sprintf('FFT相关: %.4f', R)
};
text(0.1, 0.5, stats_text, 'FontSize', 12, 'VerticalAlignment', 'middle');
axis off;
title('统计');

sgtitle('FDM E2E 数据集 (优化版)');
saveas(gcf, fullfile(save_dir, 'fdm_dataset_v2.png'));

%% ==================== 完成 ====================
fprintf('\n========== 完成 ==========\n');
fprintf('训练集: [%d × %d] -> [%d × %d]\n', size(X_train), size(Y_train));
fprintf('验证集: [%d × %d] -> [%d × %d]\n', size(X_val), size(Y_val));
fprintf('测试集: [%d × %d] -> [%d × %d]\n', size(X_test), size(Y_test));
fprintf('===========================\n');

%% ==================== 辅助函数 ====================

function X = generate_signals_fast(Y, A, modulation_matrix, snr_range, normalize_method, random_phase)
    [N_samples, ~] = size(Y);
    [N_points, N_led] = size(modulation_matrix);
    
    I_led = Y * A';
    X = zeros(N_samples, N_points, 'single');
    
    batch_size = 10000;
    n_batches = ceil(N_samples / batch_size);
    
    for b = 1:n_batches
        idx_start = (b-1) * batch_size + 1;
        idx_end = min(b * batch_size, N_samples);
        batch_idx = idx_start:idx_end;
        n_batch = length(batch_idx);
        
        I_batch = I_led(batch_idx, :);
        
        if random_phase
            signals_batch = zeros(n_batch, N_points, 'single');
            for i = 1:n_batch
                signal = zeros(1, N_points);
                for k = 1:N_led
                    shift = randi(N_points);
                    mod_shifted = circshift(modulation_matrix(:, k), shift);
                    signal = signal + I_batch(i, k) * mod_shifted';
                end
                signals_batch(i, :) = signal;
            end
        else
            signals_batch = single(I_batch * modulation_matrix');
        end
        
        for i = 1:n_batch
            signal = double(signals_batch(i, :));
            
            snr_db = snr_range(1) + (snr_range(2) - snr_range(1)) * rand();
            sig_power = mean(signal.^2);
            if sig_power > 0
                noise_power = sig_power / (10^(snr_db/10));
                noise = sqrt(noise_power) * randn(1, N_points);
                signal = signal + noise;
            end
            
            switch lower(normalize_method)
                case 'zscore'
                    sig_mean = mean(signal);
                    sig_std = std(signal);
                    if sig_std > 0
                        signal = (signal - sig_mean) / sig_std;
                    end
                case 'minmax'
                    sig_min = min(signal);
                    sig_max = max(signal);
                    if sig_max > sig_min
                        signal = (signal - sig_min) / (sig_max - sig_min);
                    end
            end
            
            signals_batch(i, :) = single(signal);
        end
        
        X(batch_idx, :) = signals_batch;
        
        if mod(b, 5) == 0 || b == n_batches
            fprintf('    批次 %d/%d 完成\n', b, n_batches);
        end
    end
end

function spectra_aug = augment_brightness(spectra, n_levels)
    n_orig = size(spectra, 1);
    n_channels = size(spectra, 2);
    spectra_aug = zeros(n_orig * n_levels, n_channels);
    
    for i = 1:n_orig
        spec = spectra(i, :);
        spec_max = max(spec) + 1e-6;
        
        for j = 1:n_levels
            if j == 1
                new_spec = spec;
            else
                aug_type = randi(4);
                switch aug_type
                    case 1, scale = 0.3 + 0.7 * rand(); new_spec = (spec / spec_max) * scale;
                    case 2, scale = 0.5 + 1.0 * rand(); new_spec = spec * scale;
                    case 3, new_spec = spec / spec_max;
                    case 4, offset = 0.1 + 0.3 * rand(); new_spec = spec / spec_max * (1 - offset) + offset;
                end
            end
            new_spec = max(min(new_spec, 1), 0);
            spectra_aug((i-1)*n_levels + j, :) = new_spec;
        end
    end
end

function cc_aug = augment_colorchecker(colorchecker, n_copies, n_channels)
    n_colors = size(colorchecker, 1);
    cc_aug = zeros(n_copies * n_colors, n_channels);
    
    for i = 1:n_copies
        for j = 1:n_colors
            noise = 0.02 * randn(1, n_channels);
            scale = 0.7 + 0.6 * rand();
            spec = colorchecker(j, :) * scale + noise;
            spec = max(min(spec, 1), 0);
            cc_aug((i-1)*n_colors + j, :) = spec;
        end
    end
end
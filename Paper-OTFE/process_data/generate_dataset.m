%% FDM 端到端数据集生成
% 12个LED，方波调制，300μs采样时间
% 输入：3000点降采样时域信号
% 输出：31维光谱

clear; clc; close all;

%% ==================== 配置参数 ====================
% LED频率配置（12个LED）
f_led = [30, 50, 70, 110, 130, 170, 190, 230, 290, 310, 370, 410] * 1e3;  % Hz
N_led = length(f_led);

% 采样参数
fs = 1e9;               % 1 GHz 采样率
T = 300e-6;             % 300 μs 采样时间
N_points = round(fs * T);  % 300,000 点

% 降采样参数
downsample_factor = 100;
fs_ds = fs / downsample_factor;  % 10 MHz
N_points_ds = N_points / downsample_factor;  % 3,000 点

% 噪声参数
snr_db_range = [30, 60];  % 信噪比范围 (dB)

% 数据路径
data_dir = 'W:\dataset\benchmark\merged_data\';
cave_file = 'CAVE_1D.mat';
kaist_file = 'KAIST_1D.mat';

% LED光谱矩阵路径（使用 load_mat）
% A0 = load_mat("led_0711", "gt")

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

% 随机种子
rng(42);

%% ==================== 加载LED光谱矩阵 ====================
fprintf('========== 加载数据 ==========\n');

% 加载 LED 光谱矩阵
A0 = load_mat("led_0711", "gt");
if size(A0, 1) == 31 && size(A0, 2) == 12
    A0 = A0';  % 转为 [12 × 31]
end

% 加载系统增益（从白板测量获得）
wfm_path = "./data/PD-01-04/";
k_A = read_rigol_wfm(wfm_path + "新建文件-1.wfm", fs, T);

% 系统矩阵 = 增益 × LED光谱
A = k_A .* A0;

n_channels = size(A, 2);  % 31

fprintf('LED光谱矩阵 A0: [%d × %d]\n', size(A0));
fprintf('系统增益 k_A: [%d × 1]\n', length(k_A));
fprintf('系统矩阵 A: [%d × %d]\n', size(A));
fprintf('LED数量: %d\n', N_led);
fprintf('光谱通道数: %d\n', n_channels);

%% ==================== 加载原始数据集 ====================
fprintf('\n[1/4] 加载CAVE数据集...\n');
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

% 确保是 [N × 31] 格式
if size(cave_spectra, 2) ~= n_channels && size(cave_spectra, 1) == n_channels
    cave_spectra = cave_spectra';
end
N_cave = size(cave_spectra, 1);
fprintf('  CAVE: [%d × %d], 均值: %.4f\n', size(cave_spectra), mean(cave_spectra(:)));
fprintf('  耗时: %.1f 秒\n', toc);

fprintf('\n[2/4] 加载KAIST数据集...\n');
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

% 确保是 [N × 31] 格式
if size(kaist_spectra, 2) ~= n_channels && size(kaist_spectra, 1) == n_channels
    kaist_spectra = kaist_spectra';
end
N_kaist = size(kaist_spectra, 1);
fprintf('  KAIST: [%d × %d], 均值: %.4f\n', size(kaist_spectra), mean(kaist_spectra(:)));
fprintf('  耗时: %.1f 秒\n', toc);

%% ==================== 加载 ColorChecker ====================
fprintf('\n[3/4] 加载ColorChecker...\n');
if include_colorchecker
    colorchecker = load_mat("colorchecker", "gt");
    if size(colorchecker, 1) == n_channels
        colorchecker = colorchecker';  % 转为 [24 × 31]
    end
    fprintf('  ColorChecker: [%d × %d], 均值: %.4f\n', size(colorchecker), mean(colorchecker(:)));
else
    fprintf('  跳过 ColorChecker\n');
end

%% ==================== 生成调制矩阵 ====================
fprintf('\n生成方波调制矩阵...\n');

t = (0:N_points-1) / fs;  % 时间轴 [1 × 300000]
modulation_matrix = zeros(N_led, N_points);
for k = 1:N_led
    % 方波调制：占空比 50%
    sq_wave = square(2 * pi * f_led(k) * t);
    modulation_matrix(k, :) = (sq_wave + 1) / 2;  % 归一化到 [0, 1]
end

% 降采样调制矩阵
modulation_matrix_ds = modulation_matrix(:, 1:downsample_factor:end);
fprintf('  原始调制矩阵: [%d × %d]\n', size(modulation_matrix));
fprintf('  降采样调制矩阵: [%d × %d]\n', size(modulation_matrix_ds));

%% ==================== 数据增强与采样 ====================
fprintf('\n[4/4] 数据增强与采样...\n');

% 从 CAVE 采样
n_cave_base = min(ceil(N_train_samples / n_brightness_levels), N_cave);
idx_cave = randperm(N_cave, n_cave_base);
cave_sampled = cave_spectra(idx_cave, :);
clear cave_spectra;
fprintf('  CAVE 基础采样: %d\n', size(cave_sampled, 1));

% 亮度增强
if brightness_augment
    fprintf('  亮度增强 (×%d)...\n', n_brightness_levels);
    cave_augmented = augment_brightness(cave_sampled, n_brightness_levels);
    fprintf('  增强后: %d 样本\n', size(cave_augmented, 1));
else
    cave_augmented = cave_sampled;
end

% ColorChecker 增强
if include_colorchecker
    fprintf('  ColorChecker 增强 (×%d)...\n', n_colorchecker_copies);
    cc_augmented = augment_colorchecker(colorchecker, n_colorchecker_copies, n_channels);
    fprintf('  ColorChecker 增强后: %d 样本\n', size(cc_augmented, 1));
    
    all_train_spectra = [cave_augmented; cc_augmented];
else
    all_train_spectra = cave_augmented;
end

% 从 KAIST 采样作为测试集
idx_kaist = randperm(N_kaist, min(N_test_samples, N_kaist));
test_spectra = kaist_spectra(idx_kaist, :);
clear kaist_spectra;

% 打乱训练数据
idx_shuffle = randperm(size(all_train_spectra, 1));
all_train_spectra = all_train_spectra(idx_shuffle, :);

% 划分训练集和验证集
n_train = min(N_train_samples, size(all_train_spectra, 1) - N_val_samples);
n_val = min(N_val_samples, size(all_train_spectra, 1) - n_train);

Y_train = all_train_spectra(1:n_train, :);
Y_val = all_train_spectra(n_train+1:n_train+n_val, :);
Y_test = test_spectra;

fprintf('\n  最终数据集:\n');
fprintf('    训练集: %d, 均值: %.4f\n', size(Y_train, 1), mean(Y_train(:)));
fprintf('    验证集: %d, 均值: %.4f\n', size(Y_val, 1), mean(Y_val(:)));
fprintf('    测试集: %d, 均值: %.4f\n', size(Y_test, 1), mean(Y_test(:)));

%% ==================== 数据预处理 ====================
fprintf('\n数据预处理...\n');

% 处理异常值，裁剪到 [0, 1]
Y_train = max(min(Y_train, 1), 0);
Y_val = max(min(Y_val, 1), 0);
Y_test = max(min(Y_test, 1), 0);

Y_train(isnan(Y_train)) = 0;
Y_val(isnan(Y_val)) = 0;
Y_test(isnan(Y_test)) = 0;

fprintf('  Y_train 范围: [%.4f, %.4f]\n', min(Y_train(:)), max(Y_train(:)));
fprintf('  Y_val 范围: [%.4f, %.4f]\n', min(Y_val(:)), max(Y_val(:)));
fprintf('  Y_test 范围: [%.4f, %.4f]\n', min(Y_test(:)), max(Y_test(:)));

%% ==================== 生成时域信号 ====================
fprintf('\n========== 生成时域信号 ==========\n');
fprintf('参数:\n');
fprintf('  采样率: %.0f MHz (降采样后)\n', fs_ds/1e6);
fprintf('  采样时间: %.0f μs\n', T*1e6);
fprintf('  采样点数: %d (降采样后)\n', N_points_ds);
fprintf('  SNR范围: [%d, %d] dB\n', snr_db_range(1), snr_db_range(2));
fprintf('================================\n');

% 预分配
X_train = zeros(size(Y_train, 1), N_points_ds, 'single');
X_val = zeros(size(Y_val, 1), N_points_ds, 'single');
X_test = zeros(size(Y_test, 1), N_points_ds, 'single');

% --- 训练集 ---
fprintf('\n生成训练集信号...\n');
tic;
parfor i = 1:size(Y_train, 1)
    x = Y_train(i, :)';  % [31 × 1]
    I_led = A * x;       % [12 × 1] LED 强度（包含系统增益）
    
    % 生成时域信号（方波调制）
    signal = I_led' * modulation_matrix_ds;  % [1 × 3000]
    
    % 添加噪声（随机 SNR）
    snr_db = snr_db_range(1) + (snr_db_range(2) - snr_db_range(1)) * rand();
    signal = add_noise(signal, snr_db);
    
    X_train(i, :) = signal;
end
fprintf('  耗时: %.1f 秒\n', toc);

% --- 验证集 ---
fprintf('生成验证集信号...\n');
tic;
parfor i = 1:size(Y_val, 1)
    x = Y_val(i, :)';
    I_led = A * x;
    signal = I_led' * modulation_matrix_ds;
    
    snr_db = snr_db_range(1) + (snr_db_range(2) - snr_db_range(1)) * rand();
    signal = add_noise(signal, snr_db);
    
    X_val(i, :) = signal;
end
fprintf('  耗时: %.1f 秒\n', toc);

% --- 测试集 ---
fprintf('生成测试集信号...\n');
tic;
parfor i = 1:size(Y_test, 1)
    x = Y_test(i, :)';
    I_led = A * x;
    signal = I_led' * modulation_matrix_ds;
    
    % 测试集使用固定中等 SNR
    snr_db = mean(snr_db_range);
    signal = add_noise(signal, snr_db);
    
    X_test(i, :) = signal;
end
fprintf('  耗时: %.1f 秒\n', toc);

%% ==================== 归一化 ====================
fprintf('\n时域信号归一化...\n');

X_max = max(abs(X_train(:)));
X_train = X_train / X_max;
X_val = X_val / X_max;
X_test = X_test / X_max;

fprintf('  归一化因子 X_max: %.6f\n', X_max);
fprintf('  X_train 范围: [%.4f, %.4f]\n', min(X_train(:)), max(X_train(:)));

% 转为 single
Y_train = single(Y_train);
Y_val = single(Y_val);
Y_test = single(Y_test);

%% ==================== 保存配置 ====================
config = struct();
config.f_led = f_led;
config.N_led = N_led;
config.fs = fs;
config.fs_ds = fs_ds;
config.T = T;
config.N_points = N_points;
config.N_points_ds = N_points_ds;
config.downsample_factor = downsample_factor;
config.snr_db_range = snr_db_range;
config.n_channels = n_channels;
config.X_max = X_max;
config.A0 = A0;
config.k_A = k_A;
config.A = A;
config.modulation_matrix_ds = modulation_matrix_ds;
config.brightness_augment = brightness_augment;
config.n_brightness_levels = n_brightness_levels;
config.include_colorchecker = include_colorchecker;
config.n_colorchecker_copies = n_colorchecker_copies;

%% ==================== 保存数据 ====================
fprintf('\n保存数据...\n');

if ~exist(save_dir, 'dir')
    mkdir(save_dir);
end

save_name = sprintf('fdm_e2e_%dled_%dus_%dpts.mat', N_led, T*1e6, N_points_ds);
save_path = fullfile(save_dir, save_name);

save(save_path, ...
     'X_train', 'Y_train', ...
     'X_val', 'Y_val', ...
     'X_test', 'Y_test', ...
     'config', '-v7.3');

fprintf('  已保存: %s\n', save_path);

% 文件大小
info = dir(save_path);
fprintf('  文件大小: %.1f MB\n', info.bytes/1e6);

%% ==================== 可视化验证 ====================
fprintf('\n生成可视化...\n');

figure('Position', [100, 100, 1600, 800]);

% 1. 光谱分布
subplot(2, 4, 1);
histogram(Y_train(:), 50, 'Normalization', 'pdf', 'FaceColor', [0.3, 0.6, 0.9]);
xlabel('反射率'); ylabel('概率密度');
title(sprintf('训练集光谱分布 (均值=%.3f)', mean(Y_train(:))));
grid on;

% 2. 样本均值分布
subplot(2, 4, 2);
train_means = mean(Y_train, 2);
histogram(train_means, 50, 'Normalization', 'pdf', 'FaceColor', [0.9, 0.6, 0.3]);
xlabel('样本均值'); ylabel('概率密度');
title('训练样本均值分布');
grid on;

% 3. 光谱示例
subplot(2, 4, 3);
wav = linspace(400, 700, n_channels);
[~, idx_sorted] = sort(train_means);
idx_show = idx_sorted(round(linspace(1, length(idx_sorted), 5)));
plot(wav, Y_train(idx_show, :)', 'LineWidth', 1.5);
xlabel('波长 (nm)'); ylabel('反射率');
title('训练集光谱示例');
legend(arrayfun(@(x) sprintf('mean=%.2f', x), train_means(idx_show), 'UniformOutput', false), 'Location', 'best');
grid on;

% 4. LED 光谱矩阵
subplot(2, 4, 4);
plot(wav, A0', 'LineWidth', 1.5);
xlabel('波长 (nm)'); ylabel('响应');
title(sprintf('LED 光谱矩阵 (%d LEDs)', N_led));
grid on;

% 5. 时域信号示例
subplot(2, 4, 5);
t_ds = (0:N_points_ds-1) / fs_ds * 1e6;
plot(t_ds, X_train(idx_show(1:3), :)', 'LineWidth', 0.8);
xlabel('时间 (μs)'); ylabel('归一化幅值');
title('时域信号示例');
xlim([0, 50]);
grid on;

% 6. FFT 验证
subplot(2, 4, 6);
sample_signal = X_train(1, :);
Y_fft = abs(fft(sample_signal));
f_axis = (0:N_points_ds-1) * fs_ds / N_points_ds / 1e3;  % kHz
plot(f_axis(1:N_points_ds/2), Y_fft(1:N_points_ds/2), 'b-', 'LineWidth', 1);
hold on;
for k = 1:N_led
    xline(f_led(k)/1e3, 'r--', 'LineWidth', 0.5);
end
xlabel('频率 (kHz)'); ylabel('幅值');
title('FFT 频谱验证');
xlim([0, 500]);
grid on;

% 7. 测试集光谱
subplot(2, 4, 7);
plot(wav, Y_test(1:5, :)', 'LineWidth', 1.5);
xlabel('波长 (nm)'); ylabel('反射率');
title('测试集光谱 (KAIST)');
grid on;

% 8. 数据统计
subplot(2, 4, 8);
stats_text = {
    sprintf('训练集: %d 样本', size(Y_train, 1))
    sprintf('验证集: %d 样本', size(Y_val, 1))
    sprintf('测试集: %d 样本', size(Y_test, 1))
    ''
    sprintf('输入维度: %d 点', N_points_ds)
    sprintf('输出维度: %d 通道', n_channels)
    sprintf('采样时间: %.0f μs', T*1e6)
    sprintf('采样率: %.0f MHz', fs_ds/1e6)
    ''
    sprintf('LED数量: %d', N_led)
    sprintf('调制: 方波')
};
text(0.1, 0.5, stats_text, 'FontSize', 11, 'VerticalAlignment', 'middle');
axis off;
title('数据集统计');

sgtitle(sprintf('FDM E2E 数据集: %d LED, %d μs, %d 点', N_led, T*1e6, N_points_ds));

saveas(gcf, fullfile(save_dir, 'fdm_e2e_dataset_visualization.png'));
fprintf('  已保存可视化图\n');

%% ==================== 完成 ====================
fprintf('\n========== 完成 ==========\n');
fprintf('数据文件: %s\n', save_name);
fprintf('  训练集: [%d × %d] -> [%d × %d]\n', size(X_train), size(Y_train));
fprintf('  验证集: [%d × %d] -> [%d × %d]\n', size(X_val), size(Y_val));
fprintf('  测试集: [%d × %d] -> [%d × %d]\n', size(X_test), size(Y_test));
fprintf('===========================\n');

%% ==================== 辅助函数 ====================

function spectra_aug = augment_brightness(spectra, n_levels)
% 亮度增强：生成不同亮度版本
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
                    case 1  % 归一化后随机缩放
                        scale = 0.3 + 0.7 * rand();
                        new_spec = (spec / spec_max) * scale;
                    case 2  % 直接随机缩放
                        scale = 0.5 + 1.0 * rand();
                        new_spec = spec * scale;
                    case 3  % 归一化到峰值=1
                        new_spec = spec / spec_max;
                    case 4  % 添加基线偏移
                        offset = 0.1 + 0.3 * rand();
                        new_spec = spec / spec_max * (1 - offset) + offset;
                end
            end
            new_spec = max(min(new_spec, 1), 0);
            spectra_aug((i-1)*n_levels + j, :) = new_spec;
        end
    end
end

function cc_aug = augment_colorchecker(colorchecker, n_copies, n_channels)
% ColorChecker 增强
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

function signal_noisy = add_noise(signal, snr_db)
% 添加高斯白噪声
    sig_power = mean(signal.^2);
    noise_power = sig_power / (10^(snr_db/10));
    noise = sqrt(noise_power) * randn(size(signal));
    signal_noisy = signal + noise;
end
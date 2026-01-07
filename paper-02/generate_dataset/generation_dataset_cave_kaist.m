%% FDM 端到端数据集生成 - 增强版
% 增加亮度多样性，覆盖更广的反射率范围
% 包含 ColorChecker 数据增强

clear; clc; close all;

%% ==================== 配置参数 ====================
% LED频率配置（12个LED）
f_led = [30, 50, 70, 110, 130, 170, 190, 230, 290, 310, 370, 410] * 1e3;  % Hz
N_led = length(f_led);

% 采样参数（与实际系统一致）
fs = 1e9;           % 1 GHz 采样率
T = 350e-6;         % 100 μs 采样时间
N_points = round(fs * T);  % 100,000 点

% 降采样到合理大小（神经网络输入）
downsample_factor = 100;
N_points_ds = N_points / downsample_factor;  % 1000 点

% 噪声参数
target_rel_error = 0.05;  % 5% 平均相对误差
noise_sigma = target_rel_error / sqrt(2/pi);

% 数据路径
data_dir = 'W:\dataset\benchmark\merged_data\';
cave_file = 'CAVE_1D.mat';
kaist_file = 'KAIST_1D.mat';
colorchecker_path = 'W:\Github\My-Repository\My-Graduation\paper-02\generate_dataset\colorchecker.mat';

% 采样数量
N_train_samples = 100000;
N_val_samples = 10000;
N_test_samples = 50000;

% 数据增强参数
brightness_augment = true;      % 是否进行亮度增强
n_brightness_levels = 5;        % 每个样本生成几个亮度版本
include_colorchecker = true;    % 是否包含 ColorChecker
n_colorchecker_copies = 2000;   % ColorChecker 复制份数

% 保存路径
save_dir = 'W:\Github\My-Repository\My-Graduation\paper-02\generate_dataset';

% 随机种子
rng(42);

%% ==================== 加载LED光谱矩阵 ====================
fprintf('========== 加载数据 ==========\n');

A0_full = load_mat("led_0711", "gt");
if size(A0_full, 1) == 31 && size(A0_full, 2) == 12
    A0_full = A0_full';
end

led_indices = 1:N_led;
A0 = A0_full(led_indices, :);
n_channels = size(A0, 2);

fprintf('A0: [%d × %d]\n', size(A0));

%% ==================== 加载原始数据集 ====================
fprintf('\n[1/5] 加载CAVE数据集...\n');
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
N_cave = size(cave_spectra, 1);
fprintf('  CAVE大小: %d × %d, 均值: %.4f\n', size(cave_spectra), mean(cave_spectra(:)));
fprintf('  加载耗时: %.1f 秒\n', toc);

fprintf('\n[2/5] 加载KAIST数据集...\n');
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
N_kaist = size(kaist_spectra, 1);
fprintf('  KAIST大小: %d × %d, 均值: %.4f\n', size(kaist_spectra), mean(kaist_spectra(:)));
fprintf('  加载耗时: %.1f 秒\n', toc);

%% ==================== 加载 ColorChecker ====================
if include_colorchecker && exist(colorchecker_path, 'file')
    fprintf('\n[3/5] 加载ColorChecker...\n');
    cc_data = load(colorchecker_path);
    fn = fieldnames(cc_data);
    for i = 1:length(fn)
        if numel(cc_data.(fn{i})) > 100
            colorchecker = double(cc_data.(fn{i}));
            break;
        end
    end
    if size(colorchecker, 1) == 31
        colorchecker = colorchecker';
    end
    fprintf('  ColorChecker大小: %d × %d, 均值: %.4f\n', size(colorchecker), mean(colorchecker(:)));
else
    include_colorchecker = false;
    fprintf('\n[3/5] 跳过ColorChecker (文件不存在)\n');
end

%% ==================== 数据增强函数 ====================
function spectra_aug = augment_spectra(spectra, n_levels, target_mean_range)
    % 对光谱进行亮度增强，生成不同亮度版本
    % target_mean_range: [min_mean, max_mean] 目标均值范围
    
    n_orig = size(spectra, 1);
    spectra_aug = zeros(n_orig * n_levels, size(spectra, 2));
    
    for i = 1:n_orig
        spec = spectra(i, :);
        spec_max = max(spec);
        
        for j = 1:n_levels
            if j == 1
                % 保留原始
                new_spec = spec;
            else
                % 随机选择增强方式
                aug_type = randi(4);
                
                switch aug_type
                    case 1
                        % 归一化到峰值=1，然后随机缩放
                        scale = 0.3 + 0.7 * rand();  % [0.3, 1.0]
                        new_spec = (spec / (spec_max + 1e-6)) * scale;
                        
                    case 2
                        % 直接随机缩放（保持相对形状）
                        scale = 0.5 + 1.5 * rand();  % [0.5, 2.0]
                        new_spec = spec * scale;
                        
                    case 3
                        % 归一化到峰值=1（高反射率）
                        new_spec = spec / (spec_max + 1e-6);
                        
                    case 4
                        % 添加基线偏移（模拟高反射率材料）
                        offset = 0.2 + 0.4 * rand();  % [0.2, 0.6]
                        new_spec = spec / (spec_max + 1e-6) * (1 - offset) + offset;
                end
            end
            
            % 裁剪到 [0, 1]
            new_spec = max(min(new_spec, 1), 0);
            spectra_aug((i-1)*n_levels + j, :) = new_spec;
        end
    end
end

%% ==================== 随机采样并增强 ====================
fprintf('\n[4/5] 随机采样与数据增强...\n');

% 从 CAVE 采样
n_cave_sample = min(N_train_samples / n_brightness_levels, N_cave);
idx_cave = randperm(N_cave, round(n_cave_sample));
cave_sampled = cave_spectra(idx_cave, :);
clear cave_spectra;

% 从 KAIST 采样（测试集，不增强）
idx_kaist = randperm(N_kaist, min(N_test_samples, N_kaist));
Y_test = kaist_spectra(idx_kaist, :);
clear kaist_spectra;

fprintf('  CAVE 采样: %d\n', size(cave_sampled, 1));
fprintf('  KAIST 采样: %d\n', size(Y_test, 1));

% 亮度增强
if brightness_augment
    fprintf('  进行亮度增强 (×%d)...\n', n_brightness_levels);
    cave_augmented = augment_spectra(cave_sampled, n_brightness_levels, [0.1, 0.8]);
    fprintf('  增强后: %d 样本, 均值: %.4f\n', size(cave_augmented, 1), mean(cave_augmented(:)));
else
    cave_augmented = cave_sampled;
end

% 添加 ColorChecker 增强数据
if include_colorchecker
    fprintf('  添加 ColorChecker 增强 (×%d)...\n', n_colorchecker_copies);
    
    cc_augmented = zeros(n_colorchecker_copies * size(colorchecker, 1), n_channels);
    for i = 1:n_colorchecker_copies
        for j = 1:size(colorchecker, 1)
            % 原始 + 随机噪声 + 随机缩放
            noise = 0.03 * randn(1, n_channels);
            scale = 0.7 + 0.6 * rand();  % [0.7, 1.3]
            
            spec = colorchecker(j, :) * scale + noise;
            spec = max(min(spec, 1), 0);
            
            cc_augmented((i-1)*size(colorchecker, 1) + j, :) = spec;
        end
    end
    
    fprintf('  ColorChecker 增强: %d 样本, 均值: %.4f\n', size(cc_augmented, 1), mean(cc_augmented(:)));
    
    % 合并
    all_train_spectra = [cave_augmented; cc_augmented];
else
    all_train_spectra = cave_augmented;
end

fprintf('  合并后总样本: %d\n', size(all_train_spectra, 1));

% 打乱顺序
idx_shuffle = randperm(size(all_train_spectra, 1));
all_train_spectra = all_train_spectra(idx_shuffle, :);

% 划分训练集和验证集
n_train = min(N_train_samples, size(all_train_spectra, 1) - N_val_samples);
n_val = min(N_val_samples, size(all_train_spectra, 1) - n_train);

Y_train = all_train_spectra(1:n_train, :);
Y_val = all_train_spectra(n_train+1:n_train+n_val, :);

fprintf('\n  最终数据集:\n');
fprintf('    训练集: %d, 均值: %.4f, 范围: [%.4f, %.4f]\n', size(Y_train, 1), mean(Y_train(:)), min(Y_train(:)), max(Y_train(:)));
fprintf('    验证集: %d, 均值: %.4f, 范围: [%.4f, %.4f]\n', size(Y_val, 1), mean(Y_val(:)), min(Y_val(:)), max(Y_val(:)));
fprintf('    测试集: %d, 均值: %.4f, 范围: [%.4f, %.4f]\n', size(Y_test, 1), mean(Y_test(:)), min(Y_test(:)), max(Y_test(:)));

%% ==================== 数据预处理 ====================
fprintf('\n数据预处理...\n');

% 处理异常值
Y_train(Y_train < 0) = 0; Y_train(isnan(Y_train)) = 0;
Y_val(Y_val < 0) = 0; Y_val(isnan(Y_val)) = 0;
Y_test(Y_test < 0) = 0; Y_test(isnan(Y_test)) = 0;

% 检查最大值
max_spectrum = max([max(Y_train(:)), max(Y_val(:)), max(Y_test(:))]);
fprintf('  光谱最大值: %.4f\n', max_spectrum);

% 如果超过1，进行裁剪
if max_spectrum > 1.0
    fprintf('  裁剪到 [0, 1]...\n');
    Y_train = min(Y_train, 1);
    Y_val = min(Y_val, 1);
    Y_test = min(Y_test, 1);
end

%% ==================== 生成调制矩阵 ====================
fprintf('\n生成调制矩阵...\n');

t = (0:N_points-1) / fs;
modulation_matrix = zeros(N_led, N_points);
for k = 1:N_led
    sq_wave = square(2 * pi * f_led(k) * t);
    modulation_matrix(k, :) = (sq_wave + 1) / 2;
end
modulation_matrix_ds = modulation_matrix(:, 1:downsample_factor:end);

fprintf('  调制矩阵: [%d × %d]\n', size(modulation_matrix_ds));

%% ==================== 显示参数 ====================
fprintf('\n========== 仿真参数 ==========\n');
fprintf('LED数量: %d\n', N_led);
fprintf('采样率: %.0f MHz (降采样后)\n', fs/downsample_factor/1e6);
fprintf('采样时间: %.0f μs\n', T*1e6);
fprintf('采样点数: %d\n', N_points_ds);
fprintf('频率分辨率: %.0f kHz\n', 1/T/1e3);
fprintf('目标平均相对误差: %.1f%%\n', target_rel_error * 100);
fprintf('亮度增强: %s (×%d)\n', string(brightness_augment), n_brightness_levels);
fprintf('ColorChecker: %s (×%d)\n', string(include_colorchecker), n_colorchecker_copies);
fprintf('==============================\n');

%% ==================== 生成时域信号 ====================
fprintf('\n[5/5] 生成时域信号...\n');

X_train = zeros(size(Y_train, 1), N_points_ds, 'single');
X_val = zeros(size(Y_val, 1), N_points_ds, 'single');
X_test = zeros(size(Y_test, 1), N_points_ds, 'single');

actual_errors_train = zeros(size(Y_train, 1), N_led);

% --- 训练集 ---
fprintf('  生成训练集...\n');
tic;
for i = 1:size(Y_train, 1)
    x = Y_train(i, :)';
    I_led = A0 * x;
    
    noise = noise_sigma * randn(N_led, 1);
    I_led_noisy = I_led .* (1 + noise);
    I_led_noisy = max(I_led_noisy, 0);
    
    actual_errors_train(i, :) = abs(I_led_noisy - I_led) ./ (I_led + eps) * 100;
    X_train(i, :) = I_led_noisy' * modulation_matrix_ds;
    
    if mod(i, 20000) == 0
        fprintf('    进度: %d / %d (%.1f%%)\n', i, size(Y_train, 1), i/size(Y_train, 1)*100);
    end
end
fprintf('    耗时: %.1f 秒\n', toc);

% --- 验证集 ---
fprintf('  生成验证集...\n');
tic;
for i = 1:size(Y_val, 1)
    x = Y_val(i, :)';
    I_led = A0 * x;
    
    noise = noise_sigma * randn(N_led, 1);
    I_led_noisy = I_led .* (1 + noise);
    I_led_noisy = max(I_led_noisy, 0);
    
    X_val(i, :) = I_led_noisy' * modulation_matrix_ds;
end
fprintf('    耗时: %.1f 秒\n', toc);

% --- 测试集 ---
fprintf('  生成测试集...\n');
tic;
actual_errors_test = zeros(size(Y_test, 1), N_led);
for i = 1:size(Y_test, 1)
    x = Y_test(i, :)';
    I_led = A0 * x;
    
    noise = noise_sigma * randn(N_led, 1);
    I_led_noisy = I_led .* (1 + noise);
    I_led_noisy = max(I_led_noisy, 0);
    
    actual_errors_test(i, :) = abs(I_led_noisy - I_led) ./ (I_led + eps) * 100;
    X_test(i, :) = I_led_noisy' * modulation_matrix_ds;
    
    if mod(i, 10000) == 0
        fprintf('    进度: %d / %d (%.1f%%)\n', i, size(Y_test, 1), i/size(Y_test, 1)*100);
    end
end
fprintf('    耗时: %.1f 秒\n', toc);

%% ==================== 归一化 ====================
fprintf('\n时域信号归一化...\n');

X_max = max(abs(X_train(:)));
X_train = X_train / X_max;
X_val = X_val / X_max;
X_test = X_test / X_max;

fprintf('  归一化因子: %.6f\n', X_max);

Y_train = single(Y_train);
Y_val = single(Y_val);
Y_test = single(Y_test);

%% ==================== 数据统计 ====================
fprintf('\n========== 数据统计 ==========\n');
fprintf('Y_train: 均值=%.4f, 范围=[%.4f, %.4f], size=[%d × %d]\n', mean(Y_train(:)), min(Y_train(:)), max(Y_train(:)), size(Y_train));
fprintf('Y_val:   均值=%.4f, 范围=[%.4f, %.4f], size=[%d × %d]\n', mean(Y_val(:)), min(Y_val(:)), max(Y_val(:)), size(Y_val));
fprintf('Y_test:  均值=%.4f, 范围=[%.4f, %.4f], size=[%d × %d]\n', mean(Y_test(:)), min(Y_test(:)), max(Y_test(:)), size(Y_test));
fprintf('训练集噪声: %.2f%%\n', mean(actual_errors_train(:)));
fprintf('==============================\n');

%% ==================== 保存配置 ====================
config = struct();
config.f_led = f_led;
config.fs = fs;
config.fs_ds = fs / downsample_factor;
config.T = T;
config.N_points = N_points;
config.N_points_ds = N_points_ds;
config.downsample_factor = downsample_factor;
config.target_rel_error = target_rel_error;
config.noise_sigma = noise_sigma;
config.actual_mean_error_train = mean(actual_errors_train(:));
config.actual_mean_error_test = mean(actual_errors_test(:));
config.n_channels = n_channels;
config.N_led = N_led;
config.X_max = X_max;
config.max_spectrum = max_spectrum;
config.A0 = A0;
config.led_indices = led_indices;
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

save_name = sprintf('fdm_e2e_cave%dk_kaist%dk_noise%.0fpct_aug.mat', ...
                    size(Y_train, 1)/1000, size(Y_test, 1)/1000, target_rel_error*100);
save_path = fullfile(save_dir, save_name);
save(save_path, ...
     'X_train', 'Y_train', ...
     'X_val', 'Y_val', ...
     'X_test', 'Y_test', ...
     'config', '-v7.3');
fprintf('  已保存: %s\n', save_path);

%% ==================== 可视化验证 ====================
fprintf('\n生成可视化...\n');

figure('Position', [100, 100, 1800, 900]);

% 1. 训练集光谱分布直方图
subplot(2, 4, 1);
histogram(Y_train(:), 50, 'Normalization', 'pdf', 'FaceColor', [0.3, 0.6, 0.9]);
hold on;
xline(mean(Y_train(:)), 'r-', 'LineWidth', 2);
xlabel('反射率');
ylabel('概率密度');
title(sprintf('训练集分布 (均值=%.3f)', mean(Y_train(:))));
legend('分布', '均值');
grid on;

% 2. 训练集 vs ColorChecker 分布对比
subplot(2, 4, 2);
hold on;
histogram(Y_train(:), 50, 'Normalization', 'pdf', 'FaceAlpha', 0.5, 'DisplayName', sprintf('Train (%.3f)', mean(Y_train(:))));
if include_colorchecker
    histogram(colorchecker(:), 30, 'Normalization', 'pdf', 'FaceAlpha', 0.5, 'DisplayName', sprintf('ColorChecker (%.3f)', mean(colorchecker(:))));
end
xlabel('反射率');
ylabel('概率密度');
title('训练集 vs ColorChecker');
legend;
grid on;

% 3. 训练集光谱示例（不同亮度）
subplot(2, 4, 3);
wav = linspace(400, 700, n_channels);
% 选择不同均值的样本
train_means = mean(Y_train, 2);
[~, idx_sorted] = sort(train_means);
idx_show = idx_sorted(round(linspace(1, length(idx_sorted), 6)));
plot(wav, Y_train(idx_show, :)', 'LineWidth', 1.5);
xlabel('波长 (nm)');
ylabel('反射率');
title('训练集光谱示例（不同亮度）');
legend(arrayfun(@(x) sprintf('mean=%.2f', x), train_means(idx_show), 'UniformOutput', false));
grid on;

% 4. 测试集光谱示例
subplot(2, 4, 4);
plot(wav, Y_test(1:5, :)', 'LineWidth', 1.5);
xlabel('波长 (nm)');
ylabel('反射率');
title('测试集光谱 (KAIST)');
grid on;

% 5. 时域信号示例
subplot(2, 4, 5);
t_ds = (0:N_points_ds-1) / (fs / downsample_factor) * 1e6;
plot(t_ds, X_train(idx_show(1:3), :)', 'LineWidth', 0.8);
xlabel('时间 (μs)');
ylabel('归一化幅值');
title('时域信号示例');
xlim([0, 30]);
grid on;

% 6. FFT 验证
subplot(2, 4, 6);
sample_signal = X_train(1, :);
Y_fft = abs(fft(sample_signal));
f_axis = (0:N_points_ds-1) * (fs / downsample_factor) / N_points_ds;
plot(f_axis/1e3, Y_fft, 'b-', 'LineWidth', 1);
hold on;
for k = 1:N_led
    xline(f_led(k)/1e3, 'r--', 'LineWidth', 0.5);
end
xlabel('频率 (kHz)');
ylabel('幅值');
title('FFT 频谱验证');
xlim([0, 500]);
grid on;

% 7. 每个样本的均值分布
subplot(2, 4, 7);
histogram(train_means, 50, 'Normalization', 'pdf', 'FaceColor', [0.9, 0.6, 0.3]);
xlabel('样本均值');
ylabel('概率密度');
title('训练样本均值分布');
grid on;

% 8. LED 光谱矩阵
subplot(2, 4, 8);
plot(wav, A0', 'LineWidth', 1.5);
xlabel('波长 (nm)');
ylabel('响应');
title(sprintf('LED 光谱矩阵 (%d LEDs)', N_led));
grid on;

sgtitle(sprintf('FDM E2E 增强数据集: Train %dk (均值%.3f) + Test %dk', ...
                size(Y_train, 1)/1000, mean(Y_train(:)), size(Y_test, 1)/1000));

saveas(gcf, fullfile(save_dir, 'fdm_e2e_dataset_aug_visualization.png'));
fprintf('  已保存: fdm_e2e_dataset_aug_visualization.png\n');

%% ==================== 完成 ====================
fprintf('\n========== 完成 ==========\n');
fprintf('数据文件: %s\n', save_name);
fprintf('训练集: %d 样本, 均值: %.4f\n', size(Y_train, 1), mean(Y_train(:)));
fprintf('验证集: %d 样本, 均值: %.4f\n', size(Y_val, 1), mean(Y_val(:)));
fprintf('测试集: %d 样本, 均值: %.4f\n', size(Y_test, 1), mean(Y_test(:)));
fprintf('ColorChecker 均值: %.4f (已包含在训练集)\n', mean(colorchecker(:)));
fprintf('===========================\n');
fprintf('\n下一步: python train_fdm_e2e.py\n');
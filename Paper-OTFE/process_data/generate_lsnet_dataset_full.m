%% 编码光谱重建数据集生成（全量CAVE版本）
% 输入: 6×1 测量向量 (y = A * x + noise)
% 输出: 31×1 光谱信号 (x)
% 训练集: 全部CAVE数据

clear; clc; close all;

%% ==================== 配置参数 ====================
% 数据路径
data_dir = 'W:\dataset\benchmark\merged_data\';
cave_file = 'CAVE_1D.mat';
kaist_file = 'KAIST_1D.mat';

% 验证和测试采样数量（训练集使用全部CAVE）
N_val_samples = 10000;
N_test_samples = 50000;

% 噪声参数
target_rel_error = 0;  % 相对误差 (0=无噪声, 0.05=5%, 0.1=10%)
noise_sigma = target_rel_error / sqrt(2/pi);

% ==================== 数据增强开关 ====================
AUGMENT_BRIGHTNESS = false;   % 亮度增强
AUGMENT_COLORCHECKER = false; % 加入ColorChecker

% 亮度增强参数
n_brightness_levels = 5;

% ColorChecker参数
n_colorchecker_copies = 10;

% 保存路径
save_dir = 'W:\Github\My-Repository\My-Graduation\paper-02\generate_dataset';

rng(42);

%% ==================== 加载测量矩阵 ====================
fprintf('========== 配置信息 ==========\n');
fprintf('训练集: 全量CAVE\n');
fprintf('噪声水平: %.0f%%\n', target_rel_error * 100);
fprintf('亮度增强: %s\n', mat2str(AUGMENT_BRIGHTNESS));
fprintf('ColorChecker增强: %s\n', mat2str(AUGMENT_COLORCHECKER));
fprintf('==============================\n\n');

fprintf('========== 加载测量矩阵 ==========\n');
A = load_mat("A_hybrid_0115", "gt");  % 6×31
[K, n_channels] = size(A);
fprintf('A: [%d × %d]\n', K, n_channels);

%% ==================== 加载数据集 ====================
fprintf('\n========== 加载数据集 ==========\n');

% CAVE（全部用于训练）
fprintf('加载CAVE...\n');
cave_data = load(fullfile(data_dir, cave_file));
fn = fieldnames(cave_data);
for i = 1:length(fn)
    if numel(cave_data.(fn{i})) > 1000
        cave_spectra = double(cave_data.(fn{i}));
        break;
    end
end
N_cave = size(cave_spectra, 1);
fprintf('  CAVE: %d × %d (全部用于训练)\n', size(cave_spectra));

% KAIST（用于测试）
fprintf('加载KAIST...\n');
kaist_data = load(fullfile(data_dir, kaist_file));
fn = fieldnames(kaist_data);
for i = 1:length(fn)
    if numel(kaist_data.(fn{i})) > 1000
        kaist_spectra = double(kaist_data.(fn{i}));
        break;
    end
end
N_kaist = size(kaist_spectra, 1);
fprintf('  KAIST: %d × %d\n', size(kaist_spectra));

% ColorChecker
if AUGMENT_COLORCHECKER
    fprintf('加载ColorChecker...\n');
    colorchecker_ref = load_mat("colorchecker_gt", "gt");      % 31×24 反射型
    colorchecker_trans = load_mat("colorchecker_trans", "gt"); % 31×24 透射型
    colorchecker = horzcat(colorchecker_ref, colorchecker_trans)';  % 48×31
    fprintf('  ColorChecker: %d × %d (24反射 + 24透射)\n', size(colorchecker));
end

%% ==================== 数据处理 ====================
fprintf('\n========== 数据处理 ==========\n');

% 全量CAVE（不采样）
cave_full = cave_spectra;
fprintf('CAVE全量: %d\n', size(cave_full, 1));
clear cave_spectra cave_data;

% KAIST采样作为测试集
idx_kaist = randperm(N_kaist, min(N_test_samples, N_kaist));
Y_test = kaist_spectra(idx_kaist, :);
clear kaist_spectra kaist_data;

% 亮度增强
if AUGMENT_BRIGHTNESS
    cave_processed = augment_spectra(cave_full, n_brightness_levels);
    fprintf('亮度增强: %d → %d\n', size(cave_full, 1), size(cave_processed, 1));
else
    cave_processed = cave_full;
    fprintf('亮度增强: 禁用\n');
end

% ColorChecker增强
if AUGMENT_COLORCHECKER
    cc_augmented = zeros(n_colorchecker_copies * size(colorchecker, 1), n_channels);
    for i = 1:n_colorchecker_copies
        for j = 1:size(colorchecker, 1)
            spec = colorchecker(j, :) * (0.7 + 0.6*rand()) + 0.03*randn(1, n_channels);
            cc_augmented((i-1)*size(colorchecker, 1) + j, :) = max(min(spec, 1), 0);
        end
    end
    fprintf('ColorChecker: 48 × %d = %d\n', n_colorchecker_copies, size(cc_augmented, 1));
    all_train_spectra = [cave_processed; cc_augmented];
else
    all_train_spectra = cave_processed;
    fprintf('ColorChecker: 禁用\n');
end

% 打乱
idx_shuffle = randperm(size(all_train_spectra, 1));
all_train_spectra = all_train_spectra(idx_shuffle, :);

% 划分训练集和验证集
n_total = size(all_train_spectra, 1);
n_val = min(N_val_samples, floor(n_total * 0.1));  % 验证集最多10%
n_train = n_total - n_val;

Y_train = all_train_spectra(1:n_train, :);
Y_val = all_train_spectra(n_train+1:end, :);

% 预处理
Y_train = max(min(Y_train, 1), 0);
Y_val = max(min(Y_val, 1), 0);
Y_test = max(min(Y_test, 1), 0);

fprintf('\n训练集: %d, 验证集: %d, 测试集: %d\n', size(Y_train,1), size(Y_val,1), size(Y_test,1));
fprintf('总计: %d\n', size(Y_train,1) + size(Y_val,1));

%% ==================== 生成测量向量 ====================
fprintf('\n========== 生成测量向量 ==========\n');

% 训练集
X_train = (Y_train * A') .* (1 + noise_sigma * randn(size(Y_train, 1), K));
X_train = single(max(X_train, 0));

% 验证集
X_val = (Y_val * A') .* (1 + noise_sigma * randn(size(Y_val, 1), K));
X_val = single(max(X_val, 0));

% 测试集
X_test = (Y_test * A') .* (1 + noise_sigma * randn(size(Y_test, 1), K));
X_test = single(max(X_test, 0));

% 归一化
X_max = max(X_train(:));
X_train = X_train / X_max;
X_val = X_val / X_max;
X_test = X_test / X_max;

Y_train = single(Y_train);
Y_val = single(Y_val);
Y_test = single(Y_test);

fprintf('X: [N × %d], Y: [N × %d]\n', K, n_channels);
fprintf('X_max = %.4f\n', X_max);

%% ==================== 保存 ====================
fprintf('\n========== 保存 ==========\n');

config = struct(...
    'A', A, ...
    'K', K, ...
    'n_channels', n_channels, ...
    'noise_sigma', noise_sigma, ...
    'X_max', X_max, ...
    'target_rel_error', target_rel_error, ...
    'augment_brightness', AUGMENT_BRIGHTNESS, ...
    'augment_colorchecker', AUGMENT_COLORCHECKER, ...
    'full_cave', true);

if ~exist(save_dir, 'dir'), mkdir(save_dir); end

% 文件名标记full表示全量
save_name = sprintf('spectral_%din_%dout_train%.0fk_noise%d_full.mat', ...
    K, n_channels, size(Y_train,1)/1000, round(target_rel_error*100));
save(fullfile(save_dir, save_name), 'X_train', 'Y_train', 'X_val', 'Y_val', ...
     'X_test', 'Y_test', 'config', '-v7.3');
fprintf('已保存: %s\n', save_name);

%% ==================== 可视化 ====================
figure('Position', [100, 100, 1200, 400]);

subplot(1,3,1);
wav = linspace(400, 700, n_channels);
plot(wav, A', 'LineWidth', 1.5);
xlabel('波长 (nm)'); ylabel('响应');
title(sprintf('测量矩阵 A [%d×%d]', K, n_channels));
grid on;

subplot(1,3,2);
idx = randperm(size(Y_train,1), 5);
plot(wav, Y_train(idx,:)', 'LineWidth', 1.5);
xlabel('波长 (nm)'); ylabel('反射率');
title('光谱示例'); grid on;

subplot(1,3,3);
bar(X_train(idx,:)');
xlabel('测量编号'); ylabel('归一化值');
title('测量值示例'); grid on;

saveas(gcf, fullfile(save_dir, 'dataset_visualization_full.png'));

%% ==================== 汇总 ====================
fprintf('\n========== 完成 ==========\n');
fprintf('模式: 全量CAVE训练\n');
fprintf('输入: %d×1, 输出: %d×1\n', K, n_channels);
fprintf('训练集: %d (全量)\n', size(Y_train, 1));
fprintf('验证集: %d\n', size(Y_val, 1));
fprintf('测试集: %d\n', size(Y_test, 1));
fprintf('噪声: %.0f%%\n', target_rel_error * 100);
fprintf('文件: %s\n', save_name);
fprintf('============================\n');

%% ==================== 辅助函数 ====================
function spectra_aug = augment_spectra(spectra, n_levels)
    [n_orig, n_ch] = size(spectra);
    spectra_aug = zeros(n_orig * n_levels, n_ch);
    
    for i = 1:n_orig
        spec = spectra(i, :);
        spec_max = max(spec) + 1e-6;
        
        for j = 1:n_levels
            if j == 1
                new_spec = spec;
            else
                switch randi(4)
                    case 1, new_spec = (spec / spec_max) * (0.3 + 0.7*rand());
                    case 2, new_spec = spec * (0.5 + 1.5*rand());
                    case 3, new_spec = spec / spec_max;
                    case 4, offset = 0.2 + 0.4*rand(); 
                            new_spec = spec/spec_max*(1-offset) + offset;
                end
            end
            spectra_aug((i-1)*n_levels + j, :) = max(min(new_spec, 1), 0);
        end
    end
end
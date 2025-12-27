%% FDM Spectroscopy Simulation - CAVE训练 + KAIST测试
% 使用CAVE_1D作为训练/验证集，KAIST_1D作为测试集
% 实现跨数据集泛化测试

clear; clc;
A = load_mat("led_0711", "gt");
data_path = 'W:\dataset\benchmark\pixel_data_clustered\pixels_all.mat';
data = load(data_path);
x = data.spectra;

%% ===================== 参数设置 =====================
% --- 数据路径 ---
data_dir = 'W:\dataset\benchmark\merged_data\';
cave_file = 'CAVE_1D.mat';    % 训练+验证
kaist_file = 'KAIST_1D.mat';  % 测试

% --- 采样参数 ---
N_train_samples = 100000;   % 训练样本数 (从CAVE采样)
N_val_samples = 10000;      % 验证样本数 (从CAVE采样)
N_test_samples = 50000;     % 测试样本数 (从KAIST采样)

% --- 时域采样参数 ---
fs = 1e6;           % 采样率: 1 MHz
T = 1e-3;           % 采样时间: 1 ms
N_points = fs * T;  % 采样点数: 1000

% --- 调制频率参数 ---
N_led = 12;         % LED数量
f_start = 100e3;    % 起始频率: 100 kHz
f_step = 10e3;      % 频率间隔: 10 kHz
f_carriers = f_start + (0:N_led-1) * f_step;

% --- 时间向量 ---
t = (0:N_points-1) / fs;

%% ===================== 检查LED矩阵A =====================
if ~exist('A', 'var')
    error(['请先加载LED光谱矩阵A到workspace中！\n' ...
           'A应为 31×12 的矩阵']);
end
assert(size(A,1) == 31 && size(A,2) == 12, 'A的维度应为31×12');
fprintf('LED光谱矩阵A: %d × %d ✓\n', size(A));

%% ===================== 生成调制波形矩阵 =====================
fprintf('\n生成调制波形...\n');
modulation_matrix = zeros(N_led, N_points);
for k = 1:N_led
    sq_wave = square(2 * pi * f_carriers(k) * t);
    modulation_matrix(k, :) = (sq_wave + 1) / 2;
end
fprintf('调制矩阵: %d × %d ✓\n', size(modulation_matrix));

%% ===================== 显示参数 =====================
fprintf('\n========== 仿真参数 ==========\n');
fprintf('采样率: %d kHz\n', fs/1e3);
fprintf('采样时间: %.1f ms\n', T*1e3);
fprintf('采样点数: %d\n', N_points);
fprintf('载波频率: %d - %d kHz (间隔 %d kHz)\n', ...
    f_carriers(1)/1e3, f_carriers(end)/1e3, f_step/1e3);
fprintf('训练样本: %d\n', N_train_samples);
fprintf('验证样本: %d\n', N_val_samples);
fprintf('测试样本: %d\n', N_test_samples);
fprintf('==============================\n');

%% ===================== 加载CAVE数据集 =====================
fprintf('\n[1/4] 加载CAVE数据集...\n');
tic;

cave_path = fullfile(data_dir, cave_file);
if endsWith(cave_file, '.mat')
    cave_data = load(cave_path);
    fn = fieldnames(cave_data);
    for i = 1:length(fn)
        if numel(cave_data.(fn{i})) > 1000
            cave_spectra = double(cave_data.(fn{i}));
            break;
        end
    end
    clear cave_data;
else
    cave_spectra = double(readNPY(cave_path));
end

N_cave = size(cave_spectra, 1);
fprintf('  CAVE大小: %d × %d\n', size(cave_spectra));
fprintf('  加载耗时: %.1f 秒\n', toc);

%% ===================== 加载KAIST数据集 =====================
fprintf('\n[2/4] 加载KAIST数据集...\n');
tic;

kaist_path = fullfile(data_dir, kaist_file);
if endsWith(kaist_file, '.mat')
    kaist_data = load(kaist_path);
    fn = fieldnames(kaist_data);
    for i = 1:length(fn)
        if numel(kaist_data.(fn{i})) > 1000
            kaist_spectra = double(kaist_data.(fn{i}));
            break;
        end
    end
    clear kaist_data;
else
    kaist_spectra = double(readNPY(kaist_path));
end

N_kaist = size(kaist_spectra, 1);
fprintf('  KAIST大小: %d × %d\n', size(kaist_spectra));
fprintf('  加载耗时: %.1f 秒\n', toc);

%% ===================== 随机采样 =====================
fprintf('\n[3/4] 随机采样...\n');
rng(42);  % 固定随机种子

% 从CAVE采样训练+验证
idx_cave = randperm(N_cave, N_train_samples + N_val_samples);
idx_train = idx_cave(1:N_train_samples);
idx_val = idx_cave(N_train_samples+1:end);

Y_train = cave_spectra(idx_train, :);
Y_val = cave_spectra(idx_val, :);
clear cave_spectra;  % 释放内存

% 从KAIST采样测试
idx_test = randperm(N_kaist, N_test_samples);
Y_test = kaist_spectra(idx_test, :);
clear kaist_spectra;

fprintf('  训练集: %d 样本 (from CAVE)\n', size(Y_train, 1));
fprintf('  验证集: %d 样本 (from CAVE)\n', size(Y_val, 1));
fprintf('  测试集: %d 样本 (from KAIST)\n', size(Y_test, 1));

%% ===================== 数据预处理 =====================
fprintf('\n数据预处理...\n');

% 处理异常值
Y_train(Y_train < 0) = 0; Y_train(isnan(Y_train)) = 0;
Y_val(Y_val < 0) = 0; Y_val(isnan(Y_val)) = 0;
Y_test(Y_test < 0) = 0; Y_test(isnan(Y_test)) = 0;

% 检查是否需要归一化
max_all = max([max(Y_train(:)), max(Y_val(:)), max(Y_test(:))]);
fprintf('  光谱最大值: %.4f\n', max_all);

if max_all > 1.5
    fprintf('  归一化到[0,1]...\n');
    Y_train = Y_train / max_all;
    Y_val = Y_val / max_all;
    Y_test = Y_test / max_all;
end

%% ===================== 生成时域信号 =====================
fprintf('\n[4/4] 生成时域信号...\n');

% --- 训练集 ---
fprintf('  生成训练集时域信号...\n');
tic;
I_train = (A' * Y_train')';  % (N, 12)
X_train = single(I_train * modulation_matrix);  % (N, 1000)
fprintf('    耗时: %.1f 秒\n', toc);

% --- 验证集 ---
fprintf('  生成验证集时域信号...\n');
tic;
I_val = (A' * Y_val')';
X_val = single(I_val * modulation_matrix);
fprintf('    耗时: %.1f 秒\n', toc);

% --- 测试集 ---
fprintf('  生成测试集时域信号...\n');
tic;
I_test = (A' * Y_test')';
X_test = single(I_test * modulation_matrix);
fprintf('    耗时: %.1f 秒\n', toc);

%% ===================== 时域信号归一化 =====================
fprintf('\n时域信号归一化...\n');

% 使用训练集的统计量进行归一化（避免数据泄露）
max_signal = max(abs(X_train(:)));
X_train = X_train / max_signal;
X_val = X_val / max_signal;
X_test = X_test / max_signal;

fprintf('  归一化因子: %.6f\n', max_signal);

% 转换Y为single
Y_train = single(Y_train);
Y_val = single(Y_val);
Y_test = single(Y_test);

%% ===================== 数据统计 =====================
fprintf('\n========== 数据统计 ==========\n');
fprintf('X_train: [%.4f, %.4f], mean=%.4f\n', min(X_train(:)), max(X_train(:)), mean(X_train(:)));
fprintf('Y_train: [%.4f, %.4f], mean=%.4f\n', min(Y_train(:)), max(Y_train(:)), mean(Y_train(:)));
fprintf('X_val:   [%.4f, %.4f], mean=%.4f\n', min(X_val(:)), max(X_val(:)), mean(X_val(:)));
fprintf('Y_val:   [%.4f, %.4f], mean=%.4f\n', min(Y_val(:)), max(Y_val(:)), mean(Y_val(:)));
fprintf('X_test:  [%.4f, %.4f], mean=%.4f\n', min(X_test(:)), max(X_test(:)), mean(X_test(:)));
fprintf('Y_test:  [%.4f, %.4f], mean=%.4f\n', min(Y_test(:)), max(Y_test(:)), mean(Y_test(:)));
fprintf('==============================\n');

%% ===================== 保存数据 =====================
fprintf('\n保存数据...\n');

% 保存为.mat格式
save_name = sprintf('fdm_cave%dk_kaist%dk.mat', N_train_samples/1000, N_test_samples/1000);
save(save_name, 'X_train', 'Y_train', 'X_val', 'Y_val', 'X_test', 'Y_test', ...
     'f_carriers', 'fs', 'T', 'A', 'max_signal', 'modulation_matrix', '-v7.3');
fprintf('  已保存: %s\n', save_name);

% 保存为NPY格式（可选）
try
    npy_dir = 'fdm_npy';
    if ~exist(npy_dir, 'dir'), mkdir(npy_dir); end
    
    writeNPY(X_train, fullfile(npy_dir, 'X_train.npy'));
    writeNPY(Y_train, fullfile(npy_dir, 'Y_train.npy'));
    writeNPY(X_val, fullfile(npy_dir, 'X_val.npy'));
    writeNPY(Y_val, fullfile(npy_dir, 'Y_val.npy'));
    writeNPY(X_test, fullfile(npy_dir, 'X_test.npy'));
    writeNPY(Y_test, fullfile(npy_dir, 'Y_test.npy'));
    writeNPY(single(A), fullfile(npy_dir, 'A.npy'));
    
    fprintf('  已保存NPY到: %s/\n', npy_dir);
catch
    warning('NPY保存失败，请安装npy-matlab或使用.mat文件');
end

%% ===================== 可视化验证 =====================
fprintf('\n生成可视化...\n');

figure('Position', [100, 100, 1400, 900]);

% 1. 训练集光谱示例
subplot(2,3,1);
plot(1:31, Y_train(1:5, :)', 'LineWidth', 1.5);
xlabel('Wavelength Channel'); ylabel('Intensity');
title('Training Spectra (CAVE)');
legend('1','2','3','4','5'); grid on;

% 2. 测试集光谱示例
subplot(2,3,2);
plot(1:31, Y_test(1:5, :)', 'LineWidth', 1.5);
xlabel('Wavelength Channel'); ylabel('Intensity');
title('Test Spectra (KAIST)');
legend('1','2','3','4','5'); grid on;

% 3. 时域信号示例
subplot(2,3,3);
plot(t*1e3, X_train(1, :), 'LineWidth', 1);
xlabel('Time (ms)'); ylabel('Normalized Amplitude');
title('Time-domain Signal Example');
xlim([0, 0.1]); grid on;

% 4. FFT验证
subplot(2,3,4);
Y_fft = abs(fft(X_train(1, :)));
f_axis = (0:N_points-1) * fs / N_points;
plot(f_axis/1e3, Y_fft, 'LineWidth', 1);
hold on;
for k = 1:N_led
    xline(f_carriers(k)/1e3, 'r--', 'LineWidth', 0.5);
end
xlabel('Frequency (kHz)'); ylabel('Amplitude');
title('FFT Spectrum (verify carriers)');
xlim([50, 250]); grid on;

% 5. LED光谱矩阵
subplot(2,3,5);
plot(1:31, A, 'LineWidth', 1.5);
xlabel('Wavelength Channel'); ylabel('Response');
title('LED Spectra Matrix A');
grid on;

% 6. 训练/测试光谱分布对比
subplot(2,3,6);
hold on;
histogram(Y_train(:), 50, 'Normalization', 'pdf', 'FaceAlpha', 0.5, 'DisplayName', 'CAVE (Train)');
histogram(Y_test(:), 50, 'Normalization', 'pdf', 'FaceAlpha', 0.5, 'DisplayName', 'KAIST (Test)');
xlabel('Intensity'); ylabel('PDF');
title('Spectral Distribution Comparison');
legend; grid on;

sgtitle(sprintf('FDM Dataset: CAVE %dk train + KAIST %dk test', N_train_samples/1000, N_test_samples/1000));
saveas(gcf, 'fdm_dataset_visualization.png');
fprintf('  已保存: fdm_dataset_visualization.png\n');

%% ===================== 完成 =====================
fprintf('\n========== 完成 ==========\n');
fprintf('数据文件: %s\n', save_name);
fprintf('训练集: %d × %d (X), %d × %d (Y)\n', size(X_train), size(Y_train));
fprintf('验证集: %d × %d (X), %d × %d (Y)\n', size(X_val), size(Y_val));
fprintf('测试集: %d × %d (X), %d × %d (Y)\n', size(X_test), size(Y_test));
fprintf('===========================\n');
fprintf('\n下一步: python train_fdm_net.py --data_path %s\n', save_name);
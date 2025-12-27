%% FDM 端到端数据集生成
% 输入: 时域信号 X [N_samples × N_points]
% 输出: 光谱 Y [N_samples × 31]
% 包含 5% 平均相对误差模拟实际测量噪声

clear; clc; close all;

%% ==================== 配置参数 ====================
% LED频率配置
f_led = [30, 50, 70, 110, 130, 170, 190, 230, 290, 310, 370] * 1e3;  % Hz
N_led = length(f_led);

% 采样参数（与实际系统一致）
fs = 1e9;           % 1 GHz 采样率（示波器实际能力）
T = 100e-6;         % 100 μs 采样时间
N_points = round(fs * T);  % 100,000 点

% 降采样到合理大小（神经网络输入）
downsample_factor = 100;  % 降采样因子
N_points_ds = N_points / downsample_factor;  % 1000 点

% 噪声参数（精确控制平均相对误差）
target_rel_error = 0.05;  % 目标：5% 平均相对误差
noise_sigma = target_rel_error / sqrt(2/pi);  % ≈ 6.27%

% 数据集划分
train_ratio = 0.8;
val_ratio = 0.1;
test_ratio = 0.1;

% 随机种子
rng(42);

%% ==================== 加载数据 ====================
fprintf('========== 加载数据 ==========\n');

% LED光谱矩阵
A0_full = load_mat("led_0711", "gt");
if size(A0_full, 1) == 31 && size(A0_full, 2) == 12
    A0_full = A0_full';  % 转为 [12 × 31]
end

% 选择使用的LED
led_indices = 1:N_led;
A0 = A0_full(led_indices, :);  % [N_led × 31]
n_channels = size(A0, 2);

fprintf('A0: [%d × %d]\n', size(A0));

% 加载光谱数据
data_path = 'W:\dataset\benchmark\pixel_data_clustered\pixels_all.mat';
data = load(data_path);
spectra = data.spectra;  % [N × 31]

% 归一化光谱到 [0, 1]
spectra = spectra ./ max(spectra, [], 2);
spectra(isnan(spectra)) = 0;

N_samples = size(spectra, 1);
fprintf('光谱数据: [%d × %d]\n', size(spectra));

%% ==================== 生成时间轴和调制矩阵 ====================
fprintf('\n========== 生成调制矩阵 ==========\n');

t = (0:N_points-1) / fs;

% 生成方波调制矩阵 [N_led × N_points]
modulation_matrix = zeros(N_led, N_points);
for k = 1:N_led
    sq_wave = square(2 * pi * f_led(k) * t);
    modulation_matrix(k, :) = (sq_wave + 1) / 2;  % 0/1 方波
end

% 降采样调制矩阵
modulation_matrix_ds = modulation_matrix(:, 1:downsample_factor:end);  % [N_led × N_points_ds]

fprintf('原始调制矩阵: [%d × %d]\n', size(modulation_matrix));
fprintf('降采样调制矩阵: [%d × %d]\n', size(modulation_matrix_ds));

%% ==================== 生成仿真数据 ====================
fprintf('\n========== 生成仿真数据 ==========\n');
fprintf('样本数: %d\n', N_samples);
fprintf('目标平均相对误差: %.1f%%\n', target_rel_error * 100);
fprintf('噪声标准差 σ: %.2f%%\n', noise_sigma * 100);

% 预分配
X_signals = zeros(N_samples, N_points_ds);
Y_spectra = spectra;

% 记录实际误差用于验证
actual_errors = zeros(N_samples, N_led);

tic;
for i = 1:N_samples
    % 1. 获取光谱 [1 × 31]
    x = spectra(i, :)';
    
    % 2. 计算理论 LED 响应 [N_led × 1]
    I_led = A0 * x;
    
    % 3. 添加噪声（精确控制平均相对误差为 5%）
    noise = noise_sigma * randn(N_led, 1);
    I_led_noisy = I_led .* (1 + noise);
    I_led_noisy = max(I_led_noisy, 0);  % 确保非负
    
    % 记录实际相对误差
    actual_errors(i, :) = abs(I_led_noisy - I_led) ./ I_led * 100;
    
    % 4. 生成时域信号（使用降采样调制矩阵）
    time_signal = I_led_noisy' * modulation_matrix_ds;  % [1 × N_points_ds]
    
    % 5. 存储
    X_signals(i, :) = time_signal;
    
    % 进度显示
    if mod(i, 2000) == 0
        fprintf('  进度: %d / %d (%.1f%%)\n', i, N_samples, i/N_samples*100);
    end
end
elapsed = toc;

fprintf('数据生成完成! 耗时: %.2f 秒\n', elapsed);
fprintf('时域信号: [%d × %d]\n', size(X_signals));

% 验证噪声水平
fprintf('\n========== 噪声验证 ==========\n');
fprintf('实际平均相对误差: %.2f%% (目标: %.1f%%)\n', mean(actual_errors(:)), target_rel_error * 100);
fprintf('相对误差标准差: %.2f%%\n', std(actual_errors(:)));
fprintf('最大相对误差: %.2f%%\n', max(actual_errors(:)));

%% ==================== 归一化 ====================
fprintf('\n========== 归一化 ==========\n');

% 全局归一化时域信号
X_max = max(abs(X_signals(:)));
X_signals_norm = X_signals / X_max;

fprintf('时域信号范围: [%.4f, %.4f] → [%.4f, %.4f]\n', ...
        min(X_signals(:)), max(X_signals(:)), ...
        min(X_signals_norm(:)), max(X_signals_norm(:)));

%% ==================== 划分数据集 ====================
fprintf('\n========== 划分数据集 ==========\n');

idx = randperm(N_samples);

n_train = round(N_samples * train_ratio);
n_val = round(N_samples * val_ratio);

idx_train = idx(1:n_train);
idx_val = idx(n_train+1 : n_train+n_val);
idx_test = idx(n_train+n_val+1 : end);

% 训练集
X_train = X_signals_norm(idx_train, :);
Y_train = Y_spectra(idx_train, :);

% 验证集
X_val = X_signals_norm(idx_val, :);
Y_val = Y_spectra(idx_val, :);

% 测试集
X_test = X_signals_norm(idx_test, :);
Y_test = Y_spectra(idx_test, :);

fprintf('训练集: %d 样本\n', size(X_train, 1));
fprintf('验证集: %d 样本\n', size(X_val, 1));
fprintf('测试集: %d 样本\n', size(X_test, 1));

%% ==================== 保存数据集 ====================
fprintf('\n========== 保存数据集 ==========\n');

% 保存配置信息
config = struct();
config.f_led = f_led;
config.fs = fs;
config.T = T;
config.N_points = N_points;
config.N_points_ds = N_points_ds;
config.downsample_factor = downsample_factor;
config.target_rel_error = target_rel_error;
config.noise_sigma = noise_sigma;
config.actual_mean_error = mean(actual_errors(:));
config.n_channels = n_channels;
config.N_led = N_led;
config.X_max = X_max;
config.A0 = A0;
config.led_indices = led_indices;

% 保存 MAT 文件
save_path = 'fdm_e2e_dataset_5pct_noise.mat';
save(save_path, ...
     'X_train', 'Y_train', ...
     'X_val', 'Y_val', ...
     'X_test', 'Y_test', ...
     'config', '-v7.3');
fprintf('已保存: %s\n', save_path);

% 保存 NPY 文件（用于 Python）
try
    npy_dir = 'fdm_e2e_dataset_npy';
    if ~exist(npy_dir, 'dir')
        mkdir(npy_dir);
    end
    
    writeNPY(single(X_train), fullfile(npy_dir, 'X_train.npy'));
    writeNPY(single(Y_train), fullfile(npy_dir, 'Y_train.npy'));
    writeNPY(single(X_val), fullfile(npy_dir, 'X_val.npy'));
    writeNPY(single(Y_val), fullfile(npy_dir, 'Y_val.npy'));
    writeNPY(single(X_test), fullfile(npy_dir, 'X_test.npy'));
    writeNPY(single(Y_test), fullfile(npy_dir, 'Y_test.npy'));
    writeNPY(single(f_led), fullfile(npy_dir, 'f_led.npy'));
    writeNPY(single(A0), fullfile(npy_dir, 'A0.npy'));
    
    fprintf('已保存 NPY 文件到: %s/\n', npy_dir);
catch ME
    warning('NPY 保存失败: %s', ME.message);
end

%% ==================== 可视化验证 ====================
fprintf('\n========== 可视化验证 ==========\n');

figure('Position', [100, 100, 1400, 800]);

% 1. 时域信号示例
subplot(2, 3, 1);
t_ds = (0:N_points_ds-1) / (fs / downsample_factor) * 1e6;
plot(t_ds, X_train(1:5, :)', 'LineWidth', 0.5);
xlabel('时间 (μs)');
ylabel('归一化幅值');
title('时域信号示例 (5个样本)');
xlim([0, 20]);
grid on;
legend('样本1', '样本2', '样本3', '样本4', '样本5', 'Location', 'best');

% 2. 对应光谱
subplot(2, 3, 2);
wav = linspace(400, 700, n_channels);
plot(wav, Y_train(1:5, :)', 'LineWidth', 1.5);
xlabel('波长 (nm)');
ylabel('反射率');
title('对应的 Ground Truth 光谱');
grid on;

% 3. 时域信号 FFT
subplot(2, 3, 3);
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

% 4. 噪声验证：实际相对误差分布
subplot(2, 3, 4);
histogram(actual_errors(:), 50, 'Normalization', 'pdf', 'FaceColor', [0.3, 0.6, 0.9]);
hold on;
xline(mean(actual_errors(:)), 'r-', 'LineWidth', 2);
xline(target_rel_error * 100, 'g--', 'LineWidth', 2);
xlabel('相对误差 (%)');
ylabel('概率密度');
title(sprintf('相对误差分布\n实际均值: %.2f%%, 目标: %.1f%%', mean(actual_errors(:)), target_rel_error * 100));
legend('分布', '实际均值', '目标', 'Location', 'best');
grid on;

% 5. 每个 LED 的平均误差
subplot(2, 3, 5);
led_mean_errors = mean(actual_errors, 1);
bar(1:N_led, led_mean_errors, 'FaceColor', [0.3, 0.6, 0.9]);
hold on;
yline(target_rel_error * 100, 'r--', 'LineWidth', 2);
xlabel('LED');
ylabel('平均相对误差 (%)');
title('各 LED 平均相对误差');
set(gca, 'XTick', 1:N_led);
grid on;

% 6. 光谱分布
subplot(2, 3, 6);
histogram(Y_train(:), 50, 'Normalization', 'pdf', 'FaceColor', [0.9, 0.6, 0.3]);
xlabel('反射率')
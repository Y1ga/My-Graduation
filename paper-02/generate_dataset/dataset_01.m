

%% 
%% FDM Spectroscopy Simulation Data Generation
% 生成频分复用光谱仪的仿真训练数据
% 输入: 时域信号 (N_samples × N_points)
% 输出: 光谱 (N_samples × 31)

clear; clc;
A = load_mat("led_0711", "gt");
data_path = 'W:\dataset\benchmark\pixel_data_clustered\pixels_all.mat';
data = load(data_path);
x = data.spectra;

%% ===================== 参数设置 =====================
% 请根据实际情况修改数据加载路径
% load('your_data.mat');  % 需要包含 A (31×12), x (9882×31)

% --- 时域采样参数 ---
fs = 1e6;           % 采样率: 1 MHz
T = 1e-3;           % 采样时间: 1 ms
N_points = fs * T;  % 采样点数: 1000

% --- 调制频率参数 ---
N_led = 12;         % LED数量
f_start = 100e3;    % 起始频率: 100 kHz
f_step = 10e3;      % 频率间隔: 10 kHz
f_carriers = f_start + (0:N_led-1) * f_step;  % 12个载波频率: 100k-210kHz

% --- 时间向量 ---
t = (0:N_points-1) / fs;  % 1×1000

%% ===================== 显示参数信息 =====================
fprintf('========== FDM仿真参数 ==========\n');
fprintf('采样率: %.0f kHz\n', fs/1e3);
fprintf('采样时间: %.1f ms\n', T*1e3);
fprintf('采样点数: %d\n', N_points);
fprintf('频率分辨率: %.0f Hz\n', 1/T);
fprintf('载波频率范围: %.0f - %.0f kHz\n', f_carriers(1)/1e3, f_carriers(end)/1e3);
fprintf('频率间隔: %.0f kHz\n', f_step/1e3);
fprintf('Nyquist频率: %.0f kHz\n', fs/2/1e3);
fprintf('=================================\n\n');

%% ===================== 生成调制波形矩阵 =====================
% 预生成12个LED的方波调制信号 (12 × 1000)
% 方波定义: 正半周期为1，负半周期为0 (与论文一致)

modulation_matrix = zeros(N_led, N_points);
for k = 1:N_led
    % 生成方波: square函数输出±1，转换为0/1
    sq_wave = square(2 * pi * f_carriers(k) * t);
    modulation_matrix(k, :) = (sq_wave + 1) / 2;  % 转换为 0/1
end

fprintf('调制波形矩阵生成完成: %d × %d\n', size(modulation_matrix));

%% ===================== 检查数据是否已加载 =====================
if ~exist('A', 'var') || ~exist('x', 'var')
    error(['请先加载数据!\n' ...
           '需要的变量:\n' ...
           '  A: 31×12 LED发射光谱矩阵\n' ...
           '  x: N×31 Ground Truth光谱\n' ...
           '使用方法: 先load数据, 再运行此脚本']);
end

% 验证数据维度
assert(size(A, 1) == 31 && size(A, 2) == 12, 'A的维度应为31×12');
assert(size(x, 2) == 31, 'x的第二维应为31');

N_samples = size(x, 1);
fprintf('样本数量: %d\n', N_samples);

%% ===================== 生成仿真数据 =====================
fprintf('\n开始生成仿真数据...\n');

% 预分配输出矩阵
time_signals = zeros(N_samples, N_points);  % 时域信号

tic;
for i = 1:N_samples
    % 1. 获取当前样本的光谱 (1×31)
    spectrum = x(i, :);
    
    % 2. 计算理想测量值: I = A' * spectrum' (12×1)
    %    I_k = sum_n(A(n,k) * spectrum(n))
    I_led = A' * spectrum';  % 12×1, 每个LED对应的强度
    
    % 3. 生成叠加的时域信号
    %    I_total(t) = sum_k(I_k * modulation_k(t))
    time_signals(i, :) = I_led' * modulation_matrix;  % 1×1000
    
    % 进度显示
    if mod(i, 1000) == 0
        fprintf('  进度: %d / %d (%.1f%%)\n', i, N_samples, i/N_samples*100);
    end
end
elapsed = toc;

fprintf('数据生成完成! 耗时: %.2f 秒\n', elapsed);
fprintf('时域信号矩阵: %d × %d\n', size(time_signals));

%% ===================== 数据归一化 (可选) =====================
% 对时域信号进行归一化，有助于神经网络训练

% 方案1: 全局归一化
time_signals_norm = time_signals / max(abs(time_signals(:)));

% 方案2: 逐样本归一化 (每个样本独立归一化到[0,1])
% time_signals_norm = zeros(size(time_signals));
% for i = 1:N_samples
%     sig = time_signals(i, :);
%     time_signals_norm(i, :) = (sig - min(sig)) / (max(sig) - min(sig) + eps);
% end

fprintf('归一化完成\n');

%% ===================== 划分训练集/验证集/测试集 =====================
% 比例: 80% / 10% / 10%

rng(42);  % 固定随机种子，保证可重复性
idx = randperm(N_samples);

n_train = round(N_samples * 0.8);
n_val = round(N_samples * 0.1);

idx_train = idx(1:n_train);
idx_val = idx(n_train+1 : n_train+n_val);
idx_test = idx(n_train+n_val+1 : end);

% 训练集
X_train = time_signals_norm(idx_train, :);
Y_train = x(idx_train, :);

% 验证集
X_val = time_signals_norm(idx_val, :);
Y_val = x(idx_val, :);

% 测试集
X_test = time_signals_norm(idx_test, :);
Y_test = x(idx_test, :);

fprintf('\n数据集划分:\n');
fprintf('  训练集: %d 样本\n', size(X_train, 1));
fprintf('  验证集: %d 样本\n', size(X_val, 1));
fprintf('  测试集: %d 样本\n', size(X_test, 1));

%% ===================== 保存数据 =====================
% 保存为.mat格式
save_path_mat = 'fdm_dataset.mat';
save(save_path_mat, 'X_train', 'Y_train', 'X_val', 'Y_val', 'X_test', 'Y_test', ...
     'f_carriers', 'fs', 'T', 't', 'A', 'modulation_matrix', '-v7.3');
fprintf('\n已保存MAT文件: %s\n', save_path_mat);

% 保存为.npy格式 (需要npy-matlab工具包)
% 如果没有安装，可以从这里下载: https://github.com/kwikteam/npy-matlab
try
    save_path_npy = 'fdm_dataset_npy';
    if ~exist(save_path_npy, 'dir')
        mkdir(save_path_npy);
    end
    
    writeNPY(X_train, fullfile(save_path_npy, 'X_train.npy'));
    writeNPY(Y_train, fullfile(save_path_npy, 'Y_train.npy'));
    writeNPY(X_val, fullfile(save_path_npy, 'X_val.npy'));
    writeNPY(Y_val, fullfile(save_path_npy, 'Y_val.npy'));
    writeNPY(X_test, fullfile(save_path_npy, 'X_test.npy'));
    writeNPY(Y_test, fullfile(save_path_npy, 'Y_test.npy'));
    writeNPY(f_carriers', fullfile(save_path_npy, 'f_carriers.npy'));
    writeNPY(A, fullfile(save_path_npy, 'A.npy'));
    
    fprintf('已保存NPY文件到: %s/\n', save_path_npy);
catch ME
    warning('NPY保存失败: %s\n请安装npy-matlab工具包，或使用Python读取.mat文件', ME.message);
end

%% ===================== 可视化验证 =====================
figure('Position', [100, 100, 1400, 800]);

% 1. 显示几个样本的时域信号
subplot(2,3,1);
plot(t*1e3, time_signals_norm(1:5, :)');
xlabel('时间 (ms)');
ylabel('归一化幅值');
title('时域信号示例 (5个样本)');
xlim([0, 0.1]);  % 只显示前0.1ms，看清调制
legend('样本1', '样本2', '样本3', '样本4', '样本5');
grid on;

% 2. 显示对应的光谱
subplot(2,3,2);
if exist('wav', 'var')
    plot(wav, x(1:5, :)');
    xlabel('波长 (nm)');
else
    plot(1:31, x(1:5, :)');
    xlabel('波长通道');
end
ylabel('强度');
title('对应的Ground Truth光谱');
legend('样本1', '样本2', '样本3', '样本4', '样本5');
grid on;

% 3. 显示单个样本的完整时域信号
subplot(2,3,3);
plot(t*1e3, time_signals_norm(1, :));
xlabel('时间 (ms)');
ylabel('归一化幅值');
title('单个样本的完整时域信号');
grid on;

% 4. 显示FFT频谱，验证载波频率
subplot(2,3,4);
Y_fft = abs(fft(time_signals_norm(1, :)));
f_axis = (0:N_points-1) * fs / N_points;
plot(f_axis/1e3, Y_fft);
xlabel('频率 (kHz)');
ylabel('幅值');
title('FFT频谱 (验证载波)');
xlim([0, 300]);  % 只显示0-300kHz
hold on;
% 标注12个载波频率
for k = 1:N_led
    xline(f_carriers(k)/1e3, 'r--', sprintf('%.0fk', f_carriers(k)/1e3));
end
grid on;

% 5. 显示LED发射光谱矩阵
subplot(2,3,5);
if exist('wav', 'var')
    plot(wav, A);
    xlabel('波长 (nm)');
else
    plot(1:31, A);
    xlabel('波长通道');
end
ylabel('响应');
title('LED发射光谱矩阵 A (31×12)');
grid on;

% 6. 显示调制波形
subplot(2,3,6);
plot(t(1:100)*1e6, modulation_matrix(:, 1:100)');
xlabel('时间 (μs)');
ylabel('调制值');
title('调制波形 (前100μs)');
ylim([-0.1, 1.1]);
grid on;

sgtitle('FDM仿真数据验证');

% 保存图片
saveas(gcf, 'fdm_data_visualization.png');
fprintf('\n可视化图片已保存: fdm_data_visualization.png\n');

%% ===================== 完成 =====================
fprintf('\n========== 数据生成完成 ==========\n');
fprintf('下一步: 使用PyTorch训练E2E神经网络\n');
fprintf('  - 输入: X_train (%d × %d)\n', size(X_train));
fprintf('  - 输出: Y_train (%d × %d)\n', size(Y_train));
fprintf('==================================\n');
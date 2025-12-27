%% graduation_compare.m : 梯度下降法 vs SVD 方法对比
clear; clc; close all;
%% 1. 构造仿真数据
% 设置随机种子以便复现
rng(42);

% 波长范围
wav = linspace(400, 700, 31)'; % 列向量
N = length(wav);
M = 15; % 传感器数量 (M < N，欠定问题)

% 构造 A: 模拟光谱响应函数 (高斯滤波器)
centers = linspace(400, 700, M);
A = zeros(M, N);
for i = 1:M
    sigma = 30 / 2.355; % FWHM = 30nm
    A(i, :) = exp(-((wav - centers(i)).^2) / (2 * sigma^2));
end
% 归一化 A
A = A ./ max(A,[],2);

data = load("data/graduation/hsi_24");
data = data.hsi;
data = data(:, :,1:31);
data = permute(data,[3,1,2]);
% 取光谱图象中的随便一个像素
x = data(:, 123, 131);
% 构造 x: 真实光谱 (双峰高斯分布)
x_true = 0.8 * exp(-((wav - 480).^2) / (2 * 40^2)) + ...
         0.5 * exp(-((wav - 620).^2) / (2 * 50^2));
% x_true = x;
% 构造 y: 测量值 (y = Ax)
y = A * x_true;
% 添加极少量噪声 (可选)
% y = y + 0.01 * randn(size(y));
plot(wav, A);

%% 2. 算法求解
% --- 方法 A: 梯度下降法 (带 TV 正则化) ---
disp('正在运行梯度下降法...');
tic;
x_gd = opt_gd(A, y);
time_gd = toc;

% --- 方法 B: 奇异值分解法 (SVD) ---
disp('正在运行 SVD 方法...');
% k 参数选择：保留前 k 个奇异值。
% 对于 M=15 的矩阵，k=10 通常是一个折中值
k_val = 12; 
tic;
x_svd = opt_svd(A, y, k_val);
time_svd = toc;

%% 3. 定量分析 (RMSE)
rmse_gd = sqrt(mean((x_gd - x_true).^2));
rmse_svd = sqrt(mean((x_svd - x_true).^2));

fprintf('\n=== 定量分析结果 ===\n');
fprintf('梯度下降法 (GD)  RMSE: %.4f | 耗时: %.4f 秒\n', rmse_gd, time_gd);
fprintf('奇异值分解 (SVD) RMSE: %.4f | 耗时: %.4f 秒\n', rmse_svd, time_svd);

%% 4. 可视化对比
figure('Color', 'w', 'Position', [100, 100, 800, 500]);
hold on; box on; grid on;

% 绘制真实光谱
p1 = plot(wav, x_true, 'k-', 'LineWidth', 2);

% 绘制 GD 结果
p2 = plot(wav, x_gd, 'b--o', 'LineWidth', 1.5, 'MarkerSize', 4);

% 绘制 SVD 结果
p3 = plot(wav, x_svd, 'r-.x', 'LineWidth', 1.5, 'MarkerSize', 6);

% 设置图例和标题
legend([p1, p2, p3], ...
    '真实光谱 (Ground Truth)', ...
    ['梯度下降法 (RMSE = ' num2str(rmse_gd, '%.4f') ')'], ...
    ['SVD 方法 (k=' num2str(k_val) ', RMSE = ' num2str(rmse_svd, '%.4f') ')'], ...
    'Location', 'Best');

title('光谱重建算法对比：迭代法 vs 解析法');
xlabel('波长 (nm)');
ylabel('归一化强度');
ylim([-0.1, 1.1]);
%% 调用示例 (放在脚本中)
% lambda 是正则化参数，建议从 0.1 开始尝试，逐步减小或增大
% 经验范围：0.01 到 1.0 之间
lambda = 0.01; 
x_tikhonov = opt_tikhonov(A, y, lambda);

% 绘图比较
figure;
plot(wav, x_true, 'k-', 'LineWidth', 2); hold on;
plot(wav, x_tikhonov, 'r--o', 'LineWidth', 1.5);
legend('真实光谱', ['Tikhonov (lambda=' num2str(lambda) ')']);
title('Tikhonov 正则化重建结果');

%% 函数定义
function x = opt_tikhonov(A, y, lambda)
    % A: 系统矩阵
    % y: 测量值
    % lambda: 正则化系数 (Tikhonov 参数)
    
    if nargin < 3
        lambda = 0.1; % 默认值
    end

    % 1. SVD 分解
    [U, S, V] = svd(A, 'econ');
    s_val = diag(S); % 获取奇异值向量
    
    % 2. 构造 Tikhonov 滤波因子 (核心修改)
    % 公式: filter = sigma / (sigma^2 + lambda^2)
    % 这相当于原来的 1/sigma * (sigma^2 / (sigma^2 + lambda^2))
    s_filter = s_val ./ (s_val.^2 + lambda^2);
    
    % 3. 计算解
    % x = V * diag(filter) * U' * y
    % 为了计算速度，使用向量点乘代替对角矩阵乘法
    x = V * (s_filter .* (U' * y));
    
    % 4. 投影约束 (必须加)
    % 因为 Tikhonov 本质是 L2 范数约束，不保证非负
    x = max(0, min(1, x));
end
%% --- 局部函数定义 ---

% 函数 1: 梯度下降法
function x = opt_gd(A, y)
    [~, n] = size(A);
    x = rand(n, 1); % 随机初始值
    
    % 参数设置
    alpha = 0.01;      % 学习率
    beta3 = 1.0;       % TV 正则化权重 (控制平滑度)
    max_iter = 3000;   % 最大迭代次数
    tol = 1e-6;        % 收敛阈值
    
    % 差分算子 (用于 TV 正则化)
    D = diff(eye(n)); 
    
    for k = 1:max_iter
        x_old = x;
        
        % 1. 数据拟合项梯度 (Data Fidelity)
        residual = A * x - y;
        % 归一化梯度以保持稳定
        grad_fit = A' * residual;
        if norm(residual) > 1e-9
            grad_fit = grad_fit / norm(residual);
        end
        
        % 2. TV 正则化项梯度 (Total Variation)
        diff_x = D * x;
        grad_tv = zeros(n, 1);
        norm_diff = sqrt(sum(diff_x.^2));
        if norm_diff > 1e-9
            grad_tv = beta3 * (D' * diff_x) / norm_diff;
        end
        
        % 3. 更新 x
        grad = grad_fit + grad_tv;
        x = x - alpha * grad;
        
        % 4. 投影约束 (0 <= x <= 1)
        x = max(0, min(1, x));
        
        % 5. 检查收敛
        if norm(x - x_old) < tol
            break;
        end
    end
end

% 函数 2: 奇异值分解法 (Truncated SVD)
function x = opt_svd(A, y, k)
    % A: 系统矩阵
    % y: 测量值
    % k: 截断参数 (保留前 k 个奇异值)
    
    % 1. SVD 分解
    % econ 模式下 U 是 MxM, S 是 MxM, V 是 NxM (若M<N)
    [U, S, V] = svd(A, 'econ');
    
    s_diag = diag(S);
    if nargin < 3
        k = length(s_diag);
    end
    
    % 2. 构造逆奇异值矩阵 (截断)
    s_inv_diag = zeros(size(s_diag));
    for i = 1:k
        if s_diag(i) > 1e-10
            s_inv_diag(i) = 1 / s_diag(i);
        end
    end
    
    % 3. 计算解 x = V * S_inv * U' * y
    x = V * (diag(s_inv_diag) * (U' * y));
    
    % 4. 投影约束 (强制非负和最大值约束)
    x = max(0, min(1, x));
end
%% spectral_reconstruction_benchmark.m
% 光谱重建算法 Benchmark
% 问题: y = Ax, 已知 y 和 A, 求解 x
%
% 测试方法分类:
%   1. 直接法 (伪逆、最小二乘)
%   2. 正则化方法 (Tikhonov, LASSO, Ridge)
%   3. 稀疏优化 (OMP, BPDN, ISTA/FISTA)
%   4. 贝叶斯方法 (MAP, Sparse Bayesian Learning)
%   5. 字典学习 (K-SVD + OMP)
%   6. 非负约束 (NNLS, NMF)
%   7. 迭代优化 (ADMM, Proximal Gradient)
%
% 评估指标:
%   - RMSE, MRAE, SAM, SID, PSNR, SSIM
%   - 计算时间
%
% 作者: [Your Name]
% 日期: 2024

clear; clc; close all;
rng(42);

%% ======================== 配置 ========================
config = struct();

% 数据路径
config.data_path = 'W:\dataset\benchmark\pixel_data_clustered\pixels_all.mat';

% 滤波器参数
config.num_channels = 15;       % 测量通道数
config.num_bands = 31;          % 光谱波段数
config.wavelengths = 400:10:700; % 波长范围 (nm)
config.fwhm = 30;               % 滤波器半高宽 (nm)

% 噪声参数
config.add_noise = true;
config.noise_snr = 30;          % 信噪比 (dB)

% 测试参数
config.max_test_pixels = inf;  % 使用全部像素

% 输出路径
config.output_folder = 'W:\dataset\benchmark\reconstruction_results';
if ~exist(config.output_folder, 'dir')
    mkdir(config.output_folder);
end

%% ======================== 生成滤波器矩阵 A ========================
fprintf('========================================\n');
fprintf('  光谱重建算法 Benchmark\n');
fprintf('========================================\n\n');

fprintf('生成滤波器矩阵 A [%d x %d]...\n', config.num_channels, config.num_bands);

wav = config.wavelengths;
M = config.num_channels;
N = config.num_bands;

% 均匀分布的滤波器中心波长
centers = linspace(wav(1), wav(end), M);
sigma = config.fwhm / 2.355;

A = zeros(M, N);
for i = 1:M
    A(i, :) = exp(-((wav - centers(i)).^2) / (2 * sigma^2));
end
A = A ./ max(A, [], 2);  % 归一化

fprintf('滤波器中心波长: %.0f - %.0f nm\n', centers(1), centers(end));
fprintf('FWHM: %.0f nm\n', config.fwhm);

% 显示滤波器
figure('Color', 'w', 'Position', [100, 100, 600, 300]);
plot(wav, A', 'LineWidth', 1.5);
xlabel('波长 (nm)');
ylabel('响应');
title(sprintf('滤波器响应矩阵 A [%d × %d]', M, N));
grid on;

%% ======================== 加载测试数据 ========================
fprintf('\n加载测试数据...\n');

data = load(config.data_path);
spectra_gt = data.spectra;  % [N_pixels x 31] Ground Truth

% 采样测试像素
n_pixels = size(spectra_gt, 1);
if n_pixels > config.max_test_pixels
    test_idx = randperm(n_pixels, config.max_test_pixels);
else
    test_idx = 1:n_pixels;
end
spectra_gt = spectra_gt(test_idx, :);
n_test = size(spectra_gt, 1);

fprintf('测试像素数: %d\n', n_test);

% 生成测量值 y = Ax
Y = (A * spectra_gt')';  % [n_test x M]

% 添加噪声
if config.add_noise
    noise_std = mean(Y(:)) / (10^(config.noise_snr/20));
    Y_noisy = Y + noise_std * randn(size(Y));
    fprintf('添加噪声: SNR = %d dB\n', config.noise_snr);
else
    Y_noisy = Y;
end

%% ======================== 定义所有方法 ========================
fprintf('\n========================================\n');
fprintf('  测试方法列表\n');
fprintf('========================================\n\n');

methods = struct();

% ===== 1. 直接法 =====
methods(1).name = 'Pseudoinverse';
methods(1).category = '直接法';
methods(1).func = @(y, A, params) method_pseudoinverse(y, A, params);
methods(1).params = struct();

methods(2).name = 'Least Squares (lsqminnorm)';
methods(2).category = '直接法';
methods(2).func = @(y, A, params) method_lsqminnorm(y, A, params);
methods(2).params = struct();

% ===== 2. 正则化方法 =====
methods(3).name = 'Tikhonov (Ridge)';
methods(3).category = '正则化';
methods(3).func = @(y, A, params) method_tikhonov(y, A, params);
methods(3).params = struct('lambda', 0.01);

methods(4).name = 'Tikhonov (lambda=0.1)';
methods(4).category = '正则化';
methods(4).func = @(y, A, params) method_tikhonov(y, A, params);
methods(4).params = struct('lambda', 0.1);

methods(5).name = 'LASSO (L1)';
methods(5).category = '正则化';
methods(5).func = @(y, A, params) method_lasso(y, A, params);
methods(5).params = struct('lambda', 0.001);

methods(6).name = 'Elastic Net';
methods(6).category = '正则化';
methods(6).func = @(y, A, params) method_elasticnet(y, A, params);
methods(6).params = struct('lambda', 0.01, 'alpha', 0.5);

% ===== 3. 稀疏优化 =====
methods(7).name = 'OMP';
methods(7).category = '稀疏优化';
methods(7).func = @(y, A, params) method_omp(y, A, params);
methods(7).params = struct('sparsity', 10);

methods(8).name = 'ISTA';
methods(8).category = '稀疏优化';
methods(8).func = @(y, A, params) method_ista(y, A, params);
methods(8).params = struct('lambda', 0.001, 'max_iter', 100);

methods(9).name = 'FISTA';
methods(9).category = '稀疏优化';
methods(9).func = @(y, A, params) method_fista(y, A, params);
methods(9).params = struct('lambda', 0.001, 'max_iter', 100);

% ===== 4. 非负约束 =====
methods(10).name = 'NNLS';
methods(10).category = '非负约束';
methods(10).func = @(y, A, params) method_nnls(y, A, params);
methods(10).params = struct();

methods(11).name = 'Non-negative Tikhonov';
methods(11).category = '非负约束';
methods(11).func = @(y, A, params) method_nn_tikhonov(y, A, params);
methods(11).params = struct('lambda', 0.01, 'max_iter', 100);

% ===== 5. 贝叶斯方法 =====
methods(12).name = 'MAP Gaussian Prior';
methods(12).category = '贝叶斯';
methods(12).func = @(y, A, params) method_map_gaussian(y, A, params);
methods(12).params = struct('prior_var', 1, 'noise_var', 0.01);

% ===== 6. 迭代优化 =====
methods(13).name = 'Gradient Descent';
methods(13).category = '迭代优化';
methods(13).func = @(y, A, params) method_gradient_descent(y, A, params);
methods(13).params = struct('lr', 0.01, 'max_iter', 200);

methods(14).name = 'Conjugate Gradient';
methods(14).category = '迭代优化';
methods(14).func = @(y, A, params) method_conjugate_gradient(y, A, params);
methods(14).params = struct('max_iter', 100, 'tol', 1e-6);

methods(15).name = 'ADMM';
methods(15).category = '迭代优化';
methods(15).func = @(y, A, params) method_admm(y, A, params);
methods(15).params = struct('lambda', 0.01, 'rho', 1, 'max_iter', 100);

% ===== 7. 平滑约束 =====
methods(16).name = 'Total Variation';
methods(16).category = '平滑约束';
methods(16).func = @(y, A, params) method_tv(y, A, params);
methods(16).params = struct('lambda', 0.01, 'max_iter', 100);

methods(17).name = 'Smoothness Regularization';
methods(17).category = '平滑约束';
methods(17).func = @(y, A, params) method_smooth(y, A, params);
methods(17).params = struct('lambda', 0.1);

n_methods = length(methods);

fprintf('共 %d 种方法:\n', n_methods);
categories = unique({methods.category});
for c = 1:length(categories)
    cat_methods = {methods(strcmp({methods.category}, categories{c})).name};
    fprintf('  [%s]: %s\n', categories{c}, strjoin(cat_methods, ', '));
end

%% ======================== 运行 Benchmark ========================
fprintf('\n========================================\n');
fprintf('  运行 Benchmark\n');
fprintf('========================================\n\n');

% 结果存储
results = struct();
results.method_names = {methods.name};
results.categories = {methods.category};

% 指标矩阵 [n_methods x n_test]
results.RMSE = zeros(n_methods, n_test);
results.MRAE = zeros(n_methods, n_test);
results.SAM = zeros(n_methods, n_test);
results.SID = zeros(n_methods, n_test);
results.PSNR = zeros(n_methods, n_test);
results.time = zeros(n_methods, 1);  % 总时间

% 重建结果 (可选，占内存)
% results.reconstructed = zeros(n_methods, n_test, N);

for m = 1:n_methods
    fprintf('[%2d/%d] %-25s ... ', m, n_methods, methods(m).name);
    
    tic;
    
    for p = 1:n_test
        y = Y_noisy(p, :)';  % [M x 1]
        x_gt = spectra_gt(p, :)';  % [N x 1]
        
        try
            % 调用方法
            x_rec = methods(m).func(y, A, methods(m).params);
            x_rec = x_rec(:);
            
            % 确保非负
            x_rec = max(x_rec, 0);
            
            % 计算指标
            results.RMSE(m, p) = sqrt(mean((x_rec - x_gt).^2));
            results.MRAE(m, p) = mean(abs(x_rec - x_gt) ./ (abs(x_gt) + eps));
            results.SAM(m, p) = compute_sam(x_rec', x_gt');
            results.SID(m, p) = compute_sid(x_rec', x_gt');
            results.PSNR(m, p) = compute_psnr(x_rec, x_gt);
            
        catch ME
            % 方法失败
            results.RMSE(m, p) = NaN;
            results.MRAE(m, p) = NaN;
            results.SAM(m, p) = NaN;
            results.SID(m, p) = NaN;
            results.PSNR(m, p) = NaN;
        end
    end
    
    results.time(m) = toc;
    
    % 统计
    mean_rmse = nanmean(results.RMSE(m, :));
    mean_sam = nanmean(results.SAM(m, :));
    mean_psnr = nanmean(results.PSNR(m, :));
    fprintf('RMSE=%.4f, SAM=%.4f, PSNR=%.2fdB, Time=%.2fs\n', mean_rmse, mean_sam, mean_psnr, results.time(m));
end

%% ======================== 汇总结果 ========================
fprintf('\n========================================\n');
fprintf('  结果汇总\n');
fprintf('========================================\n\n');

% 计算各方法的平均指标
summary = table();
summary.Method = results.method_names';
summary.Category = results.categories';
summary.RMSE_mean = nanmean(results.RMSE, 2);
summary.RMSE_std = nanstd(results.RMSE, 0, 2);
summary.MRAE_mean = nanmean(results.MRAE, 2);
summary.SAM_mean = nanmean(results.SAM, 2);
summary.SAM_std = nanstd(results.SAM, 0, 2);
summary.SID_mean = nanmean(results.SID, 2);
summary.PSNR_mean = nanmean(results.PSNR, 2);
summary.PSNR_std = nanstd(results.PSNR, 0, 2);
summary.Time_sec = results.time;

% 按 RMSE 排序
[~, sort_idx] = sort(summary.RMSE_mean);
summary_sorted = summary(sort_idx, :);

% 显示表格
fprintf('%-25s %-10s %10s %10s %10s %10s %10s %8s\n', ...
        'Method', 'Category', 'RMSE', 'MRAE', 'SAM', 'SID', 'PSNR(dB)', 'Time(s)');
fprintf('%s\n', repmat('-', 1, 105));

for i = 1:n_methods
    idx = sort_idx(i);
    fprintf('%-25s %-10s %10.4f %10.4f %10.4f %10.4f %10.2f %8.2f\n', ...
            methods(idx).name, methods(idx).category, ...
            summary.RMSE_mean(idx), summary.MRAE_mean(idx), ...
            summary.SAM_mean(idx), summary.SID_mean(idx), ...
            summary.PSNR_mean(idx), summary.Time_sec(idx));
end

% 最佳方法
[best_rmse, best_idx] = min(summary.RMSE_mean);
fprintf('\n最佳方法 (RMSE): %s (RMSE=%.4f)\n', methods(best_idx).name, best_rmse);

%% ======================== 可视化 (Top 5) ========================
fprintf('\n生成可视化 (Top 5 方法)...\n');

% 取 RMSE 最小的前 5 个方法
top_k = 5;
top_idx = sort_idx(1:top_k);
top_names = results.method_names(top_idx);

figure('Color', 'w', 'Position', [50, 50, 1500, 900], 'Name', 'Benchmark Results (Top 5)');

colors = lines(top_k);

% 1. Top 5 RMSE 条形图
subplot(2, 4, 1);
bar(summary.RMSE_mean(top_idx), 'FaceColor', [0.3 0.6 0.9]);
set(gca, 'XTick', 1:top_k, 'XTickLabel', top_names, 'XTickLabelRotation', 30);
ylabel('RMSE');
title('RMSE (越小越好)');
grid on;

% 2. Top 5 SAM 条形图
subplot(2, 4, 2);
bar(summary.SAM_mean(top_idx), 'FaceColor', [0.8 0.4 0.2]);
set(gca, 'XTick', 1:top_k, 'XTickLabel', top_names, 'XTickLabelRotation', 30);
ylabel('SAM (rad)');
title('SAM (越小越好)');
grid on;

% 3. Top 5 PSNR 条形图
subplot(2, 4, 3);
bar(summary.PSNR_mean(top_idx), 'FaceColor', [0.4 0.7 0.4]);
set(gca, 'XTick', 1:top_k, 'XTickLabel', top_names, 'XTickLabelRotation', 30);
ylabel('PSNR (dB)');
title('PSNR (越大越好)');
grid on;

% 4. Top 5 计算时间
subplot(2, 4, 4);
bar(summary.Time_sec(top_idx), 'FaceColor', [0.6 0.4 0.7]);
set(gca, 'XTick', 1:top_k, 'XTickLabel', top_names, 'XTickLabelRotation', 30);
ylabel('Time (s)');
title('计算时间');
grid on;

% 5. Top 5 RMSE 箱线图
subplot(2, 4, 5);
boxplot(results.RMSE(top_idx, :)', 'Labels', top_names);
ylabel('RMSE');
title('RMSE 分布');
xtickangle(30);
grid on;

% 6. Top 5 PSNR 箱线图
subplot(2, 4, 6);
boxplot(results.PSNR(top_idx, :)', 'Labels', top_names);
ylabel('PSNR (dB)');
title('PSNR 分布');
xtickangle(30);
grid on;

% 7. Top 5 多指标雷达图
subplot(2, 4, 7);
% 归一化指标 (统一越大越好)
metrics_radar = zeros(top_k, 5);
metrics_radar(:, 1) = 1 ./ (summary.RMSE_mean(top_idx) + eps);  % 1/RMSE
metrics_radar(:, 2) = 1 ./ (summary.SAM_mean(top_idx) + eps);   % 1/SAM
metrics_radar(:, 3) = 1 ./ (summary.SID_mean(top_idx) + eps);   % 1/SID
metrics_radar(:, 4) = summary.PSNR_mean(top_idx);               % PSNR 本身越大越好
metrics_radar(:, 5) = 1 ./ (summary.Time_sec(top_idx) + eps);   % 1/Time

% 归一化到 [0, 1]
metrics_radar = metrics_radar ./ max(metrics_radar, [], 1);

bar(metrics_radar);
set(gca, 'XTick', 1:top_k, 'XTickLabel', top_names, 'XTickLabelRotation', 30);
ylabel('归一化得分 (越高越好)');
legend({'1/RMSE', '1/SAM', '1/SID', 'PSNR', '1/Time'}, 'Location', 'best');
title('综合性能对比');
grid on;

% 8. Top 5 重建示例对比
subplot(2, 4, 8);
test_pixel = randi(n_test);  % 随机选一个测试像素
y_test = Y_noisy(test_pixel, :)';
x_gt_test = spectra_gt(test_pixel, :);

hold on;
plot(wav, x_gt_test, 'k-', 'LineWidth', 2.5, 'DisplayName', 'Ground Truth');

for i = 1:top_k
    m_idx = top_idx(i);
    x_rec = methods(m_idx).func(y_test, A, methods(m_idx).params);
    x_rec = max(x_rec, 0);
    plot(wav, x_rec, '--', 'Color', colors(i,:), 'LineWidth', 1.5, ...
         'DisplayName', methods(m_idx).name);
end
hold off;
xlabel('波长 (nm)');
ylabel('反射率');
title(sprintf('重建示例 (像素 #%d)', test_pixel));
legend('Location', 'best');
grid on;

sgtitle(sprintf('光谱重建 Benchmark Top 5 (N=%d, SNR=%ddB)', n_test, config.noise_snr), 'FontSize', 14);

% 保存图片
saveas(gcf, fullfile(config.output_folder, 'benchmark_results.png'));

%% ======================== 保存结果 ========================
save(fullfile(config.output_folder, 'benchmark_results.mat'), 'results', 'summary', 'config', 'A');
writetable(summary_sorted, fullfile(config.output_folder, 'benchmark_summary.csv'));

fprintf('\n结果已保存到: %s\n', config.output_folder);
fprintf('Benchmark 完成!\n');

%% ========================================================================
%                           方法实现
%% ========================================================================

%% ===== 1. 直接法 =====

function x = method_pseudoinverse(y, A, ~)
    % Moore-Penrose 伪逆
    x = pinv(A) * y;
end

function x = method_lsqminnorm(y, A, ~)
    % 最小范数最小二乘解
    x = lsqminnorm(A, y);
end

%% ===== 2. 正则化方法 =====

function x = method_tikhonov(y, A, params)
    % Tikhonov 正则化 (Ridge Regression)
    % min ||Ax - y||^2 + lambda * ||x||^2
    lambda = params.lambda;
    [~, N] = size(A);
    x = (A' * A + lambda * eye(N)) \ (A' * y);
end

function x = method_lasso(y, A, params)
    % LASSO (L1 正则化)
    % min ||Ax - y||^2 + lambda * ||x||_1
    lambda = params.lambda;
    [~, N] = size(A);
    
    % 使用 lasso 函数
    [x, ~] = lasso(A, y, 'Lambda', lambda);
    if isempty(x)
        x = zeros(N, 1);
    end
end

function x = method_elasticnet(y, A, params)
    % Elastic Net (L1 + L2)
    lambda = params.lambda;
    alpha = params.alpha;  % L1 比例
    
    [x, ~] = lasso(A, y, 'Lambda', lambda, 'Alpha', alpha);
    if isempty(x)
        [~, N] = size(A);
        x = zeros(N, 1);
    end
end

%% ===== 3. 稀疏优化 =====

function x = method_omp(y, A, params)
    % Orthogonal Matching Pursuit
    sparsity = params.sparsity;
    [~, N] = size(A);
    
    x = zeros(N, 1);
    residual = y;
    support = [];
    
    for k = 1:sparsity
        % 找最相关的原子
        correlations = abs(A' * residual);
        correlations(support) = 0;  % 排除已选
        [~, idx] = max(correlations);
        support = [support; idx];
        
        % 在支撑集上最小二乘
        x_support = A(:, support) \ y;
        x = zeros(N, 1);
        x(support) = x_support;
        
        % 更新残差
        residual = y - A * x;
    end
end

function x = method_ista(y, A, params)
    % Iterative Shrinkage-Thresholding Algorithm
    lambda = params.lambda;
    max_iter = params.max_iter;
    
    [~, N] = size(A);
    L = norm(A' * A, 2);  % Lipschitz 常数
    t = 1 / L;
    
    x = zeros(N, 1);
    
    for iter = 1:max_iter
        grad = A' * (A * x - y);
        x = soft_threshold(x - t * grad, lambda * t);
    end
end

function x = method_fista(y, A, params)
    % Fast ISTA (加速版)
    lambda = params.lambda;
    max_iter = params.max_iter;
    
    [~, N] = size(A);
    L = norm(A' * A, 2);
    t = 1 / L;
    
    x = zeros(N, 1);
    x_old = x;
    tk = 1;
    
    for iter = 1:max_iter
        tk_new = (1 + sqrt(1 + 4 * tk^2)) / 2;
        z = x + ((tk - 1) / tk_new) * (x - x_old);
        
        grad = A' * (A * z - y);
        x_old = x;
        x = soft_threshold(z - t * grad, lambda * t);
        tk = tk_new;
    end
end

%% ===== 4. 非负约束 =====

function x = method_nnls(y, A, ~)
    % Non-negative Least Squares
    x = lsqnonneg(A, y);
end

function x = method_nn_tikhonov(y, A, params)
    % Non-negative Tikhonov (迭代投影)
    lambda = params.lambda;
    max_iter = params.max_iter;
    
    [~, N] = size(A);
    H = A' * A + lambda * eye(N);
    f = A' * y;
    
    x = zeros(N, 1);
    
    for iter = 1:max_iter
        x_new = H \ (f + lambda * max(x, 0) - lambda * x + H * x);
        x_new = max(x_new, 0);
        
        if norm(x_new - x) < 1e-6
            break;
        end
        x = x_new;
    end
end

%% ===== 5. 贝叶斯方法 =====

function x = method_map_gaussian(y, A, params)
    % MAP with Gaussian prior
    % p(x) = N(0, prior_var * I)
    % p(y|x) = N(Ax, noise_var * I)
    prior_var = params.prior_var;
    noise_var = params.noise_var;
    
    [~, N] = size(A);
    
    % MAP 解
    x = (A' * A / noise_var + eye(N) / prior_var) \ (A' * y / noise_var);
end

%% ===== 6. 迭代优化 =====

function x = method_gradient_descent(y, A, params)
    % 梯度下降
    lr = params.lr;
    max_iter = params.max_iter;
    
    [~, N] = size(A);
    x = zeros(N, 1);
    
    for iter = 1:max_iter
        grad = A' * (A * x - y);
        x = x - lr * grad;
    end
end

function x = method_conjugate_gradient(y, A, params)
    % 共轭梯度法
    max_iter = params.max_iter;
    tol = params.tol;
    
    % 求解正规方程 A'Ax = A'y
    ATA = A' * A;
    ATy = A' * y;
    
    [x, ~] = pcg(ATA, ATy, tol, max_iter);
end

function x = method_admm(y, A, params)
    % ADMM for LASSO
    % min ||Ax - y||^2 + lambda * ||z||_1
    % s.t. x = z
    lambda = params.lambda;
    rho = params.rho;
    max_iter = params.max_iter;
    
    [~, N] = size(A);
    
    % 预计算
    ATA = A' * A;
    ATy = A' * y;
    L = chol(ATA + rho * eye(N), 'lower');
    
    x = zeros(N, 1);
    z = zeros(N, 1);
    u = zeros(N, 1);
    
    for iter = 1:max_iter
        % x 更新
        x = L' \ (L \ (ATy + rho * (z - u)));
        
        % z 更新 (软阈值)
        z = soft_threshold(x + u, lambda / rho);
        
        % u 更新
        u = u + x - z;
    end
end

%% ===== 7. 平滑约束 =====

function x = method_tv(y, A, params)
    % Total Variation 正则化 (迭代)
    lambda = params.lambda;
    max_iter = params.max_iter;
    
    [~, N] = size(A);
    
    % 差分矩阵
    D = spdiags([-ones(N,1), ones(N,1)], [0, 1], N-1, N);
    
    x = pinv(A) * y;  % 初始化
    
    for iter = 1:max_iter
        % 计算权重
        Dx = D * x;
        W = spdiags(1 ./ (abs(Dx) + 1e-6), 0, N-1, N-1);
        
        % 更新 x
        x = (A' * A + lambda * D' * W * D) \ (A' * y);
    end
end

function x = method_smooth(y, A, params)
    % 二阶平滑约束
    % min ||Ax - y||^2 + lambda * ||Dx||^2
    lambda = params.lambda;
    
    [~, N] = size(A);
    
    % 二阶差分矩阵
    D = spdiags([ones(N,1), -2*ones(N,1), ones(N,1)], [0, 1, 2], N-2, N);
    
    x = (A' * A + lambda * (D' * D)) \ (A' * y);
end

%% ===== 辅助函数 =====

function x = soft_threshold(x, thresh)
    % 软阈值算子
    x = sign(x) .* max(abs(x) - thresh, 0);
end

function sam = compute_sam(x, y)
    % 光谱角
    cos_val = dot(x, y) / (norm(x) * norm(y) + eps);
    cos_val = max(min(cos_val, 1), -1);
    sam = acos(cos_val);
end

function sid = compute_sid(x, y)
    % 光谱信息散度
    p = x / (sum(x) + eps);
    q = y / (sum(y) + eps);
    p = max(p, eps);
    q = max(q, eps);
    sid = sum(p .* log(p ./ q)) + sum(q .* log(q ./ p));
end

function psnr_val = compute_psnr(x_rec, x_gt)
    % 峰值信噪比
    % PSNR = 20 * log10(MAX / RMSE)
    % x_rec, x_gt: 列向量
    rmse = sqrt(mean((x_rec(:) - x_gt(:)).^2));
    if rmse < eps
        psnr_val = 100;  % 完美重建
    else
        max_val = max(x_gt(:));
        if max_val < eps
            max_val = 1;
        end
        max_val = 1;
        psnr_val = 20 * log10(max_val / rmse);
    end
end
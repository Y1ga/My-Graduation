%% 验证数据集生成的实际相对误差
% 检查 y_noisy 与 y_clean 之间的相对误差

clear; clc; close all;

%% 参数设置
target_rel_error = 0.1;  % 目标相对误差 5%
noise_sigma = target_rel_error / sqrt(2/pi);
n_samples = 100000;  % 测试样本数

fprintf('========== 噪声参数 ==========\n');
fprintf('目标相对误差: %.2f%%\n', target_rel_error * 100);
fprintf('噪声sigma: %.4f\n', noise_sigma);
fprintf('理论关系: sigma = rel_error / sqrt(2/pi) = %.4f\n', target_rel_error / sqrt(2/pi));

%% 加载测量矩阵
A = load_mat("A_hybrid_0115", "gt");  % 6×31
[K, n_channels] = size(A);
fprintf('\nA: [%d × %d]\n', K, n_channels);

%% 生成随机光谱
fprintf('\n生成 %d 个随机光谱...\n', n_samples);
Y = rand(n_samples, n_channels);  % 随机光谱 [0, 1]

%% 计算测量值
% 干净测量值
X_clean = Y * A';  % (n_samples, K)

% 添加乘性噪声
noise = noise_sigma * randn(n_samples, K);
X_noisy = X_clean .* (1 + noise);
X_noisy = max(X_noisy, 0);  % 裁剪负值

%% 计算相对误差
% 逐元素相对误差
rel_error_element = abs(X_noisy - X_clean) ./ (abs(X_clean) + 1e-10);

% 排除X_clean接近0的点（会导致相对误差爆炸）
valid_mask = abs(X_clean) > 0.01;
rel_error_valid = rel_error_element(valid_mask);

fprintf('\n========== 相对误差统计 ==========\n');
fprintf('所有元素:\n');
fprintf('  平均相对误差: %.4f (%.2f%%)\n', mean(rel_error_element(:)), mean(rel_error_element(:))*100);
fprintf('  中位数相对误差: %.4f (%.2f%%)\n', median(rel_error_element(:)), median(rel_error_element(:))*100);
fprintf('  标准差: %.4f\n', std(rel_error_element(:)));

fprintf('\n有效元素 (X_clean > 0.01):\n');
fprintf('  平均相对误差: %.4f (%.2f%%)\n', mean(rel_error_valid), mean(rel_error_valid)*100);
fprintf('  中位数相对误差: %.4f (%.2f%%)\n', median(rel_error_valid), median(rel_error_valid)*100);
fprintf('  标准差: %.4f\n', std(rel_error_valid));

%% 逐通道统计
fprintf('\n逐测量通道相对误差:\n');
for k = 1:K
    re_k = rel_error_element(:, k);
    fprintf('  通道 %d: mean=%.4f (%.2f%%), median=%.4f\n', ...
        k, mean(re_k), mean(re_k)*100, median(re_k));
end

%% 逐样本统计
rel_error_per_sample = mean(rel_error_element, 2);
fprintf('\n逐样本平均相对误差:\n');
fprintf('  mean: %.4f (%.2f%%)\n', mean(rel_error_per_sample), mean(rel_error_per_sample)*100);
fprintf('  std: %.4f\n', std(rel_error_per_sample));
fprintf('  min: %.4f, max: %.4f\n', min(rel_error_per_sample), max(rel_error_per_sample));

%% 理论验证
% 对于乘性噪声 y_noisy = y_clean * (1 + noise), noise ~ N(0, sigma^2)
% 相对误差 = |y_noisy - y_clean| / |y_clean| = |noise|
% E[|noise|] = sigma * sqrt(2/pi)  (半正态分布的期望)
theoretical_mean_rel_error = noise_sigma * sqrt(2/pi);
fprintf('\n========== 理论验证 ==========\n');
fprintf('理论平均相对误差: %.4f (%.2f%%)\n', theoretical_mean_rel_error, theoretical_mean_rel_error*100);
fprintf('实测平均相对误差: %.4f (%.2f%%)\n', mean(rel_error_valid), mean(rel_error_valid)*100);
fprintf('误差: %.4f%%\n', abs(theoretical_mean_rel_error - mean(rel_error_valid))*100);

%% 可视化
figure('Position', [100, 100, 1200, 400]);

% 1. 相对误差分布直方图
subplot(1, 3, 1);
histogram(rel_error_valid, 50, 'Normalization', 'pdf', 'FaceColor', [0.3, 0.6, 0.9]);
hold on;
xline(mean(rel_error_valid), 'r-', 'LineWidth', 2, 'Label', sprintf('实测均值=%.3f', mean(rel_error_valid)));
xline(target_rel_error, 'g--', 'LineWidth', 2, 'Label', sprintf('目标=%.3f', target_rel_error));
xlabel('相对误差');
ylabel('概率密度');
title('相对误差分布');
legend('分布', '实测均值', '目标值');
xlim([0, 0.2]);
grid on;

% 2. 噪声分布
subplot(1, 3, 2);
histogram(noise(:), 50, 'Normalization', 'pdf', 'FaceColor', [0.9, 0.6, 0.3]);
hold on;
x_range = linspace(-0.3, 0.3, 100);
y_theory = normpdf(x_range, 0, noise_sigma);
plot(x_range, y_theory, 'r-', 'LineWidth', 2);
xlabel('噪声值');
ylabel('概率密度');
title(sprintf('噪声分布 (sigma=%.4f)', noise_sigma));
legend('实际分布', '理论正态分布');
grid on;

% 3. 逐通道相对误差
subplot(1, 3, 3);
boxplot(rel_error_element, 'Labels', arrayfun(@(x) sprintf('M%d', x), 1:K, 'UniformOutput', false));
hold on;
yline(target_rel_error, 'r--', 'LineWidth', 2);
xlabel('测量通道');
ylabel('相对误差');
title('逐通道相对误差分布');
grid on;

sgtitle(sprintf('噪声验证: 目标=%.1f%%, 实测=%.2f%%', target_rel_error*100, mean(rel_error_valid)*100));

saveas(gcf, 'noise_verification.png');
fprintf('\n已保存: noise_verification.png\n');

%% 额外测试：不同光谱亮度下的相对误差
fprintf('\n========== 不同亮度下的相对误差 ==========\n');
brightness_levels = [0.1, 0.3, 0.5, 0.7, 0.9];
for b = brightness_levels
    Y_b = b * rand(10000, n_channels);  % 亮度约为 b/2
    X_clean_b = Y_b * A';
    noise_b = noise_sigma * randn(10000, K);
    X_noisy_b = X_clean_b .* (1 + noise_b);
    X_noisy_b = max(X_noisy_b, 0);
    
    rel_error_b = abs(X_noisy_b - X_clean_b) ./ (abs(X_clean_b) + 1e-10);
    valid_b = abs(X_clean_b) > 0.01;
    
    fprintf('  亮度 ~%.1f: 平均相对误差 = %.4f (%.2f%%)\n', ...
        b/2, mean(rel_error_b(valid_b)), mean(rel_error_b(valid_b))*100);
end

fprintf('\n========== 完成 ==========\n');
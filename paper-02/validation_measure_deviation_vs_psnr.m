%% 噪声敏感性分析：不同噪声水平下的TV重建性能
% 对 y_theory 添加 0~10% 加性噪声，研究 RMSE 变化

clear; clc; close all;

%% ==================== 配置 ====================
mat_path = 'X:/Github/My-Repository/My-Graduation/data/mat';
base_path = 'X:/Github/My-Repository/My-Graduation/paper-02/data/1222/';
white_csv = [base_path, '新建文件5.csv'];
sample_csv = [base_path, '新建文件3.csv'];
skip_leds = [8, 9];
color_idx = 16;

% 噪声配置
noise_levels = 0:0.5:10;    % 噪声水平 0% ~ 10%，步长0.5%
num_trials = 50;            % 每个噪声水平重复次数

%% ==================== 构建系统 ====================
fprintf('构建系统矩阵...\n');
[A, A_info] = build_system_matrix(white_csv, 'SkipLEDs', skip_leds, 'A0Path', mat_path);
[x_gt, ~] = load_ground_truth(color_idx, 'ColorPath', mat_path);

% 计算无噪声理论值
y_clean = A * x_gt;

fprintf('系统矩阵: [%d × %d]\n', size(A, 1), size(A, 2));
fprintf('真值光谱: [%d × 1]\n', length(x_gt));
fprintf('测量值: [%d × 1]\n', length(y_clean));

%% ==================== 噪声分析 ====================
num_levels = length(noise_levels);

% 存储结果
rmse_mean = zeros(num_levels, 1);
rmse_std = zeros(num_levels, 1);
psnr_mean = zeros(num_levels, 1);
psnr_std = zeros(num_levels, 1);
y_rel_error_mean = zeros(num_levels, 1);  % 测量值相对误差
y_rel_error_std = zeros(num_levels, 1);

fprintf('\n开始噪声分析 (TV方法)...\n');
fprintf('噪声水平: %d 个 (%.1f%% ~ %.1f%%)\n', num_levels, noise_levels(1), noise_levels(end));
fprintf('重复次数: %d\n', num_trials);
fprintf('%s\n', repmat('=', 1, 70));

for i = 1:num_levels
    noise_pct = noise_levels(i);
    
    rmse_trials = zeros(num_trials, 1);
    psnr_trials = zeros(num_trials, 1);
    y_rel_error_trials = zeros(num_trials, 1);
    
    for t = 1:num_trials
        % 添加加性高斯噪声
        noise_sigma = (noise_pct / 100) * max(y_clean);
        noise = noise_sigma * randn(size(y_clean));
        y_noisy = y_clean + noise;
        
        % 确保非负
        y_noisy = max(y_noisy, 0);
        
        % 计算测量值相对误差: mean(|y_noisy - y_clean| / |y_clean|)
        y_rel_error_trials(t) = mean(abs(y_noisy - y_clean) ./ abs(y_clean)) * 100;
        
        % TV重建
        try
            [x_est, ~] = fdm_reconstruct(y_noisy, A, 'Method', 'tv');
            [rmse_val, psnr_val] = fdm_metrics(x_gt, x_est, 'Plot', false);
            
            rmse_trials(t) = rmse_val;
            psnr_trials(t) = psnr_val;
        catch
            rmse_trials(t) = NaN;
            psnr_trials(t) = NaN;
        end
    end
    
    % 统计
    rmse_mean(i) = mean(rmse_trials, 'omitnan');
    rmse_std(i) = std(rmse_trials, 'omitnan');
    psnr_mean(i) = mean(psnr_trials, 'omitnan');
    psnr_std(i) = std(psnr_trials, 'omitnan');
    y_rel_error_mean(i) = mean(y_rel_error_trials, 'omitnan');
    y_rel_error_std(i) = std(y_rel_error_trials, 'omitnan');
    
    fprintf('噪声 %5.1f%% → y相对误差 %5.1f%%: RMSE = %.4f ± %.4f, PSNR = %.2f dB\n', ...
            noise_pct, y_rel_error_mean(i), rmse_mean(i), rmse_std(i), psnr_mean(i));
end

%% ==================== 结果可视化 ====================
figure('Name', 'Noise Sensitivity - TV', 'Position', [100, 100, 1200, 800]);

% 上左：噪声水平 vs 测量值相对误差（对照表）
subplot(2, 2, 1);
plot(noise_levels, y_rel_error_mean, 'ko-', 'LineWidth', 2, 'MarkerSize', 6, 'MarkerFaceColor', 'k');
hold on;
% 标注对角线（理想情况：噪声% ≈ 相对误差%）
plot([0, 10], [0, 10] * mean(y_rel_error_mean ./ noise_levels', 'omitnan'), 'g--', 'LineWidth', 1);
xlabel('添加噪声水平 (%)');
ylabel('测量值平均相对误差 (%)');
title('噪声水平 → 测量值相对误差');
grid on;
xlim([noise_levels(1)-0.5, noise_levels(end)+0.5]);

% 上右：测量值相对误差 vs RMSE（关键图！）
subplot(2, 2, 2);
errorbar(y_rel_error_mean, rmse_mean, rmse_std, 'bo-', 'LineWidth', 1.5, 'MarkerSize', 6, 'MarkerFaceColor', 'b');
xlabel('测量值平均相对误差 (%)');
ylabel('重建 RMSE');
title('测量值相对误差 vs 重建RMSE');
grid on;

% 标注实际测量误差位置
hold on;
actual_error = 34;  % 之前分析的实际误差
xline(actual_error, 'r--', 'LineWidth', 2);
text(actual_error + 1, max(rmse_mean) * 0.9, sprintf('实际误差\n≈%.0f%%', actual_error), ...
     'Color', 'r', 'FontSize', 10);

% 下左：测量值相对误差 vs PSNR
subplot(2, 2, 3);
errorbar(y_rel_error_mean, psnr_mean, psnr_std, 'rs-', 'LineWidth', 1.5, 'MarkerSize', 6, 'MarkerFaceColor', 'r');
xlabel('测量值平均相对误差 (%)');
ylabel('PSNR (dB)');
title('测量值相对误差 vs 重建PSNR');
grid on;

% 下右：综合对比（双Y轴）
subplot(2, 2, 4);
yyaxis left;
plot(y_rel_error_mean, rmse_mean, 'b-o', 'LineWidth', 2, 'MarkerSize', 6);
ylabel('RMSE', 'Color', 'b');
ylim([0, max(rmse_mean) * 1.2]);

yyaxis right;
plot(y_rel_error_mean, psnr_mean, 'r-s', 'LineWidth', 2, 'MarkerSize', 6);
ylabel('PSNR (dB)', 'Color', 'r');

xlabel('测量值平均相对误差 (%)');
title('RMSE & PSNR vs 测量值相对误差');
grid on;
legend('RMSE', 'PSNR', 'Location', 'east');

sgtitle(sprintf('TV噪声敏感性分析 (色卡 #%d, %d次平均)', color_idx, num_trials));

%% ==================== 重建示例（带相对误差） ====================
figure('Name', 'TV Reconstruction Examples', 'Position', [100, 150, 1200, 350]);

example_noise = [0, 2, 5, 10];
wavelengths = linspace(400, 700, 31);

for i = 1:length(example_noise)
    noise_pct = example_noise(i);
    noise_sigma = (noise_pct / 100) * max(y_clean);
    y_noisy = y_clean + noise_sigma * randn(size(y_clean));
    y_noisy = max(y_noisy, 0);
    
    % 计算这次的相对误差
    y_rel_err = mean(abs(y_noisy - y_clean) ./ abs(y_clean)) * 100;
    
    [x_est, ~] = fdm_reconstruct(y_noisy, A, 'Method', 'tv');
    [rmse_val, psnr_val] = fdm_metrics(x_gt, x_est, 'Plot', false);
    
    subplot(1, 4, i);
    plot(wavelengths, x_gt, 'k-', 'LineWidth', 2, 'DisplayName', 'Ground Truth');
    hold on;
    plot(wavelengths, x_est, 'b--', 'LineWidth', 1.5, 'DisplayName', 'TV重建');
    hold off;
    
    xlabel('波长 (nm)');
    ylabel('反射率');
    title(sprintf('y误差=%.1f%%\nRMSE=%.3f, PSNR=%.1fdB', y_rel_err, rmse_val, psnr_val));
    legend('Location', 'best');
    grid on;
    ylim([0, max(x_gt) * 1.3]);
end

sgtitle('不同测量误差下的TV光谱重建');

%% ==================== 甜点分析 ====================
fprintf('\n%s\n', repmat('=', 1, 60));
fprintf('甜点分析\n');
fprintf('%s\n', repmat('=', 1, 60));

% 定义质量标准
rmse_threshold = 0.1;
psnr_threshold = 20;

fprintf('质量标准: RMSE < %.2f, PSNR > %.0f dB\n', rmse_threshold, psnr_threshold);

sweet_mask = (rmse_mean < rmse_threshold) & (psnr_mean > psnr_threshold);
if any(sweet_mask)
    sweet_y_error = max(y_rel_error_mean(sweet_mask));
    sweet_noise = max(noise_levels(sweet_mask));
    fprintf('\n甜点区域:\n');
    fprintf('  噪声水平: ≤ %.1f%%\n', sweet_noise);
    fprintf('  对应测量值相对误差: ≤ %.1f%%\n', sweet_y_error);
    fprintf('  在此范围内，RMSE = %.3f ~ %.3f\n', min(rmse_mean(sweet_mask)), max(rmse_mean(sweet_mask)));
    fprintf('  在此范围内，PSNR = %.1f ~ %.1f dB\n', min(psnr_mean(sweet_mask)), max(psnr_mean(sweet_mask)));
else
    fprintf('没有满足严格标准的甜点区域，放宽标准...\n');
    sweet_mask2 = (rmse_mean < 0.15) & (psnr_mean > 15);
    if any(sweet_mask2)
        fprintf('  放宽后甜点: 测量误差 ≤ %.1f%%\n', max(y_rel_error_mean(sweet_mask2)));
    end
end

% 与实际测量对比
fprintf('\n%s\n', repmat('-', 1, 60));
fprintf('与实际测量对比:\n');
fprintf('  实际测量相对误差: ~34%% (之前分析)\n');

% 外推估计
p = polyfit(y_rel_error_mean, rmse_mean, 2);
estimated_rmse_at_34 = polyval(p, 34);
fprintf('  外推估计: 34%%误差 → RMSE ≈ %.2f\n', estimated_rmse_at_34);
fprintf('  结论: 需要将测量误差降到 ≤%.0f%% 才能获得可接受的重建质量\n', ...
        max(y_rel_error_mean(sweet_mask)));
fprintf('%s\n', repmat('=', 1, 60));

%% ==================== 汇总表格 ====================
fprintf('\n%s\n', repmat('=', 1, 70));
fprintf('TV重建噪声敏感性汇总\n');
fprintf('%s\n', repmat('=', 1, 70));
fprintf('%10s %15s %12s %12s\n', '噪声(%)', 'y相对误差(%)', 'RMSE', 'PSNR(dB)');
fprintf('%s\n', repmat('-', 1, 70));
for i = 1:num_levels
    fprintf('%10.1f %15.1f %12.4f %12.2f\n', ...
            noise_levels(i), y_rel_error_mean(i), rmse_mean(i), psnr_mean(i));
end
fprintf('%s\n', repmat('=', 1, 70));

%% ==================== 保存结果 ====================
results.noise_levels = noise_levels;
results.y_rel_error_mean = y_rel_error_mean;
results.y_rel_error_std = y_rel_error_std;
results.rmse_mean = rmse_mean;
results.rmse_std = rmse_std;
results.psnr_mean = psnr_mean;
results.psnr_std = psnr_std;
results.num_trials = num_trials;
results.color_idx = color_idx;

save_path = fullfile(base_path, sprintf('noise_analysis_tv_color%d.mat', color_idx));
save(save_path, 'results');
fprintf('\n结果已保存到: %s\n', save_path);

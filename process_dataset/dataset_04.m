%% analyze_pixel_mat.m
% 分析聚类采样后的像素数据 (pixels_all.mat)
% 使用 5 种光谱指标: SAM, SID, ED, MSE, MRAE
%
% 用法:
%   直接运行此脚本，或修改 mat_path 路径

clear; clc; close all;

%% ======================== 配置 ========================
mat_path = 'W:\dataset\benchmark\pixel_data_clustered\pixels_all.mat';

%% ======================== 加载数据 ========================
fprintf('========================================\n');
fprintf('  像素数据集光谱分析\n');
fprintf('========================================\n\n');

fprintf('加载: %s\n\n', mat_path);
data = load(mat_path);

spectra = data.spectra;          % [N x B]
spectra_norm = data.spectra_norm;
dataset_id = data.dataset_id;
dataset_names = data.dataset_names;
is_center = data.is_center;

[N, B] = size(spectra);
num_datasets = length(dataset_names);

fprintf('数据概览:\n');
fprintf('  像素数: %d\n', N);
fprintf('  波段数: %d\n', B);
fprintf('  数据集: %d 个\n', num_datasets);
fprintf('  聚类中心: %d 个\n\n', sum(is_center));

%% ======================== 计算光谱指标 ========================
fprintf('计算光谱指标 (对比全局均值)...\n');

% 参考光谱 = 全局均值
ref = mean(spectra, 1);

% 预分配
SAM = zeros(N, 1);
SID = zeros(N, 1);
ED = zeros(N, 1);
MSE = zeros(N, 1);
MRAE = zeros(N, 1);

% 逐像素计算
for i = 1:N
    s = spectra(i, :);
    
    % SAM: 光谱角
    cos_val = dot(s, ref) / (norm(s) * norm(ref) + eps);
    cos_val = max(min(cos_val, 1), -1);  % clamp
    SAM(i) = acos(cos_val);
    
    % SID: 光谱信息散度
    p = s / (sum(s) + eps);
    q = ref / (sum(ref) + eps);
    p = max(p, eps);
    q = max(q, eps);
    SID(i) = sum(p .* log(p ./ q)) + sum(q .* log(q ./ p));
    
    % ED: 欧氏距离
    ED(i) = norm(s - ref);
    
    % MSE: 均方误差
    MSE(i) = mean((s - ref).^2);
    
    % MRAE: 平均相对绝对误差
    MRAE(i) = mean(abs(s - ref) ./ (abs(ref) + eps));
end

fprintf('完成!\n\n');

%% ======================== 全局统计 ========================
fprintf('========================================\n');
fprintf('  全局统计 (vs 均值光谱)\n');
fprintf('========================================\n\n');

fprintf('%-8s %10s %10s %10s %10s\n', '指标', '均值', '标准差', '最小', '最大');
fprintf('%s\n', repmat('-', 1, 50));
fprintf('%-8s %10.4f %10.4f %10.4f %10.4f\n', 'SAM', mean(SAM), std(SAM), min(SAM), max(SAM));
fprintf('%-8s %10.4f %10.4f %10.4f %10.4f\n', 'SID', mean(SID), std(SID), min(SID), max(SID));
fprintf('%-8s %10.4f %10.4f %10.4f %10.4f\n', 'ED', mean(ED), std(ED), min(ED), max(ED));
fprintf('%-8s %10.4f %10.4f %10.4f %10.4f\n', 'MSE', mean(MSE), std(MSE), min(MSE), max(MSE));
fprintf('%-8s %10.4f %10.4f %10.4f %10.4f\n', 'MRAE', mean(MRAE), std(MRAE), min(MRAE), max(MRAE));

%% ======================== 按数据集统计 ========================
fprintf('\n========================================\n');
fprintf('  按数据集统计\n');
fprintf('========================================\n\n');

for d = 1:num_datasets
    mask = (dataset_id == d);
    n_d = sum(mask);
    
    fprintf('[%d] %s (n=%d)\n', d, dataset_names{d}, n_d);
    fprintf('    SAM:  %.4f +/- %.4f\n', mean(SAM(mask)), std(SAM(mask)));
    fprintf('    SID:  %.4f +/- %.4f\n', mean(SID(mask)), std(SID(mask)));
    fprintf('    ED:   %.4f +/- %.4f\n', mean(ED(mask)), std(ED(mask)));
    fprintf('    MSE:  %.4f +/- %.4f\n', mean(MSE(mask)), std(MSE(mask)));
    fprintf('    MRAE: %.4f +/- %.4f\n', mean(MRAE(mask)), std(MRAE(mask)));
    fprintf('\n');
end

%% ======================== 可视化 ========================
fprintf('生成可视化...\n');

figure('Color', 'w', 'Position', [100, 100, 1500, 900], 'Name', '像素数据集分析');

colors = lines(num_datasets);

% 1. 各数据集光谱
subplot(2, 3, 1);
hold on;
for d = 1:num_datasets
    mask = (dataset_id == d);
    d_spectra = spectra(mask, :);
    n_show = min(50, size(d_spectra, 1));
    idx = randperm(size(d_spectra, 1), n_show);
    plot(d_spectra(idx, :)', 'Color', [colors(d,:), 0.3]);
end
plot(ref, 'k-', 'LineWidth', 3);
hold off;
xlabel('波段'); ylabel('反射率');
title('各数据集光谱 (黑线=全局均值)');
grid on;

% 2. SAM 分布
subplot(2, 3, 2);
hold on;
for d = 1:num_datasets
    mask = (dataset_id == d);
    histogram(SAM(mask), 30, 'FaceColor', colors(d,:), 'FaceAlpha', 0.5, 'EdgeColor', 'none');
end
hold off;
xlabel('SAM (rad)'); ylabel('计数');
title(sprintf('SAM 分布 (均值=%.4f)', mean(SAM)));
legend(dataset_names, 'Location', 'best');
grid on;

% 3. SID 分布
subplot(2, 3, 3);
hold on;
for d = 1:num_datasets
    mask = (dataset_id == d);
    histogram(SID(mask), 30, 'FaceColor', colors(d,:), 'FaceAlpha', 0.5, 'EdgeColor', 'none');
end
hold off;
xlabel('SID'); ylabel('计数');
title(sprintf('SID 分布 (均值=%.4f)', mean(SID)));
legend(dataset_names, 'Location', 'best');
grid on;

% 4. 各数据集 SAM 箱线图
subplot(2, 3, 4);
sam_group = [];
group_label = [];
for d = 1:num_datasets
    mask = (dataset_id == d);
    sam_group = [sam_group; SAM(mask)];
    group_label = [group_label; d * ones(sum(mask), 1)];
end
boxplot(sam_group, group_label, 'Labels', dataset_names);
ylabel('SAM (rad)');
title('SAM 按数据集分布');
grid on;

% 5. 各数据集均值光谱对比
subplot(2, 3, 5);
hold on;
for d = 1:num_datasets
    mask = (dataset_id == d);
    mean_spec = mean(spectra(mask, :), 1);
    std_spec = std(spectra(mask, :), 0, 1);
    
    x = 1:B;
    fill([x, fliplr(x)], [mean_spec+std_spec, fliplr(mean_spec-std_spec)], ...
         colors(d,:), 'FaceAlpha', 0.2, 'EdgeColor', 'none');
    plot(x, mean_spec, 'Color', colors(d,:), 'LineWidth', 2);
end
hold off;
xlabel('波段'); ylabel('反射率');
title('各数据集均值 +/- 标准差');
legend(dataset_names, 'Location', 'best');
grid on;

% 6. 指标相关性热图
subplot(2, 3, 6);
metrics_matrix = [SAM, SID, ED, MSE, MRAE];
metric_names_plot = {'SAM', 'SID', 'ED', 'MSE', 'MRAE'};
corr_matrix = corrcoef(metrics_matrix);

imagesc(corr_matrix);
colormap(gca, 'jet');
colorbar;
caxis([0, 1]);

set(gca, 'XTick', 1:5, 'XTickLabel', metric_names_plot);
set(gca, 'YTick', 1:5, 'YTickLabel', metric_names_plot);
title('指标相关性');

% 添加数值标注
for ii = 1:5
    for jj = 1:5
        text(jj, ii, sprintf('%.2f', corr_matrix(ii,jj)), ...
             'HorizontalAlignment', 'center', 'FontSize', 10, 'FontWeight', 'bold');
    end
end

sgtitle(sprintf('像素数据集分析 (N=%d, B=%d)', N, B), 'FontSize', 14);

% 保存图片
[folder, ~, ~] = fileparts(mat_path);
save_path = fullfile(folder, 'pixel_analysis_result.png');
saveas(gcf, save_path);
fprintf('\n图片已保存: %s\n', save_path);

fprintf('\n分析完成!\n');
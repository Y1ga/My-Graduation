%% kmeans_tutorial.m
% K-means 聚类原理演示 - 以高光谱像素为例
%
% 目标：
%   1. 理解 K-means 算法原理
%   2. 可视化聚类过程
%   3. 学会评估聚类质量
%
% 作者: [Your Name]
% 日期: 2024

clear; clc; close all;
rng(42);

%% ======================== Part 1: K-means 原理 ========================
fprintf('========================================\n');
fprintf('  Part 1: K-means 原理\n');
fprintf('========================================\n\n');

fprintf('K-means 是最简单的聚类算法，目标是把 N 个数据点分成 K 组。\n\n');

fprintf('算法步骤：\n');
fprintf('  1. 随机选择 K 个点作为初始"中心"\n');
fprintf('  2. 把每个数据点分配给最近的中心 → 形成 K 个簇\n');
fprintf('  3. 重新计算每个簇的中心（均值）\n');
fprintf('  4. 重复 2-3，直到中心不再变化\n\n');

fprintf('按任意键继续...\n');
pause;

%% ======================== Part 2: 2D 演示 ========================
fprintf('\n========================================\n');
fprintf('  Part 2: 2D 数据演示\n');
fprintf('========================================\n\n');

% 生成简单的 2D 数据 (3 个真实簇)
n_per_cluster = 100;
true_centers = [2, 2; 8, 3; 5, 8];
data_2d = [];
true_labels = [];

for i = 1:3
    cluster_data = true_centers(i, :) + randn(n_per_cluster, 2) * 0.8;
    data_2d = [data_2d; cluster_data];
    true_labels = [true_labels; i * ones(n_per_cluster, 1)];
end

fprintf('生成了 %d 个 2D 数据点，真实有 3 个簇\n\n', size(data_2d, 1));

% 可视化原始数据
figure('Color', 'w', 'Position', [100, 100, 1200, 400], 'Name', 'K-means 2D 演示');

subplot(1, 3, 1);
scatter(data_2d(:,1), data_2d(:,2), 30, true_labels, 'filled');
title('原始数据 (真实标签着色)');
xlabel('X'); ylabel('Y');
colormap(gca, lines(3));
grid on;

% 手动实现 K-means，记录每一步
K = 3;
max_iter = 10;

% 随机初始化中心
init_idx = randperm(size(data_2d, 1), K);
centers = data_2d(init_idx, :);

fprintf('初始中心坐标:\n');
disp(centers);

% 记录历史
centers_history = {centers};
labels_history = {};

for iter = 1:max_iter
    % Step 1: 分配标签 (找最近中心)
    dists = pdist2(data_2d, centers);  % [N x K] 距离矩阵
    [~, labels] = min(dists, [], 2);
    labels_history{iter} = labels;
    
    % Step 2: 更新中心
    new_centers = zeros(K, 2);
    for k = 1:K
        new_centers(k, :) = mean(data_2d(labels == k, :), 1);
    end
    
    % 检查收敛
    center_shift = norm(new_centers(:) - centers(:));
    fprintf('迭代 %d: 中心移动距离 = %.4f\n', iter, center_shift);
    
    centers = new_centers;
    centers_history{end+1} = centers;
    
    if center_shift < 1e-6
        fprintf('收敛！\n');
        break;
    end
end

% 可视化最终结果
subplot(1, 3, 2);
scatter(data_2d(:,1), data_2d(:,2), 30, labels, 'filled');
hold on;
plot(centers(:,1), centers(:,2), 'kx', 'MarkerSize', 15, 'LineWidth', 3);
hold off;
title(sprintf('K-means 结果 (K=%d)', K));
xlabel('X'); ylabel('Y');
colormap(gca, lines(3));
grid on;

% 可视化中心移动轨迹
subplot(1, 3, 3);
scatter(data_2d(:,1), data_2d(:,2), 20, [0.8 0.8 0.8], 'filled');
hold on;
colors = lines(K);
for k = 1:K
    % 画轨迹
    traj = zeros(length(centers_history), 2);
    for t = 1:length(centers_history)
        traj(t, :) = centers_history{t}(k, :);
    end
    plot(traj(:,1), traj(:,2), '-', 'Color', colors(k,:), 'LineWidth', 2);
    plot(traj(1,1), traj(1,2), 'o', 'Color', colors(k,:), 'MarkerSize', 10, 'LineWidth', 2);
    plot(traj(end,1), traj(end,2), 's', 'Color', colors(k,:), 'MarkerSize', 12, 'LineWidth', 2, 'MarkerFaceColor', colors(k,:));
end
hold off;
title('中心移动轨迹 (○=初始, ■=最终)');
xlabel('X'); ylabel('Y');
grid on;

fprintf('\n按任意键继续看高光谱数据...\n');
pause;

%% ======================== Part 3: 高光谱数据聚类 ========================
fprintf('\n========================================\n');
fprintf('  Part 3: 高光谱像素聚类\n');
fprintf('========================================\n\n');

% 加载一个场景
data_path = 'W:\dataset\Biospecimen';  % 修改为你的路径
mat_files = dir(fullfile(data_path, '*.mat'));

if isempty(mat_files)
    fprintf('未找到数据，使用模拟数据演示\n');
    % 模拟 31 波段高光谱数据
    H = 100; W = 100; B = 31;
    img = rand(H, W, B);
else
    fprintf('加载: %s\n', mat_files(1).name);
    tmp = load(fullfile(data_path, mat_files(1).name));
    fields = fieldnames(tmp);
    img = tmp.(fields{1});
    if size(img, 1) < size(img, 3)
        img = permute(img, [2, 3, 1]);
    end
    img = img(:,:,1:min(31, size(img,3)));
end

[H, W, B] = size(img);
fprintf('图像尺寸: %d x %d x %d (%d 像素)\n', H, W, B, H*W);

% 重塑并采样 (避免太慢)
data_full = reshape(double(img), H*W, B);
max_samples = 10000;
if size(data_full, 1) > max_samples
    sample_idx = randperm(size(data_full, 1), max_samples);
    data_sampled = data_full(sample_idx, :);
    fprintf('采样 %d 像素用于演示\n', max_samples);
else
    data_sampled = data_full;
    sample_idx = 1:size(data_full, 1);
end

% L2 归一化 (聚类关注形状)
data_norm = data_sampled ./ (sqrt(sum(data_sampled.^2, 2)) + eps);

%% ======================== Part 4: 如何选择 K？========================
fprintf('\n========================================\n');
fprintf('  Part 4: 如何选择 K (聚类数)？\n');
fprintf('========================================\n\n');

fprintf('常用方法：\n');
fprintf('  1. 肘部法则 (Elbow Method): 画 K vs 误差曲线，找拐点\n');
fprintf('  2. 轮廓系数 (Silhouette): 衡量聚类紧凑度和分离度\n');
fprintf('  3. 领域知识: 例如知道场景大约有多少种材质\n\n');

% 测试不同的 K
K_range = [5, 10, 20, 50, 100];
inertias = [];      % 簇内误差平方和 (越小越好)
silhouettes = [];   % 轮廓系数 (越大越好, 范围 [-1, 1])

fprintf('测试不同 K 值...\n');

for K = K_range
    fprintf('  K = %d ... ', K);
    
    [labels, centers, sumd] = kmeans(data_norm, K, 'MaxIter', 100, 'Replicates', 1, 'Display', 'off');
    
    % 簇内误差
    inertia = sum(sumd);
    inertias = [inertias; inertia];
    
    % 轮廓系数 (采样计算，否则太慢)
    sil_sample_idx = randperm(length(labels), min(1000, length(labels)));
    sil = silhouette(data_norm(sil_sample_idx, :), labels(sil_sample_idx));
    silhouettes = [silhouettes; mean(sil)];
    
    fprintf('误差=%.2f, 轮廓=%.3f\n', inertia, mean(sil));
end

% 可视化
figure('Color', 'w', 'Position', [100, 100, 1000, 400], 'Name', '选择最优 K');

subplot(1, 2, 1);
plot(K_range, inertias, 'bo-', 'LineWidth', 2, 'MarkerSize', 10, 'MarkerFaceColor', 'b');
xlabel('K (聚类数)');
ylabel('簇内误差 (Inertia)');
title('肘部法则 - 找拐点');
grid on;

% 标注
text(K_range + 2, inertias, string(round(inertias)), 'FontSize', 9);

subplot(1, 2, 2);
plot(K_range, silhouettes, 'ro-', 'LineWidth', 2, 'MarkerSize', 10, 'MarkerFaceColor', 'r');
xlabel('K (聚类数)');
ylabel('轮廓系数 (Silhouette)');
title('轮廓系数 - 越大越好');
grid on;
ylim([0, 1]);

% 找最优
[best_sil, best_idx] = max(silhouettes);
hold on;
plot(K_range(best_idx), best_sil, 'gs', 'MarkerSize', 15, 'LineWidth', 3);
hold off;
legend('轮廓系数', sprintf('最优 K=%d', K_range(best_idx)), 'Location', 'best');

fprintf('\n根据轮廓系数，推荐 K = %d\n', K_range(best_idx));

fprintf('\n按任意键继续...\n');
pause;

%% ======================== Part 5: 聚类质量评估 ========================
fprintf('\n========================================\n');
fprintf('  Part 5: 聚类质量评估指标\n');
fprintf('========================================\n\n');

% 使用一个固定的 K 进行详细分析
K = 50;
fprintf('使用 K = %d 进行聚类...\n', K);

[labels, centers, sumd] = kmeans(data_norm, K, 'MaxIter', 200, 'Replicates', 3, 'Display', 'off');

% === 指标 1: 簇内误差 (Inertia / Within-cluster sum of squares) ===
inertia = sum(sumd);
fprintf('\n1. 簇内误差 (Inertia): %.4f\n', inertia);
fprintf('   含义: 所有点到其聚类中心的距离平方和，越小说明簇越紧凑\n');

% === 指标 2: 轮廓系数 (Silhouette Coefficient) ===
sil_values = silhouette(data_norm, labels);
mean_sil = mean(sil_values);
fprintf('\n2. 轮廓系数: %.4f (范围 [-1, 1])\n', mean_sil);
fprintf('   含义: 衡量样本与自己簇的相似度 vs 与其他簇的相似度\n');
fprintf('   > 0.7: 强聚类结构\n');
fprintf('   > 0.5: 合理的聚类结构\n');
fprintf('   > 0.25: 弱聚类结构\n');
fprintf('   < 0.25: 可能没有实质性结构\n');

% === 指标 3: Davies-Bouldin 指数 ===
db_index = evalclusters(data_norm, labels, 'DaviesBouldin');
fprintf('\n3. Davies-Bouldin 指数: %.4f (越小越好)\n', db_index.CriterionValues);
fprintf('   含义: 簇内散度与簇间距离的比值，越小说明簇越紧凑且分离度越好\n');

% === 指标 4: Calinski-Harabasz 指数 ===
ch_index = evalclusters(data_norm, labels, 'CalinskiHarabasz');
fprintf('\n4. Calinski-Harabasz 指数: %.4f (越大越好)\n', ch_index.CriterionValues);
fprintf('   含义: 簇间离散度与簇内离散度的比值\n');

% === 指标 5: 类内/类间距离比 ===
% 计算类内平均距离
intra_dists = [];
for k = 1:K
    cluster_data = data_norm(labels == k, :);
    if size(cluster_data, 1) > 1
        D = pdist(cluster_data);
        intra_dists = [intra_dists; mean(D)];
    end
end
mean_intra = mean(intra_dists);

% 计算类间平均距离 (中心之间)
inter_dists = pdist(centers);
mean_inter = mean(inter_dists);

ratio = mean_inter / (mean_intra + eps);
fprintf('\n5. 类间/类内距离比: %.4f (越大越好)\n', ratio);
fprintf('   类内平均距离: %.4f\n', mean_intra);
fprintf('   类间平均距离: %.4f\n', mean_inter);

%% ======================== Part 6: 可视化聚类结果 ========================
fprintf('\n========================================\n');
fprintf('  Part 6: 可视化聚类结果\n');
fprintf('========================================\n\n');

figure('Color', 'w', 'Position', [100, 100, 1400, 800], 'Name', '高光谱聚类结果');

% 1. 各聚类中心光谱
subplot(2, 3, 1);
plot(centers', 'LineWidth', 0.5);
xlabel('波段');
ylabel('归一化反射率');
title(sprintf('所有聚类中心 (K=%d)', K));
grid on;

% 2. 轮廓图
subplot(2, 3, 2);
[sil_sorted, sort_idx] = sort(sil_values);
barh(sil_sorted, 'FaceColor', [0.4 0.6 0.8], 'EdgeColor', 'none');
xlabel('轮廓系数');
ylabel('像素');
title(sprintf('轮廓图 (均值=%.3f)', mean_sil));
xlim([-0.5, 1]);
xline(0, 'r--', 'LineWidth', 1.5);
xline(mean_sil, 'g-', 'LineWidth', 2);

% 3. 各簇大小分布
subplot(2, 3, 3);
cluster_sizes = histcounts(labels, 1:K+1);
bar(cluster_sizes, 'FaceColor', [0.3 0.5 0.7]);
xlabel('聚类 ID');
ylabel('像素数');
title('各聚类大小');
grid on;

% 4. 最大的 5 个簇的光谱
subplot(2, 3, 4);
[~, size_order] = sort(cluster_sizes, 'descend');
colors = lines(5);
hold on;
for i = 1:5
    k = size_order(i);
    cluster_data = data_sampled(labels == k, :);  % 原始光谱
    
    % 画均值和范围
    mean_spec = mean(cluster_data, 1);
    plot(mean_spec, 'Color', colors(i,:), 'LineWidth', 2);
end
hold off;
xlabel('波段');
ylabel('反射率');
title('最大 5 个簇的均值光谱');
legend(arrayfun(@(x) sprintf('簇%d (n=%d)', size_order(x), cluster_sizes(size_order(x))), 1:5, 'UniformOutput', false), 'Location', 'best');
grid on;

% 5. PCA 降维可视化
subplot(2, 3, 5);
[coeff, score] = pca(data_norm);
scatter(score(:,1), score(:,2), 10, labels, 'filled');
xlabel('PC1');
ylabel('PC2');
title('PCA 降维可视化');
colormap(gca, jet(K));
grid on;

% 6. t-SNE 降维可视化 (采样)
subplot(2, 3, 6);
tsne_n = min(2000, size(data_norm, 1));
tsne_idx = randperm(size(data_norm, 1), tsne_n);
fprintf('计算 t-SNE (n=%d)...\n', tsne_n);
Y = tsne(data_norm(tsne_idx, :), 'Perplexity', 30);
scatter(Y(:,1), Y(:,2), 10, labels(tsne_idx), 'filled');
xlabel('t-SNE 1');
ylabel('t-SNE 2');
title('t-SNE 降维可视化');
colormap(gca, jet(K));
grid on;

sgtitle(sprintf('K-means 聚类结果分析 (K=%d, 轮廓系数=%.3f)', K, mean_sil), 'FontSize', 14);

%% ======================== Part 7: 聚类结果应用 ========================
fprintf('\n========================================\n');
fprintf('  Part 7: 聚类结果应用于像素采样\n');
fprintf('========================================\n\n');

% 从每个簇提取代表性像素
samples_per_cluster = 3;
sampled_spectra = [];
sampled_labels = [];
is_center = [];

for k = 1:K
    cluster_mask = (labels == k);
    cluster_size = sum(cluster_mask);
    
    if cluster_size < 2
        continue;
    end
    
    cluster_data = data_sampled(cluster_mask, :);
    cluster_norm = data_norm(cluster_mask, :);
    center = centers(k, :);
    
    % 找最接近中心的点
    dists = sum((cluster_norm - center).^2, 2);
    [~, center_idx] = min(dists);
    
    % 添加中心
    sampled_spectra = [sampled_spectra; cluster_data(center_idx, :)];
    sampled_labels = [sampled_labels; k];
    is_center = [is_center; true];
    
    % 添加随机样本
    if cluster_size > 1
        n_extra = min(samples_per_cluster - 1, cluster_size - 1);
        other_idx = setdiff(1:cluster_size, center_idx);
        random_idx = other_idx(randperm(length(other_idx), n_extra));
        
        sampled_spectra = [sampled_spectra; cluster_data(random_idx, :)];
        sampled_labels = [sampled_labels; k * ones(n_extra, 1)];
        is_center = [is_center; false(n_extra, 1)];
    end
end

fprintf('原始像素数: %d\n', size(data_sampled, 1));
fprintf('采样后像素数: %d (%.2f%%)\n', size(sampled_spectra, 1), 100*size(sampled_spectra,1)/size(data_sampled,1));
fprintf('其中聚类中心: %d\n', sum(is_center));

% 可视化采样结果
figure('Color', 'w', 'Position', [100, 100, 1000, 400], 'Name', '采样结果');

subplot(1, 2, 1);
plot(data_sampled(1:min(500, end), :)', 'Color', [0.7 0.7 0.7 0.3]);
hold on;
plot(sampled_spectra(is_center, :)', 'r-', 'LineWidth', 1);
hold off;
xlabel('波段');
ylabel('反射率');
title('原始 vs 采样 (红=聚类中心)');
grid on;

subplot(1, 2, 2);
histogram(sampled_labels, K, 'FaceColor', [0.4 0.6 0.8]);
xlabel('聚类 ID');
ylabel('采样数');
title('各聚类采样分布');
grid on;

%% ======================== 总结 ========================
fprintf('\n========================================\n');
fprintf('  总结\n');
fprintf('========================================\n\n');

fprintf('K-means 聚类要点:\n');
fprintf('  1. 原理: 迭代分配 + 更新中心，最小化簇内误差\n');
fprintf('  2. 选 K: 肘部法则 + 轮廓系数\n');
fprintf('  3. 评估: 轮廓系数 > 0.5 通常是合理的聚类\n');
fprintf('  4. 应用: 从每个簇采样，大幅减少冗余\n\n');

fprintf('对于高光谱像素:\n');
fprintf('  - L2 归一化后聚类，关注光谱形状而非亮度\n');
fprintf('  - K = 50~100 通常能覆盖场景中的主要材质\n');
fprintf('  - 聚类后采样可将 26 万像素压缩到几百个代表性样本\n');
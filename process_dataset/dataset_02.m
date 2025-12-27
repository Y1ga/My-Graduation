%% extract_pixels_spectral_clustering.m
% 基于光谱聚类的像素采样 - 避免冗余，保证多样性
%
% 核心思想:
%   512x512 图像有 26 万像素，但可能只有几十种不同材质
%   对光谱进行聚类，每类取代表性像素，大幅减少冗余
%
% 采样策略:
%   1. 对每个场景的所有像素进行 K-means 光谱聚类
%   2. 每个聚类取: 类中心 + 若干随机样本
%   3. 保留类别标签，方便后续分析
%
% 作者: [Your Name]
% 日期: 2024

clear; clc; close all;
rng(42);  % 固定随机种子

%% ======================== 配置参数 ========================
config = struct();

% 数据集路径 (每个取前5个文件)
config.datasets = {
%   路径                          名称           波段数   波长范围          取前N个文件
    'W:\dataset\CAVE_MAT',       'CAVE',        31,      400:10:700,       5;
    'W:\dataset\50-Scenes',      '50Scenes',    31,      400:10:700,       5;
    'W:\dataset\KAIST_MAT',      'KAIST',       31,      420:10:720,       5;
    'W:\dataset\Biospecimen',    'Biospecimen', 31,      400:10:700,       5;
};

% 聚类参数
config.num_clusters = 100;          % 每个场景聚类数 (代表材质种类数)
config.samples_per_cluster = 5;     % 每个聚类采样数 (1=只取中心, >1=中心+随机)
config.min_cluster_size = 3;        % 最小聚类大小 (过滤噪声聚类)

% 预处理
config.normalize_spectra = true;    % 聚类前是否 L2 归一化 (关注形状而非强度)
config.min_intensity = 0.01;        % 过滤过暗像素
config.max_intensity = 0.99;        % 过滤过曝像素

% 训练/测试划分
config.train_ratio = 0.8;

% 输出
config.output_folder = 'W:\dataset\benchmark\pixel_data_clustered';
if ~exist(config.output_folder, 'dir')
    mkdir(config.output_folder);
end

%% ======================== 主程序 ========================
fprintf('========================================\n');
fprintf('  光谱聚类像素采样工具\n');
fprintf('========================================\n');
fprintf('聚类数: %d, 每类采样: %d\n', config.num_clusters, config.samples_per_cluster);
fprintf('预计每场景像素: ~%d\n\n', config.num_clusters * config.samples_per_cluster);

% 存储结果
all_spectra = [];           % [N x B] 光谱
all_spectra_norm = [];      % [N x B] 归一化光谱 (用于后续处理)
all_dataset_id = [];        % [N x 1] 数据集ID
all_scene_id = [];          % [N x 1] 场景ID
all_cluster_id = [];        % [N x 1] 聚类ID (场景内)
all_is_center = [];         % [N x 1] 是否聚类中心

scene_counter = 0;

% 遍历数据集
for d = 1:size(config.datasets, 1)
    dataset_path = config.datasets{d, 1};
    dataset_name = config.datasets{d, 2};
    num_bands = config.datasets{d, 3};
    wavelengths = config.datasets{d, 4};
    max_files = config.datasets{d, 5};
    
    fprintf('\n[数据集 %d/%d] %s\n', d, size(config.datasets,1), dataset_name);
    fprintf('路径: %s\n', dataset_path);
    fprintf('%s\n', repmat('-', 1, 50));
    
    % 获取 MAT 文件
    mat_files = dir(fullfile(dataset_path, '*.mat'));
    if isempty(mat_files)
        warning('未找到 MAT 文件，跳过');
        continue;
    end
    
    % 只取前 N 个
    mat_files = mat_files(1:min(max_files, length(mat_files)));
    fprintf('处理 %d 个场景\n\n', length(mat_files));
    
    for s = 1:length(mat_files)
        scene_counter = scene_counter + 1;
        filepath = fullfile(dataset_path, mat_files(s).name);
        
        fprintf('  [%d/%d] %s\n', s, length(mat_files), mat_files(s).name);
        
        try
            % 加载数据
            img = load_hsi_flexible(filepath, num_bands);
            [H, W, B] = size(img);
            fprintf('        尺寸: %dx%dx%d (%d 像素)\n', H, W, B, H*W);
            
            % 光谱聚类采样
            tic;
            [spectra, spectra_norm, cluster_ids, is_center] = ...
                cluster_and_sample(img, config);
            t = toc;
            
            num_sampled = size(spectra, 1);
            num_centers = sum(is_center);
            
            fprintf('        聚类采样: %d 像素 (%d 中心 + %d 样本), 耗时 %.2fs\n', ...
                    num_sampled, num_centers, num_sampled - num_centers, t);
            
            % 存储
            all_spectra = [all_spectra; spectra];
            all_spectra_norm = [all_spectra_norm; spectra_norm];
            all_dataset_id = [all_dataset_id; d * ones(num_sampled, 1)];
            all_scene_id = [all_scene_id; scene_counter * ones(num_sampled, 1)];
            all_cluster_id = [all_cluster_id; cluster_ids];
            all_is_center = [all_is_center; is_center];
            
        catch ME
            fprintf('        失败: %s\n', ME.message);
        end
    end
end

%% ======================== 统计信息 ========================
fprintf('\n========================================\n');
fprintf('  采样统计\n');
fprintf('========================================\n');

total_pixels = size(all_spectra, 1);
total_centers = sum(all_is_center);

fprintf('总像素数: %d\n', total_pixels);
fprintf('聚类中心: %d (%.1f%%)\n', total_centers, 100*total_centers/total_pixels);
fprintf('随机样本: %d (%.1f%%)\n', total_pixels - total_centers, 100*(1 - total_centers/total_pixels));

fprintf('\n各数据集分布:\n');
for d = 1:size(config.datasets, 1)
    mask = (all_dataset_id == d);
    count = sum(mask);
    centers = sum(all_is_center(mask));
    fprintf('  %s: %d 像素 (%d 中心)\n', config.datasets{d, 2}, count, centers);
end

%% ======================== 计算光谱多样性 ========================
fprintf('\n计算光谱多样性...\n');

% 计算类内/类间距离，验证聚类效果
diversity_stats = compute_diversity_stats(all_spectra_norm, all_scene_id, all_cluster_id);

fprintf('类内平均距离: %.4f\n', diversity_stats.intra_cluster_dist);
fprintf('类间平均距离: %.4f\n', diversity_stats.inter_cluster_dist);
fprintf('多样性比率 (越大越好): %.2f\n', diversity_stats.diversity_ratio);

%% ======================== 划分训练/测试集 ========================
fprintf('\n划分训练/测试集...\n');

% 按场景分层划分
unique_scenes = unique(all_scene_id);
train_idx = [];
test_idx = [];

for sc = unique_scenes'
    scene_mask = find(all_scene_id == sc);
    scene_mask = scene_mask(randperm(length(scene_mask)));
    
    n_train = round(length(scene_mask) * config.train_ratio);
    train_idx = [train_idx; scene_mask(1:n_train)];
    test_idx = [test_idx; scene_mask(n_train+1:end)];
end

% 构建输出结构
train_data = struct();
train_data.spectra = all_spectra(train_idx, :);
train_data.spectra_norm = all_spectra_norm(train_idx, :);
train_data.dataset_id = all_dataset_id(train_idx);
train_data.scene_id = all_scene_id(train_idx);
train_data.cluster_id = all_cluster_id(train_idx);
train_data.is_center = all_is_center(train_idx);
train_data.dataset_names = config.datasets(:, 2);
train_data.wavelengths = config.datasets{1, 4};  % 使用第一个数据集的波长
train_data.config = config;

test_data = struct();
test_data.spectra = all_spectra(test_idx, :);
test_data.spectra_norm = all_spectra_norm(test_idx, :);
test_data.dataset_id = all_dataset_id(test_idx);
test_data.scene_id = all_scene_id(test_idx);
test_data.cluster_id = all_cluster_id(test_idx);
test_data.is_center = all_is_center(test_idx);
test_data.dataset_names = config.datasets(:, 2);
test_data.wavelengths = config.datasets{1, 4};
test_data.config = config;

fprintf('训练集: %d 像素\n', length(train_idx));
fprintf('测试集: %d 像素\n', length(test_idx));

%% ======================== 保存 ========================
fprintf('\n保存数据...\n');

save(fullfile(config.output_folder, 'pixels_train.mat'), '-struct', 'train_data', '-v7.3');
save(fullfile(config.output_folder, 'pixels_test.mat'), '-struct', 'test_data', '-v7.3');

% 保存完整数据
all_data = struct();
all_data.spectra = all_spectra;
all_data.spectra_norm = all_spectra_norm;
all_data.dataset_id = all_dataset_id;
all_data.scene_id = all_scene_id;
all_data.cluster_id = all_cluster_id;
all_data.is_center = all_is_center;
all_data.dataset_names = config.datasets(:, 2);
all_data.wavelengths = config.datasets{1, 4};
all_data.config = config;
all_data.diversity_stats = diversity_stats;
save(fullfile(config.output_folder, 'pixels_all.mat'), '-struct', 'all_data', '-v7.3');

fprintf('保存完成: %s\n', config.output_folder);

%% ======================== 可视化 ========================
visualize_clustering_results(all_data, config);

fprintf('\n全部完成！\n');

%% ======================== 核心函数 ========================

function [spectra, spectra_norm, cluster_ids, is_center] = cluster_and_sample(img, config)
    % 对图像进行光谱聚类，然后从每个聚类采样
    % 针对大图像优化：先随机子采样再聚类
    %
    % 输出:
    %   spectra      - [N x B] 原始光谱
    %   spectra_norm - [N x B] 归一化光谱
    %   cluster_ids  - [N x 1] 聚类标签
    %   is_center    - [N x 1] 是否为聚类中心 (逻辑值)
    
    [H, W, B] = size(img);
    total_pixels = H * W;
    
    % === 大图像内存优化参数 ===
    max_pixels_for_clustering = 100000;   % 聚类时最大像素数 (10万)
    max_pixels_for_assignment = 500000;   % 分配标签时最大像素数 (50万)
    
    % 重塑为 2D
    data = reshape(double(img), total_pixels, B);
    
    % 计算亮度并过滤
    intensity = mean(data, 2);
    int_min = min(intensity);
    int_max = max(intensity);
    intensity_norm = (intensity - int_min) / (int_max - int_min + eps);
    
    valid_mask = (intensity_norm > config.min_intensity) & ...
                 (intensity_norm < config.max_intensity);
    valid_indices = find(valid_mask);
    num_valid = length(valid_indices);
    
    fprintf('        有效像素: %d (%.1f%%)\n', num_valid, 100*num_valid/total_pixels);
    
    if num_valid < config.num_clusters * 10
        warning('有效像素太少');
        valid_data = data(valid_mask, :);
        spectra = valid_data;
        spectra_norm = valid_data ./ (sqrt(sum(valid_data.^2, 2)) + eps);
        cluster_ids = (1:size(valid_data, 1))';
        is_center = true(size(valid_data, 1), 1);
        return;
    end
    
    % === 策略：子采样聚类 ===
    % 如果像素太多，先随机采样一部分用于聚类，然后把聚类中心应用到全部数据
    
    if num_valid > max_pixels_for_clustering
        fprintf('        大图像模式: 子采样 %d 像素用于聚类\n', max_pixels_for_clustering);
        
        % 随机采样用于聚类
        subsample_idx = randperm(num_valid, max_pixels_for_clustering);
        subsample_global_idx = valid_indices(subsample_idx);
        subsample_data = data(subsample_global_idx, :);
        
        % L2 归一化
        subsample_norm = subsample_data ./ (sqrt(sum(subsample_data.^2, 2)) + eps);
        
        % 在子样本上做 K-means
        num_clusters = min(config.num_clusters, floor(max_pixels_for_clustering / 50));
        fprintf('        K-means 聚类 (K=%d)...\n', num_clusters);
        
        [~, centers] = kmeans(subsample_norm, num_clusters, ...
            'MaxIter', 100, ...
            'Replicates', 1, ...  % 大数据只跑1次
            'Display', 'off');
        
        % 对有效像素分配聚类标签 (分批处理避免内存爆炸)
        fprintf('        分配聚类标签...\n');
        
        cluster_labels = zeros(num_valid, 1);
        batch_size = max_pixels_for_assignment;
        num_batches = ceil(num_valid / batch_size);
        
        for batch = 1:num_batches
            start_idx = (batch - 1) * batch_size + 1;
            end_idx = min(batch * batch_size, num_valid);
            
            batch_global_idx = valid_indices(start_idx:end_idx);
            batch_data = data(batch_global_idx, :);
            batch_norm = batch_data ./ (sqrt(sum(batch_data.^2, 2)) + eps);
            
            % 找最近的聚类中心
            % 使用矩阵运算: dist^2 = ||a||^2 + ||b||^2 - 2*a*b'
            % 由于都是单位向量，||a||^2 = ||b||^2 = 1
            % dist^2 = 2 - 2*a*b' = 2*(1 - cos_sim)
            cos_sim = batch_norm * centers';  % [batch x K]
            [~, batch_labels] = max(cos_sim, [], 2);
            
            cluster_labels(start_idx:end_idx) = batch_labels;
        end
        
        % 获取完整的有效数据
        valid_data = data(valid_indices, :);
        valid_data_norm = valid_data ./ (sqrt(sum(valid_data.^2, 2)) + eps);
        
    else
        % 小图像：直接聚类
        valid_data = data(valid_indices, :);
        valid_data_norm = valid_data ./ (sqrt(sum(valid_data.^2, 2)) + eps);
        
        num_clusters = min(config.num_clusters, floor(num_valid / 10));
        
        [cluster_labels, centers] = kmeans(valid_data_norm, num_clusters, ...
            'MaxIter', 200, ...
            'Replicates', 3, ...
            'Display', 'off');
    end
    
    % === 从每个聚类采样 ===
    spectra = [];
    spectra_norm = [];
    cluster_ids = [];
    is_center = [];
    
    unique_labels = unique(cluster_labels);
    
    for k = unique_labels'
        cluster_mask = (cluster_labels == k);
        cluster_size = sum(cluster_mask);
        
        if cluster_size < config.min_cluster_size
            continue;
        end
        
        cluster_local_idx = find(cluster_mask);
        cluster_spectra = valid_data(cluster_mask, :);
        cluster_spectra_norm = valid_data_norm(cluster_mask, :);
        
        % 找最接近中心的点
        center = centers(k, :);
        cos_sim = cluster_spectra_norm * center';
        [~, center_local_idx] = max(cos_sim);
        
        % 添加中心点
        spectra = [spectra; cluster_spectra(center_local_idx, :)];
        spectra_norm = [spectra_norm; cluster_spectra_norm(center_local_idx, :)];
        cluster_ids = [cluster_ids; k];
        is_center = [is_center; true];
        
        % 添加额外样本
        if config.samples_per_cluster > 1 && cluster_size > 1
            n_extra = min(config.samples_per_cluster - 1, cluster_size - 1);
            other_idx = setdiff(1:cluster_size, center_local_idx);
            sample_idx = other_idx(randperm(length(other_idx), n_extra));
            
            spectra = [spectra; cluster_spectra(sample_idx, :)];
            spectra_norm = [spectra_norm; cluster_spectra_norm(sample_idx, :)];
            cluster_ids = [cluster_ids; k * ones(n_extra, 1)];
            is_center = [is_center; false(n_extra, 1)];
        end
    end
    
    fprintf('        有效聚类: %d\n', length(unique(cluster_ids)));
end


function stats = compute_diversity_stats(spectra_norm, scene_ids, cluster_ids)
    % 计算光谱多样性统计
    
    stats = struct();
    
    % 采样计算 (避免内存爆炸)
    n = size(spectra_norm, 1);
    sample_size = min(2000, n);
    sample_idx = randperm(n, sample_size);
    
    sampled_spectra = spectra_norm(sample_idx, :);
    sampled_scene = scene_ids(sample_idx);
    sampled_cluster = cluster_ids(sample_idx);
    
    % 计算类内距离 (同场景同聚类)
    intra_dists = [];
    unique_scenes = unique(sampled_scene);
    
    for sc = unique_scenes'
        scene_mask = (sampled_scene == sc);
        scene_clusters = sampled_cluster(scene_mask);
        scene_spectra = sampled_spectra(scene_mask, :);
        
        unique_clusters = unique(scene_clusters);
        for cl = unique_clusters'
            cl_mask = (scene_clusters == cl);
            if sum(cl_mask) > 1
                cl_spectra = scene_spectra(cl_mask, :);
                % 计算类内两两距离
                D = pdist(cl_spectra, 'euclidean');
                intra_dists = [intra_dists; D(:)];
            end
        end
    end
    
    % 计算类间距离 (不同聚类)
    inter_dists = [];
    for i = 1:min(500, sample_size)
        for j = i+1:min(500, sample_size)
            if sampled_scene(i) ~= sampled_scene(j) || sampled_cluster(i) ~= sampled_cluster(j)
                d = norm(sampled_spectra(i,:) - sampled_spectra(j,:));
                inter_dists = [inter_dists; d];
            end
        end
    end
    
    stats.intra_cluster_dist = mean(intra_dists);
    stats.inter_cluster_dist = mean(inter_dists);
    stats.diversity_ratio = stats.inter_cluster_dist / (stats.intra_cluster_dist + eps);
end


function img = load_hsi_flexible(filepath, expected_bands)
    % 灵活加载高光谱数据
    
    data = load(filepath);
    
    var_names = {'hsi', 'HSI', 'cube', 'data', 'img', 'ref', 'rad', 'reflectance'};
    
    img = [];
    for i = 1:length(var_names)
        if isfield(data, var_names{i})
            candidate = data.(var_names{i});
            if ndims(candidate) == 3
                img = candidate;
                break;
            end
        end
    end
    
    if isempty(img)
        fields = fieldnames(data);
        max_size = 0;
        for i = 1:length(fields)
            candidate = data.(fields{i});
            if isnumeric(candidate) && ndims(candidate) == 3
                if numel(candidate) > max_size
                    max_size = numel(candidate);
                    img = candidate;
                end
            end
        end
    end
    
    if isempty(img)
        error('无法找到高光谱数据');
    end
    
    % 自动转置
    [d1, d2, d3] = size(img);
    if d1 < d2 && d1 < d3 && d1 < 100
        img = permute(img, [2, 3, 1]);
    end
    
    % 截取波段
    if size(img, 3) > expected_bands
        img = img(:, :, 1:expected_bands);
    end
    
    img = double(img);
    if max(img(:)) > 2
        img = img / max(img(:));
    end
end


function visualize_clustering_results(data, config)
    % 可视化聚类采样结果
    
    figure('Color', 'w', 'Position', [100, 100, 1600, 500], ...
           'Name', '光谱聚类采样结果');
    
    % 1. 数据集分布
    subplot(1, 4, 1);
    dataset_counts = histcounts(data.dataset_id, 1:size(config.datasets, 1)+1);
    bar(dataset_counts, 'FaceColor', [0.3 0.6 0.9]);
    set(gca, 'XTickLabel', config.datasets(:, 2), 'XTickLabelRotation', 30);
    ylabel('像素数');
    title('各数据集像素数');
    grid on;
    
    % 2. 聚类中心 vs 样本
    subplot(1, 4, 2);
    center_count = sum(data.is_center);
    sample_count = sum(~data.is_center);
    pie([center_count, sample_count], {'聚类中心', '类内样本'});
    title(sprintf('采样组成 (共%d)', center_count + sample_count));
    
    % 3. 聚类中心光谱 (每个数据集不同颜色)
    subplot(1, 4, 3);
    colors = lines(size(config.datasets, 1));
    hold on;
    
    center_mask = data.is_center;
    for d = 1:size(config.datasets, 1)
        mask = center_mask & (data.dataset_id == d);
        if any(mask)
            center_spectra = data.spectra_norm(mask, :);
            % 只画前 50 个
            n_show = min(50, size(center_spectra, 1));
            plot(center_spectra(1:n_show, :)', 'Color', [colors(d,:), 0.5], 'LineWidth', 0.5);
        end
    end
    hold off;
    xlabel('波段');
    ylabel('归一化反射率');
    title('聚类中心光谱');
    legend(config.datasets(1:size(config.datasets,1), 2), 'Location', 'best');
    grid on;
    
    % 4. t-SNE 可视化光谱分布
    subplot(1, 4, 4);
    
    % 采样一部分进行 t-SNE
    n_tsne = min(2000, size(data.spectra_norm, 1));
    tsne_idx = randperm(size(data.spectra_norm, 1), n_tsne);
    
    fprintf('计算 t-SNE...\n');
    Y = tsne(data.spectra_norm(tsne_idx, :), 'Perplexity', 30, 'NumDimensions', 2);
    
    % 按数据集着色
    gscatter(Y(:,1), Y(:,2), data.dataset_id(tsne_idx), colors, '.', 15);
    legend(config.datasets(1:size(config.datasets,1), 2), 'Location', 'best');
    title('t-SNE 光谱分布');
    xlabel('t-SNE 1');
    ylabel('t-SNE 2');
    axis equal;
    grid on;
    
    sgtitle(sprintf('光谱聚类采样: %d 像素 (多样性比: %.2f)', ...
                    size(data.spectra, 1), data.diversity_stats.diversity_ratio), ...
            'FontSize', 14);
    
    saveas(gcf, fullfile(config.output_folder, 'clustering_results.png'));
end
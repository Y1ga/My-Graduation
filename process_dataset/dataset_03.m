%% view_pixel_data.m
% 浏览和可视化提取的像素数据
%
% 用法:
%   直接运行查看所有数据
%   或调用单独函数

clear; clc; close all;

%% ======================== 加载数据 ========================
data_path = 'W:\dataset\benchmark\pixel_data_clustered\pixels_all.mat';

fprintf('加载数据: %s\n', data_path);
data = load(data_path);

% 显示基本信息
fprintf('\n========================================\n');
fprintf('  数据概览\n');
fprintf('========================================\n');
fprintf('总像素数: %d\n', size(data.spectra, 1));
fprintf('波段数: %d\n', size(data.spectra, 2));
fprintf('数据集数: %d\n', length(data.dataset_names));
fprintf('聚类中心数: %d\n', sum(data.is_center));

fprintf('\n各数据集:\n');
for d = 1:length(data.dataset_names)
    mask = (data.dataset_id == d);
    fprintf('  [%d] %s: %d 像素\n', d, data.dataset_names{d}, sum(mask));
end

%% ======================== 可视化 1: 各数据集光谱概览 ========================
figure('Color', 'w', 'Position', [100, 100, 1400, 800], 'Name', '各数据集光谱概览');

num_datasets = length(data.dataset_names);
colors = lines(num_datasets);

for d = 1:num_datasets
    subplot(2, 2, d);
    
    mask = (data.dataset_id == d);
    spectra_d = data.spectra(mask, :);
    
    % 随机选取一些光谱显示
    n_show = min(100, size(spectra_d, 1));
    show_idx = randperm(size(spectra_d, 1), n_show);
    
    % 绘制单条光谱 (半透明)
    hold on;
    for i = 1:n_show
        plot(spectra_d(show_idx(i), :), 'Color', [colors(d,:), 0.3], 'LineWidth', 0.5);
    end
    
    % 绘制均值 (粗线)
    mean_spec = mean(spectra_d, 1);
    plot(mean_spec, 'Color', colors(d,:), 'LineWidth', 2.5);
    hold off;
    
    xlabel('波段');
    ylabel('反射率');
    title(sprintf('%s (n=%d)', data.dataset_names{d}, sum(mask)));
    grid on;
    xlim([1, size(data.spectra, 2)]);
end

sgtitle('各数据集光谱分布 (细线=样本, 粗线=均值)', 'FontSize', 14);

%% ======================== 可视化 2: 所有数据集对比 ========================
figure('Color', 'w', 'Position', [100, 100, 1000, 500], 'Name', '数据集对比');

subplot(1, 2, 1);
hold on;
legend_entries = {};

for d = 1:num_datasets
    mask = (data.dataset_id == d);
    mean_spec = mean(data.spectra(mask, :), 1);
    std_spec = std(data.spectra(mask, :), 0, 1);
    
    x = 1:length(mean_spec);
    
    % 绘制均值±标准差
    fill([x, fliplr(x)], [mean_spec + std_spec, fliplr(mean_spec - std_spec)], ...
         colors(d,:), 'EdgeColor', 'none', 'FaceAlpha', 0.2);
    plot(x, mean_spec, 'Color', colors(d,:), 'LineWidth', 2);
    
    legend_entries{end+1} = data.dataset_names{d};
end
hold off;

xlabel('波段');
ylabel('反射率');
title('各数据集均值光谱对比');
legend(legend_entries, 'Location', 'best');
grid on;

% 统计直方图
subplot(1, 2, 2);
bar_data = zeros(num_datasets, 1);
for d = 1:num_datasets
    bar_data(d) = sum(data.dataset_id == d);
end
bar(bar_data, 'FaceColor', [0.4 0.6 0.8]);
set(gca, 'XTickLabel', data.dataset_names);
ylabel('像素数');
title('各数据集样本量');
grid on;

%% ======================== 可视化 3: 光谱多样性热图 ========================
figure('Color', 'w', 'Position', [100, 100, 800, 600], 'Name', '光谱热图');

% 按数据集排序
[~, sort_idx] = sort(data.dataset_id);
sorted_spectra = data.spectra_norm(sort_idx, :);
sorted_dataset = data.dataset_id(sort_idx);

% 只显示一部分 (太多会很慢)
max_show = 2000;
if size(sorted_spectra, 1) > max_show
    step = floor(size(sorted_spectra, 1) / max_show);
    show_idx = 1:step:size(sorted_spectra, 1);
    sorted_spectra = sorted_spectra(show_idx, :);
    sorted_dataset = sorted_dataset(show_idx);
end

imagesc(sorted_spectra);
colormap(hot);
colorbar;

xlabel('波段');
ylabel('像素 (按数据集排序)');
title('归一化光谱热图');

% 添加数据集分隔线
hold on;
for d = 1:num_datasets-1
    boundary = find(sorted_dataset == d, 1, 'last');
    if ~isempty(boundary)
        yline(boundary, 'w-', 'LineWidth', 2);
    end
end
hold off;

%% ======================== 可视化 4: 聚类中心 vs 样本 ========================
figure('Color', 'w', 'Position', [100, 100, 1000, 400], 'Name', '聚类中心 vs 样本');

% 聚类中心
subplot(1, 2, 1);
center_mask = data.is_center;
center_spectra = data.spectra(center_mask, :);

n_show = min(200, size(center_spectra, 1));
show_idx = randperm(size(center_spectra, 1), n_show);

hold on;
for d = 1:num_datasets
    d_mask = center_mask & (data.dataset_id == d);
    d_spectra = data.spectra(d_mask, :);
    n_d = min(50, size(d_spectra, 1));
    if n_d > 0
        plot(d_spectra(1:n_d, :)', 'Color', [colors(d,:), 0.5]);
    end
end
hold off;

xlabel('波段');
ylabel('反射率');
title(sprintf('聚类中心 (n=%d)', sum(center_mask)));
grid on;

% 非中心样本
subplot(1, 2, 2);
sample_mask = ~data.is_center;
sample_spectra = data.spectra(sample_mask, :);

hold on;
for d = 1:num_datasets
    d_mask = sample_mask & (data.dataset_id == d);
    d_spectra = data.spectra(d_mask, :);
    n_d = min(50, size(d_spectra, 1));
    if n_d > 0
        plot(d_spectra(1:n_d, :)', 'Color', [colors(d,:), 0.5]);
    end
end
hold off;

xlabel('波段');
ylabel('反射率');
title(sprintf('类内样本 (n=%d)', sum(sample_mask)));
grid on;

%% ======================== 可视化 5: 光谱统计 ========================
figure('Color', 'w', 'Position', [100, 100, 1200, 400], 'Name', '光谱统计');

% 各波段分布
subplot(1, 3, 1);
boxplot(data.spectra(:, 1:5:end), 'Labels', string(1:5:size(data.spectra,2)));
xlabel('波段 (每5个)');
ylabel('反射率');
title('各波段值分布');

% 亮度分布
subplot(1, 3, 2);
intensity = mean(data.spectra, 2);
histogram(intensity, 50, 'FaceColor', [0.4 0.6 0.8]);
xlabel('平均亮度');
ylabel('像素数');
title('亮度分布');
grid on;

% 光谱变异系数
subplot(1, 3, 3);
cv = std(data.spectra, 0, 2) ./ (mean(data.spectra, 2) + eps);
histogram(cv, 50, 'FaceColor', [0.8 0.5 0.3]);
xlabel('变异系数 (Std/Mean)');
ylabel('像素数');
title('光谱变异性分布');
grid on;

%% ======================== 交互式浏览 ========================
fprintf('\n========================================\n');
fprintf('  交互式浏览\n');
fprintf('========================================\n');
fprintf('输入像素索引 (1-%d) 查看光谱，输入 0 退出\n\n', size(data.spectra, 1));

while true
    idx = input('像素索引: ');
    
    if isempty(idx) || idx == 0
        break;
    end
    
    if idx < 1 || idx > size(data.spectra, 1)
        fprintf('无效索引！范围: 1-%d\n', size(data.spectra, 1));
        continue;
    end
    
    % 显示信息
    fprintf('  数据集: %s\n', data.dataset_names{data.dataset_id(idx)});
    fprintf('  场景ID: %d\n', data.scene_id(idx));
    fprintf('  聚类ID: %d\n', data.cluster_id(idx));
    fprintf('  是否中心: %s\n', mat2str(data.is_center(idx)));
    fprintf('  亮度: %.4f\n', mean(data.spectra(idx, :)));
    
    % 绘制
    figure('Position', [500, 300, 600, 400]);
    plot(data.spectra(idx, :), 'b-', 'LineWidth', 2);
    hold on;
    plot(data.spectra_norm(idx, :), 'r--', 'LineWidth', 1.5);
    hold off;
    
    xlabel('波段');
    ylabel('值');
    title(sprintf('像素 #%d (%s, Scene %d)', idx, data.dataset_names{data.dataset_id(idx)}, data.scene_id(idx)));
    legend('原始光谱', '归一化光谱');
    grid on;
end

fprintf('浏览结束。\n');

%% ======================== 辅助函数 ========================

function quick_stats(data)
    % 快速统计
    fprintf('\n=== 快速统计 ===\n');
    fprintf('光谱范围: [%.4f, %.4f]\n', min(data.spectra(:)), max(data.spectra(:)));
    fprintf('平均亮度: %.4f ± %.4f\n', mean(mean(data.spectra, 2)), std(mean(data.spectra, 2)));
    fprintf('场景数: %d\n', length(unique(data.scene_id)));
end
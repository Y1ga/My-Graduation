%% dataset_01_optimized: 50-Scenes 高光谱数据集分析
% 功能: 批量计算光谱差异指标 (SAM/SID/ED)，分析场景复杂度
% 优化: 模块化结构、消除重复代码、统一命名规范
% 作者: [Your Name]
% 日期: 2024

clear; clc; close all;

%% ======================== 配置参数 ========================
config = struct();
config.data_folder = "W:\dataset\50-Scenes\";
config.save_folder = "W:\dataset\50-Scenes\Results_Analysis\";
config.num_scenes = 50;
config.num_bands = 31;          % 使用前31个波段 (400-700nm)
config.save_figures = true;     % 是否保存结果图片

% 创建输出目录
if ~exist(config.save_folder, 'dir')
    mkdir(config.save_folder);
end
%% 

%% 
% 场景1: 快速分析一个文件
% analyze_single_hsi('W:\dataset\CAVE_MAT\balloons_ms.mat');
% analyze_single_hsi('W:\expriment\2025\scenes_output\scene31.mat');
analyze_single_hsi('W:\dataset\KAIST_MAT\scene03.mat');
% % 场景2: 检查未知格式的文件
% inspect_mat_file('W:\dataset\new_data.mat');
% % 输出:
% % 变量: cube               | 类型: double     | 尺寸: [31 512 512]
% %   └─ [可能是高光谱数据] 格式: B x H x W (需转置)
% 
% 场景3: 批量处理自定义数据集
% files = dir('W:\expriment\2025\scenes_output\*.mat');
% for i = 1:length(files)
%     [~, stats(i,:)] = analyze_single_hsi(fullfile(files(i).folder, files(i).name), 31, false);
% end
%% ======================== 主程序 ========================
fprintf('========================================\n');
fprintf('  50-Scenes 高光谱数据集分析\n');
fprintf('========================================\n\n');

% Step 1: 批量处理所有场景
stats_results = batch_process_scenes(config);

% Step 2: 分析并可视化结果
analyze_and_visualize(stats_results, config);

fprintf('\n处理完成！结果已保存至: %s\n', config.save_folder);

%% ======================== 核心函数 ========================

function stats = batch_process_scenes(config)
    % 批量处理所有场景，计算五种光谱差异指标
    % 输出: stats - [num_scenes x 5] 矩阵
    %       列顺序: [SAM_std, SID_std, ED_std, MSE_std, MRAE_std]
    
    stats = zeros(config.num_scenes, 5);
    
    fprintf('开始批量处理 %d 个场景...\n\n', config.num_scenes);
    
    for i = 1:config.num_scenes
        % 构建文件路径
        filename = sprintf('hsi_%d.mat', i);
        filepath = fullfile(config.data_folder, filename);
        
        % 检查文件是否存在
        if ~isfile(filepath)
            fprintf('[%2d/%d] 跳过: %s 不存在\n', i, config.num_scenes, filename);
            continue;
        end
        
        fprintf('[%2d/%d] 处理: %s ... ', i, config.num_scenes, filename);
        
        % 加载数据
        img = load_hsi_data(filepath, config.num_bands);
        
        % 计算五种差异指标
        metrics = compute_spectral_metrics(img);
        
        % 记录统计信息（标准差代表场景丰富度）
        stats(i, :) = [std(metrics.sam(:)), std(metrics.sid(:)), ...
                       std(metrics.ed(:)), std(metrics.mse(:)), std(metrics.mrae(:))];
        
        % 保存可视化结果
        if config.save_figures
            save_comparison_figure(metrics, i, config.save_folder);
        end
        
        fprintf('完成 (SID=%.4f, MRAE=%.4f)\n', stats(i, 2), stats(i, 5));
    end
    
    % 保存统计数据
    save(fullfile(config.save_folder, 'Statistics.mat'), 'stats');
    fprintf('\n统计数据已保存。\n');
end


function img = load_hsi_data(filepath, num_bands)
    % 加载高光谱数据，自动识别变量名和数据格式
    % 输入: filepath - MAT文件路径
    %       num_bands - 截取的波段数 (可选，默认不截取；设为 [] 或 0 表示使用全部波段)
    % 输出: img - [H x W x B] 高光谱图像
    %
    % 支持的格式:
    %   - 常见变量名: hsi, HSI, cube, data, img, image, ref, rad 等
    %   - 自动检测 3D 数组 (H x W x B)
    %   - 自动处理 (B x H x W) 格式并转置
    %   - 支持 HDF5 格式的 v7.3 MAT 文件
    
    % 参数处理
    if nargin < 2 || isempty(num_bands) || num_bands <= 0
        num_bands = inf;  % 使用全部波段
    end
    
    % 加载 MAT 文件
    try
        tmp = load(filepath);
    catch ME
        error('无法加载文件 "%s": %s', filepath, ME.message);
    end
    
    % 查找高光谱数据
    img_full = find_hsi_variable(tmp, filepath);
    
    % 验证数据维度
    if ndims(img_full) ~= 3
        error('数据维度错误: 期望 3D 数组，实际为 %dD', ndims(img_full));
    end
    
    % 自动检测并修正数据排列 (处理 B x H x W 的情况)
    img_full = auto_permute_hsi(img_full);
    
    % 截取指定波段数
    [~, ~, B] = size(img_full);
    if num_bands < B
        img = img_full(:, :, 1:num_bands);
    else
        img = img_full;
    end
    
    % 确保数据类型为 double
    if ~isa(img, 'double')
        img = double(img);
    end
end


function data = find_hsi_variable(mat_struct, filepath)
    % 从 MAT 结构体中查找高光谱数据变量
    % 优先级: 常见变量名 > 最大的 3D 数组
    
    vars = fieldnames(mat_struct);
    
    if isempty(vars)
        error('文件 "%s" 中没有找到任何变量', filepath);
    end
    
    % 常见的高光谱变量名 (按优先级排序)
    common_names = {'hsi', 'HSI', 'cube', 'Cube', 'data', 'Data', ...
                    'img', 'image', 'Image', 'ref', 'rad', 'radiance', ...
                    'reflectance', 'hypercube', 'spec', 'spectral','transmittance'};
    
    % 策略1: 按常见变量名查找
    for i = 1:length(common_names)
        if isfield(mat_struct, common_names{i})
            candidate = mat_struct.(common_names{i});
            if isnumeric(candidate) && ndims(candidate) == 3
                data = candidate;
                return;
            end
        end
    end
    
    % 策略2: 查找最大的 3D 数值数组
    max_size = 0;
    data = [];
    
    for i = 1:length(vars)
        candidate = mat_struct.(vars{i});
        if isnumeric(candidate) && ndims(candidate) == 3
            current_size = numel(candidate);
            if current_size > max_size
                max_size = current_size;
                data = candidate;
            end
        end
    end
    
    if isempty(data)
        % 列出所有变量供调试
        var_info = cell(length(vars), 1);
        for i = 1:length(vars)
            v = mat_struct.(vars{i});
            var_info{i} = sprintf('  %s: %s [%s]', vars{i}, class(v), ...
                                  strjoin(string(size(v)), 'x'));
        end
        error('未找到 3D 高光谱数据。文件包含的变量:\n%s', strjoin(var_info, '\n'));
    end
end


function img = auto_permute_hsi(img)
    % 自动检测并修正数据排列
    % 假设: 空间维度 (H, W) 通常 > 波段数 (B)
    % 常见格式: (H x W x B) 或 (B x H x W)
    
    [d1, d2, d3] = size(img);
    
    % 启发式判断: 最小的维度很可能是波段数
    dims = [d1, d2, d3];
    [~, min_idx] = min(dims);
    
    % 如果第一个维度最小，可能是 (B x H x W) 格式
    if min_idx == 1 && d1 < 100  % 波段数通常 < 100
        warning('检测到可能的 (B x H x W) 格式，自动转置为 (H x W x B)');
        img = permute(img, [2, 3, 1]);
    % 如果第二个维度最小，可能是 (H x B x W) 格式 (罕见)
    elseif min_idx == 2 && d2 < 100
        warning('检测到可能的 (H x B x W) 格式，自动转置为 (H x W x B)');
        img = permute(img, [1, 3, 2]);
    end
    % 否则假设已经是 (H x W x B) 格式
end


function metrics = compute_spectral_metrics(img)
    % 计算五种光谱差异指标
    % 输入: img - [H x W x B] 高光谱图像
    % 输出: metrics - 结构体，包含各指标的 [H x W] 差异图
    %       .sam  - 光谱角 (Spectral Angle Mapper)
    %       .sid  - 信息散度 (Spectral Information Divergence)  
    %       .ed   - 欧氏距离 (Euclidean Distance, L2范数)
    %       .mse  - 均方误差 (Mean Squared Error)
    %       .mrae - 平均相对绝对误差 (Mean Relative Absolute Error)
    
    [H, W, B] = size(img);
    
    % 预处理：重塑为2D并确保非负
    data = reshape(double(img), H*W, B);
    data(data < 0) = 0;
    
    % 计算平均光谱作为基准
    target = mean(data, 1);
    
    % 1. SAM (光谱角) - 对光照不敏感，纯形状差异
    metrics.sam = reshape(compute_sam(data, target), H, W);
    
    % 2. SID (信息散度) - 灵敏度最高，概率分布差异
    metrics.sid = reshape(compute_sid(data, target), H, W);
    
    % 3. ED (欧氏距离/L2范数) - 绝对数值差异
    metrics.ed = reshape(compute_euclidean(data, target), H, W);
    
    % 4. MSE (均方误差) - 光谱重建常用，对大误差敏感
    metrics.mse = reshape(compute_mse(data, target), H, W);
    
    % 5. MRAE (平均相对绝对误差) - 光谱重建标准指标，对暗区敏感
    metrics.mrae = reshape(compute_mrae(data, target), H, W);
end


function sam = compute_sam(data, target)
    % 计算光谱角 (Spectral Angle Mapper)
    % 输入: data - [N x B], target - [1 x B]
    % 输出: sam - [N x 1] 角度值（弧度）
    
    dot_prod = data * target';
    norm_data = sqrt(sum(data.^2, 2));
    norm_target = sqrt(sum(target.^2));
    
    cos_val = dot_prod ./ (norm_data * norm_target + eps);
    cos_val = max(min(cos_val, 1), -1);  % 限制在 [-1, 1]
    
    sam = acos(cos_val);
end


function sid = compute_sid(data, target)
    % 计算光谱信息散度 (Spectral Information Divergence)
    % 输入: data - [N x B], target - [1 x B]
    % 输出: sid - [N x 1] 散度值
    
    % 归一化为概率分布
    p = data ./ (sum(data, 2) + eps) + eps;
    q = target ./ (sum(target) + eps) + eps;
    
    % KL散度：SID = D(p||q) + D(q||p)
    term1 = sum(p .* log(p ./ q), 2);
    term2 = sum(q .* log(q ./ p), 2);
    
    sid = term1 + term2;
end


function ed = compute_euclidean(data, target)
    % 计算欧氏距离 (L2范数)
    % 输入: data - [N x B], target - [1 x B]
    % 输出: ed - [N x 1] 距离值
    
    diff = data - target;
    ed = sqrt(sum(diff.^2, 2));
end


function mse = compute_mse(data, target)
    % 计算均方误差 (Mean Squared Error)
    % 输入: data - [N x B], target - [1 x B]
    % 输出: mse - [N x 1] MSE值
    % 公式: MSE = (1/B) * sum((x - y)^2)
    
    B = size(data, 2);
    diff = data - target;
    mse = sum(diff.^2, 2) / B;
end


function mrae = compute_mrae(data, target)
    % 计算平均相对绝对误差 (Mean Relative Absolute Error)
    % 输入: data - [N x B], target - [1 x B]
    % 输出: mrae - [N x 1] MRAE值
    % 公式: MRAE = (1/B) * sum(|x - y| / (|y| + eps))
    % 注意: 对暗区（target值小）更敏感
    
    B = size(data, 2);
    diff = abs(data - target);
    mrae = sum(diff ./ (abs(target) + eps), 2) / B;
end


function save_comparison_figure(metrics, scene_id, save_folder)
    % 保存五种指标的对比图 (2行3列布局)
    
    f = figure('Visible', 'off', 'Position', [0, 0, 1500, 800]);
    
    % 第一行：SAM, SID, ED
    subplot(2,3,1);
    imagesc(metrics.sam); axis image; colormap(gca, jet); colorbar;
    title(sprintf('Scene %d - SAM (光谱角)', scene_id));
    
    subplot(2,3,2);
    imagesc(metrics.sid); axis image; colormap(gca, jet); colorbar;
    title(sprintf('Scene %d - SID (信息散度)', scene_id));
    
    subplot(2,3,3);
    imagesc(metrics.ed); axis image; colormap(gca, jet); colorbar;
    title(sprintf('Scene %d - ED (欧氏距离)', scene_id));
    
    % 第二行：MSE, MRAE, 空白/说明
    subplot(2,3,4);
    imagesc(metrics.mse); axis image; colormap(gca, jet); colorbar;
    title(sprintf('Scene %d - MSE (均方误差)', scene_id));
    
    subplot(2,3,5);
    imagesc(metrics.mrae); axis image; colormap(gca, jet); colorbar;
    title(sprintf('Scene %d - MRAE (相对误差)', scene_id));
    
    % 第6格：显示指标说明
    subplot(2,3,6);
    axis off;
    text(0.1, 0.8, '指标说明:', 'FontSize', 12, 'FontWeight', 'bold');
    text(0.1, 0.65, 'SAM: 光谱形状差异 (光照不敏感)', 'FontSize', 10);
    text(0.1, 0.50, 'SID: 概率分布差异 (灵敏度最高)', 'FontSize', 10);
    text(0.1, 0.35, 'ED: L2范数 (绝对数值差异)', 'FontSize', 10);
    text(0.1, 0.20, 'MSE: 均方误差 (对大误差敏感)', 'FontSize', 10);
    text(0.1, 0.05, 'MRAE: 相对误差 (对暗区敏感)', 'FontSize', 10);
    
    sgtitle(sprintf('Scene %d - 光谱差异指标对比', scene_id), 'FontSize', 14);
    
    saveas(f, fullfile(save_folder, sprintf('Result_Scene_%02d.png', scene_id)));
    close(f);
end


function analyze_and_visualize(stats, config)
    % 分析结果并生成可视化
    
    fprintf('\n========================================\n');
    fprintf('  结果分析\n');
    fprintf('========================================\n');
    
    metric_names = {'SAM', 'SID', 'ED', 'MSE', 'MRAE'};
    
    % 输出各指标的最复杂/最简单场景
    fprintf('\n各指标分析 (标准差越大 = 场景越复杂):\n');
    fprintf('%-6s | %8s | %8s | %12s | %12s\n', ...
            '指标', '最复杂', '最简单', '最大Std', '最小Std');
    fprintf('%s\n', repmat('-', 1, 55));
    
    for m = 1:5
        [max_val, max_idx] = max(stats(:, m));
        [min_val, min_idx] = min(stats(:, m));
        fprintf('%-6s | %8d | %8d | %12.6f | %12.6f\n', ...
                metric_names{m}, max_idx, min_idx, max_val, min_val);
    end
    
    % 使用 SID 作为主要指标进行可视化
    sid_stds = stats(:, 2);
    [max_val, max_idx] = max(sid_stds);
    [min_val, min_idx] = min(sid_stds);
    
    fprintf('\n主要结论 (基于SID):\n');
    fprintf('  最复杂场景: hsi_%d (SID Std = %.4f)\n', max_idx, max_val);
    fprintf('  最简单场景: hsi_%d (SID Std = %.4f)\n', min_idx, min_val);
    
    % 可视化 1: 场景丰富度排名 (多指标)
    plot_richness_ranking_multi(stats, metric_names, config.save_folder);
    
    % 可视化 2: 最复杂 vs 最简单场景对比
    plot_scene_comparison(max_idx, min_idx, max_val, min_val, config);
end


function plot_richness_ranking_multi(stats, metric_names, save_folder)
    % 绘制50个场景的多指标丰富度排名
    
    f = figure('Color', 'w', 'Position', [100, 100, 1400, 800]);
    
    for m = 1:5
        subplot(2, 3, m);
        
        metric_data = stats(:, m);
        [max_val, max_idx] = max(metric_data);
        [min_val, min_idx] = min(metric_data);
        
        % 创建柱状图
        bar_colors = repmat([0.7 0.8 0.9], 50, 1);
        bar_colors(max_idx, :) = [0.8 0.2 0.2];  % 红色
        bar_colors(min_idx, :) = [0.2 0.6 0.2];  % 绿色
        
        b = bar(1:50, metric_data);
        b.FaceColor = 'flat';
        b.CData = bar_colors;
        
        grid on;
        xlabel('Scene ID');
        ylabel([metric_names{m} ' Std']);
        title(sprintf('%s - 最复杂:#%d, 最简单:#%d', metric_names{m}, max_idx, min_idx));
    end
    
    % 第6格：相关性热图
    subplot(2, 3, 6);
    corr_matrix = corrcoef(stats);
    imagesc(corr_matrix);
    colormap(gca, hot); colorbar;
    set(gca, 'XTick', 1:5, 'XTickLabel', metric_names);
    set(gca, 'YTick', 1:5, 'YTickLabel', metric_names);
    title('指标相关性矩阵');
    axis square;
    
    % 在热图上显示数值
    for i = 1:5
        for j = 1:5
            text(j, i, sprintf('%.2f', corr_matrix(i,j)), ...
                'HorizontalAlignment', 'center', 'Color', 'w', 'FontSize', 8);
        end
    end
    
    sgtitle('50个场景光谱变异性分析 (红=最复杂, 绿=最简单)', 'FontSize', 14);
    
    saveas(f, fullfile(save_folder, 'Richness_Ranking_MultiMetric.png'));
    fprintf('多指标丰富度排名图已保存。\n');
end


function plot_scene_comparison(complex_id, simple_id, max_val, min_val, config)
    % 绘制最复杂与最简单场景的对比图
    
    fprintf('正在生成场景对比图...\n');
    
    % 加载数据
    img_complex = load_hsi_data(...
        fullfile(config.data_folder, sprintf('hsi_%d.mat', complex_id)), ...
        config.num_bands);
    img_simple = load_hsi_data(...
        fullfile(config.data_folder, sprintf('hsi_%d.mat', simple_id)), ...
        config.num_bands);
    
    % 计算指标
    metrics_complex = compute_spectral_metrics(img_complex);
    metrics_simple = compute_spectral_metrics(img_simple);
    
    % 绘图 - 显示 SID 和 MRAE 两个关键指标
    f = figure('Color', 'w', 'Position', [100, 100, 1200, 800]);
    
    % 第一行：SID 对比
    subplot(2, 2, 1);
    imagesc(metrics_complex.sid);
    colormap(gca, jet); colorbar; axis image;
    title({sprintf('Scene %d - SID (最复杂)', complex_id), ...
           sprintf('Std: %.4f', max_val)});
    
    subplot(2, 2, 2);
    imagesc(metrics_simple.sid);
    colormap(gca, jet); colorbar; axis image;
    title({sprintf('Scene %d - SID (最简单)', simple_id), ...
           sprintf('Std: %.4f', min_val)});
    
    % 第二行：MRAE 对比
    subplot(2, 2, 3);
    imagesc(metrics_complex.mrae);
    colormap(gca, jet); colorbar; axis image;
    title(sprintf('Scene %d - MRAE', complex_id));
    xlabel('相对误差分布');
    
    subplot(2, 2, 4);
    imagesc(metrics_simple.mrae);
    colormap(gca, jet); colorbar; axis image;
    title(sprintf('Scene %d - MRAE', simple_id));
    xlabel('相对误差分布');
    
    sgtitle({'光谱差异图对比 (颜色越红 = 像素越独特)', ...
             '上: SID (信息散度), 下: MRAE (相对误差)'}, 'FontSize', 12);
    
    saveas(f, fullfile(config.save_folder, 'Scene_Comparison.png'));
    fprintf('场景对比图已保存。\n');
end


%% ======================== 便捷工具函数 ========================

function [metrics, stats] = analyze_single_hsi(filepath, num_bands, show_plot)
    % 分析单个高光谱文件的便捷函数
    % 
    % 用法:
    %   [metrics, stats] = analyze_single_hsi('path/to/file.mat')
    %   [metrics, stats] = analyze_single_hsi('path/to/file.mat', 31)
    %   [metrics, stats] = analyze_single_hsi('path/to/file.mat', [], true)
    %
    % 输入:
    %   filepath  - MAT 文件路径
    %   num_bands - 使用的波段数 (可选，默认全部波段)
    %   show_plot - 是否显示可视化 (可选，默认 true)
    %
    % 输出:
    %   metrics - 结构体，包含各指标的 [H x W] 差异图
    %   stats   - [1 x 5] 向量，各指标的标准差
    
    % 参数默认值
    if nargin < 2, num_bands = []; end
    if nargin < 3, show_plot = true; end
    
    % 加载数据
    fprintf('加载文件: %s\n', filepath);
    img = load_hsi_data(filepath, num_bands);
    [H, W, B] = size(img);
    fprintf('数据尺寸: %d x %d x %d\n', H, W, B);
    
    % 计算指标
    fprintf('计算光谱差异指标...\n');
    metrics = compute_spectral_metrics(img);
    
    % 统计信息
    stats = [std(metrics.sam(:)), std(metrics.sid(:)), ...
             std(metrics.ed(:)), std(metrics.mse(:)), std(metrics.mrae(:))];
    
    % 打印结果
    metric_names = {'SAM', 'SID', 'ED', 'MSE', 'MRAE'};
    fprintf('\n指标统计 (标准差):\n');
    for i = 1:5
        fprintf('  %s: %.6f\n', metric_names{i}, stats(i));
    end
    
    % 可视化
    if show_plot
        [~, name, ~] = fileparts(filepath);
        
        figure('Color', 'w', 'Position', [100, 100, 1500, 800], ...
               'Name', ['HSI Analysis: ' name]);
        
        subplot(2,3,1);
        imagesc(metrics.sam); axis image; colormap(gca, jet); colorbar;
        title('SAM (光谱角)');
        
        subplot(2,3,2);
        imagesc(metrics.sid); axis image; colormap(gca, jet); colorbar;
        title('SID (信息散度)');
        
        subplot(2,3,3);
        imagesc(metrics.ed); axis image; colormap(gca, jet); colorbar;
        title('ED (欧氏距离)');
        
        subplot(2,3,4);
        imagesc(metrics.mse); axis image; colormap(gca, jet); colorbar;
        title('MSE (均方误差)');
        
        subplot(2,3,5);
        imagesc(metrics.mrae); axis image; colormap(gca, jet); colorbar;
        title('MRAE (相对误差)');
        
        % 显示 RGB 伪彩色 (如果波段足够)
        subplot(2,3,6);
        if B >= 20
            % 假设 400-700nm，取 R=620nm, G=550nm, B=470nm 对应的波段
            rgb_img = img(:,:,[22, 16, 8]);  % 近似 RGB 波段
            rgb_img = rgb_img / max(rgb_img(:));  % 归一化
            rgb_img = rgb_img .^ 0.4;  % gamma 校正
            imshow(rgb_img);
            title('伪彩色 RGB');
        else
            axis off;
            text(0.5, 0.5, sprintf('波段数: %d', B), ...
                'HorizontalAlignment', 'center', 'FontSize', 14);
        end
        
        sgtitle(['文件: ' strrep(name, '_', '\_')], 'FontSize', 14);
    end
end


function info = inspect_mat_file(filepath)
    % 检查 MAT 文件内容，帮助调试数据格式问题
    %
    % 用法:
    %   info = inspect_mat_file('path/to/file.mat')
    %
    % 输出:
    %   info - 结构体，包含文件中所有变量的信息
    
    fprintf('检查文件: %s\n', filepath);
    fprintf('%s\n', repmat('=', 1, 60));
    
    tmp = load(filepath);
    vars = fieldnames(tmp);
    
    info = struct();
    
    for i = 1:length(vars)
        v = tmp.(vars{i});
        sz = size(v);
        
        info.(vars{i}) = struct(...
            'class', class(v), ...
            'size', sz, ...
            'numel', numel(v));
        
        fprintf('变量: %-20s | 类型: %-10s | 尺寸: %s\n', ...
                vars{i}, class(v), mat2str(sz));
        
        % 对 3D 数值数组给出额外提示
        if isnumeric(v) && ndims(v) == 3
            fprintf('  └─ [可能是高光谱数据] ');
            if sz(3) < sz(1) && sz(3) < sz(2)
                fprintf('格式: H x W x B\n');
            elseif sz(1) < sz(2) && sz(1) < sz(3)
                fprintf('格式: B x H x W (需转置)\n');
            else
                fprintf('格式: 待确认\n');
            end
        end
    end
    
    fprintf('%s\n', repmat('=', 1, 60));
end
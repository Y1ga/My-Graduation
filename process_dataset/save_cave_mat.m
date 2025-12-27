%% convert_cave_png_to_mat: 将 CAVE 数据集的 PNG 图像转换为 MAT 格式
% 
% CAVE 数据集结构:
%   root_folder/
%   ├── balloons_ms/
%   │   ├── balloons_ms_01.png  (波段1)
%   │   ├── balloons_ms_02.png  (波段2)
%   │   ├── ...
%   │   ├── balloons_ms_31.png  (波段31)
%   │   └── balloons_RGB.bmp    (RGB参考图，可选)
%   ├── beads_ms/
%   │   └── ...
%   └── ...
%
% 输出:
%   save_folder/
%   ├── balloons_ms.mat  (包含变量 'hsi': H x W x 31)
%   ├── beads_ms.mat
%   └── ...
%
% 作者: [Your Name]
% 日期: 2024

clear; clc; close all;

%% ======================== 配置参数 ========================
% 请修改为你的实际路径
config.root_folder = "W:\dataset\CAVE\";           % CAVE 数据集根目录
config.save_folder = "W:\dataset\CAVE_MAT\";       % MAT 文件保存目录
config.num_bands = 31;                              % 波段数量
config.save_rgb = true;                             % 是否同时保存 RGB 图像

% 文件命名模式 (根据实际情况调整)
% CAVE 标准格式: {scene_name}_ms_{band:02d}.png
config.filename_pattern = '%s_%02d.png';  % 例如: balloons_ms_01.png

% 创建输出目录
if ~exist(config.save_folder, 'dir')
    mkdir(config.save_folder);
end

%% ======================== 主程序 ========================
fprintf('========================================\n');
fprintf('  CAVE PNG → MAT 转换工具\n');
fprintf('========================================\n\n');

% 获取所有子文件夹 (每个文件夹是一个场景)
scene_folders = dir(config.root_folder);
scene_folders = scene_folders([scene_folders.isdir]);  % 只保留文件夹
scene_folders = scene_folders(~ismember({scene_folders.name}, {'.', '..'}));  % 排除 . 和 ..

num_scenes = length(scene_folders);
fprintf('找到 %d 个场景文件夹\n\n', num_scenes);

% 处理统计
success_count = 0;
fail_list = {};

for i = 1:num_scenes
    scene_name = scene_folders(i).name;
    scene_path = fullfile(config.root_folder, scene_name);
    
    fprintf('[%2d/%d] 处理: %s ... ', i, num_scenes, scene_name);
    
    try
        % 转换该场景
        [hsi, rgb] = convert_single_scene(scene_path, scene_name, config);
        
        % 保存 MAT 文件
        save_path = fullfile(config.save_folder, [scene_name, '.mat']);
        
        if config.save_rgb && ~isempty(rgb)
            save(save_path, 'hsi', 'rgb', '-v7.3');
        else
            save(save_path, 'hsi', '-v7.3');
        end
        
        [H, W, B] = size(hsi);
        fprintf('完成 [%dx%dx%d]\n', H, W, B);
        success_count = success_count + 1;
        
    catch ME
        fprintf('失败: %s\n', ME.message);
        fail_list{end+1} = scene_name; %#ok<SAGROW>
    end
end

%% ======================== 完成报告 ========================
fprintf('\n========================================\n');
fprintf('  转换完成\n');
fprintf('========================================\n');
fprintf('成功: %d / %d\n', success_count, num_scenes);
fprintf('输出目录: %s\n', config.save_folder);

if ~isempty(fail_list)
    fprintf('\n失败的场景:\n');
    for i = 1:length(fail_list)
        fprintf('  - %s\n', fail_list{i});
    end
end

%% ======================== 核心函数 ========================

function [hsi, rgb] = convert_single_scene(scene_path, scene_name, config)
    % 将单个场景的 PNG 序列转换为高光谱立方体
    %
    % 输入:
    %   scene_path - 场景文件夹路径
    %   scene_name - 场景名称 (用于构建文件名)
    %   config     - 配置结构体
    %
    % 输出:
    %   hsi - [H x W x B] 高光谱图像 (double, 0-1 归一化)
    %   rgb - [H x W x 3] RGB 图像 (如果存在)
    
    hsi = [];
    rgb = [];
    
    % 尝试多种常见的文件命名模式
    patterns = {
        '%s_%02d.png',      % balloons_ms_01.png (标准 CAVE)
        '%s_%d.png',        % balloons_ms_1.png
        '%s%02d.png',       % balloons_ms01.png
        'band_%02d.png',    % band_01.png
        'band%02d.png',     % band01.png
        '%02d.png',         % 01.png
    };
    
    % 检测实际使用的命名模式
    pattern_found = '';
    for p = 1:length(patterns)
        test_file = fullfile(scene_path, sprintf(patterns{p}, scene_name, 1));
        if isfile(test_file)
            pattern_found = patterns{p};
            break;
        end
    end
    
    % 如果标准模式都不匹配，尝试自动检测 PNG 文件
    if isempty(pattern_found)
        [hsi, pattern_found] = auto_detect_and_load(scene_path, config.num_bands);
        if isempty(hsi)
            error('无法识别文件命名模式');
        end
    else
        % 按检测到的模式加载
        hsi = load_bands_by_pattern(scene_path, scene_name, pattern_found, config.num_bands);
    end
    
    % 加载 RGB 参考图 (如果存在)
    if config.save_rgb
        rgb = load_rgb_image(scene_path, scene_name);
    end
end


function hsi = load_bands_by_pattern(scene_path, scene_name, pattern, num_bands)
    % 按指定命名模式加载波段图像
    
    hsi = [];
    
    for b = 1:num_bands
        filename = sprintf(pattern, scene_name, b);
        filepath = fullfile(scene_path, filename);
        
        if ~isfile(filepath)
            error('找不到波段 %d 文件: %s', b, filename);
        end
        
        band_img = imread(filepath);
        
        % 如果是 RGB 图像，转为灰度
        if size(band_img, 3) == 3
            band_img = rgb2gray(band_img);
        end
        
        % 初始化输出数组
        if isempty(hsi)
            [H, W] = size(band_img);
            hsi = zeros(H, W, num_bands);
        end
        
        % 归一化到 [0, 1]
        hsi(:, :, b) = im2double(band_img);
    end
end


function [hsi, pattern_info] = auto_detect_and_load(scene_path, num_bands)
    % 自动检测 PNG 文件并按顺序加载
    
    hsi = [];
    pattern_info = 'auto-detected';
    
    % 获取所有 PNG 文件
    png_files = dir(fullfile(scene_path, '*.png'));
    
    if isempty(png_files)
        % 也尝试 TIFF 格式
        png_files = dir(fullfile(scene_path, '*.tif'));
    end
    
    if isempty(png_files)
        return;
    end
    
    % 按文件名排序 (自然排序)
    [~, idx] = sort_nat({png_files.name});
    png_files = png_files(idx);
    
    % 过滤掉 RGB 文件
    is_rgb = contains(lower({png_files.name}), 'rgb');
    png_files = png_files(~is_rgb);
    
    % 限制波段数
    if length(png_files) > num_bands
        png_files = png_files(1:num_bands);
    elseif length(png_files) < num_bands
        warning('只找到 %d 个波段文件 (期望 %d)', length(png_files), num_bands);
        num_bands = length(png_files);
    end
    
    % 加载图像
    for b = 1:num_bands
        filepath = fullfile(scene_path, png_files(b).name);
        band_img = imread(filepath);
        
        if size(band_img, 3) == 3
            band_img = rgb2gray(band_img);
        end
        
        if isempty(hsi)
            [H, W] = size(band_img);
            hsi = zeros(H, W, num_bands);
        end
        
        hsi(:, :, b) = im2double(band_img);
    end
end


function rgb = load_rgb_image(scene_path, scene_name)
    % 尝试加载 RGB 参考图像
    
    rgb = [];
    
    % 常见的 RGB 文件命名
    rgb_patterns = {
        [scene_name, '_RGB.bmp'],
        [scene_name, '_rgb.bmp'],
        [scene_name, '_RGB.png'],
        [scene_name, '_rgb.png'],
        [scene_name, '.bmp'],
        'RGB.bmp',
        'rgb.png',
    };
    
    for i = 1:length(rgb_patterns)
        filepath = fullfile(scene_path, rgb_patterns{i});
        if isfile(filepath)
            rgb = im2double(imread(filepath));
            return;
        end
    end
end


function [sorted_names, idx] = sort_nat(names)
    % 自然排序 (让 2 排在 10 前面)
    % 输入: names - 字符串元胞数组
    % 输出: sorted_names - 排序后的名称, idx - 排序索引
    
    % 提取数字部分用于排序
    nums = zeros(length(names), 1);
    for i = 1:length(names)
        tokens = regexp(names{i}, '\d+', 'match');
        if ~isempty(tokens)
            % 使用最后一个数字 (通常是波段号)
            nums(i) = str2double(tokens{end});
        else
            nums(i) = inf;
        end
    end
    
    [~, idx] = sort(nums);
    sorted_names = names(idx);
end


%% ======================== 验证函数 ========================

function verify_conversion(mat_folder)
    % 验证转换结果
    %
    % 用法: verify_conversion('W:\dataset\CAVE_MAT\')
    
    mat_files = dir(fullfile(mat_folder, '*.mat'));
    
    fprintf('验证 %d 个 MAT 文件:\n', length(mat_files));
    fprintf('%s\n', repmat('-', 1, 70));
    fprintf('%-30s | %12s | %8s | %8s\n', '文件名', '尺寸', '最小值', '最大值');
    fprintf('%s\n', repmat('-', 1, 70));
    
    for i = 1:length(mat_files)
        filepath = fullfile(mat_folder, mat_files(i).name);
        data = load(filepath);
        
        if isfield(data, 'hsi')
            hsi = data.hsi;
            sz_str = sprintf('%dx%dx%d', size(hsi,1), size(hsi,2), size(hsi,3));
            fprintf('%-30s | %12s | %8.4f | %8.4f\n', ...
                    mat_files(i).name, sz_str, min(hsi(:)), max(hsi(:)));
        else
            fprintf('%-30s | %12s\n', mat_files(i).name, '无 hsi 变量');
        end
    end
end
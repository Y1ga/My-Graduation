%% dataset_01：处理50-scenes数据集
clear; clc; close all;
%% 读取原始scene
path = "W:\dataset\50-Scenes\";
img = load(path+"hsi_1").hsi;
img_31 = img(:, :, 1:31);
%% 
%% 0. 设置路径
% 请修改为你存放数据的文件夹路径 (注意末尾的斜杠)
data_folder = "W:\dataset\50-Scenes\"; 
save_folder = "W:\dataset\50-Scenes\Results_Analysis\"; % 结果保存路径
if ~exist(save_folder, 'dir'), mkdir(save_folder); end

% 预分配一个表格用来存储统计数据，方便最后看哪个场景最丰富
stats_results = zeros(50, 3); % [SAM标准差, SID标准差, ED标准差]

%% 1. 开始循环处理 50 个场景
fprintf('开始批量处理 50 个场景...\n');

for i = 1:50
    % --- A. 构建文件名并加载 ---
    filename = sprintf('hsi_%d.mat', i);
    full_path = fullfile(data_folder, filename);
    
    if ~isfile(full_path)
        fprintf('跳过: 找不到文件 %s\n', filename);
        continue;
    end
    
    fprintf('正在处理 (%d/50): %s ... ', i, filename);
    
    % 加载数据
    tmp = load(full_path); 
    % 假设文件里的变量名是 'hsi'
    if isfield(tmp, 'hsi')
        img_full = tmp.hsi;
    else
        % 如果变量名不是hsi，尝试获取第一个变量
        vars = fieldnames(tmp);
        img_full = tmp.(vars{1});
    end
    
    % 截取前31个波段 (400-700nm)
    img_31 = img_full(:, :, 1:31);
    [H, W, B] = size(img_31);
    
    % --- B. 数据预处理 ---
    data_2d = reshape(img_31, H*W, B);
    data_2d = double(data_2d);
    data_2d(data_2d < 0) = 0;
    
    % 【关键】计算当前场景的平均光谱作为基准 (策略一)
    target_spectrum = mean(data_2d, 1);
    
    % --- C. 计算三种差异指标 ---
    
    % 1. SAM (光谱角)
    dot_prod = data_2d * target_spectrum';
    norm_data = sqrt(sum(data_2d.^2, 2));
    norm_target = sqrt(sum(target_spectrum.^2));
    cos_val = dot_prod ./ (norm_data * norm_target + eps);
    cos_val(cos_val > 1) = 1; cos_val(cos_val < -1) = -1;
    sam_res = reshape(acos(cos_val), H, W);
    
    % 2. SID (信息散度) - 推荐
    p = data_2d ./ (sum(data_2d, 2) + eps) + eps;
    q = target_spectrum ./ (sum(target_spectrum) + eps) + eps;
    term1 = sum(p .* log(p ./ q), 2);
    term2 = sum(q .* log(q ./ p), 2);
    sid_res = reshape(term1 + term2, H, W);
    
    % 3. Euclidean (欧氏距离)
    diff_sq = (data_2d - target_spectrum).^2;
    ed_res = reshape(sqrt(sum(diff_sq, 2)), H, W);
    
    % --- D. 记录统计信息 (标准差代表该场景的"丰富度") ---
    stats_results(i, :) = [std(sam_res(:)), std(sid_res(:)), std(ed_res(:))];
    
    % --- E. 生成并保存对比图 (不显示窗口) ---
    f = figure('visible', 'off', 'Position', [0, 0, 1200, 400]);
    
    subplot(1,3,1); imagesc(sam_res); axis image; colormap jet; colorbar;
    title(['Scene ' num2str(i) ' - SAM']); 
    
    subplot(1,3,2); imagesc(sid_res); axis image; colormap jet; colorbar;
    title(['Scene ' num2str(i) ' - SID (Sensitive)']);
    
    subplot(1,3,3); imagesc(ed_res); axis image; colormap jet; colorbar;
    title(['Scene ' num2str(i) ' - Euclidean']);
    
    % 保存图片
    saveas(f, fullfile(save_folder, sprintf('Result_Scene_%d.png', i)));
    close(f); % 关闭图形句柄，防止内存溢出
    
    fprintf('完成。\n');
end

%% 2. 最终分析：找出最"不一样"的场景
fprintf('处理完毕！正在分析数据...\n');

% 找出 SID 标准差最大的场景（意味着这个场景内部材质最复杂）
[max_val, max_idx] = max(stats_results(:, 2));
fprintf('内部差异最丰富的场景是: hsi_%d (SID Std: %.4f)\n', max_idx, max_val);

% 保存统计表格
save(fullfile(save_folder, 'Statistics.mat'), 'stats_results');
%% 可视化 A: 50个场景的差异丰富度排名
% 确保工作区里有之前跑出来的 stats_results 变量
if ~exist('stats_results', 'var')
    error('请先运行之前的批量处理代码，确保 stats_results 变量存在！');
end

% 提取 SID 的标准差 (第2列)
sid_stds = stats_results(:, 2);

% 找到最大值和最小值的位置
[max_val, max_idx] = max(sid_stds);
[min_val, min_idx] = min(sid_stds);

figure('Color', 'w', 'Position', [100, 100, 1000, 500]);
b = bar(1:50, sid_stds, 'FaceColor', [0.7 0.8 0.9]); % 默认浅蓝
hold on;

% 高亮标记最大值 (冠军) 和 最小值 (最后一名)
b.CData(max_idx, :) = [0.8 0.2 0.2]; % 红色 - 最丰富
b.CData(min_idx, :) = [0.2 0.6 0.2]; % 绿色 - 最平淡

% 装饰图表
grid on;
xlabel('场景编号 (Scene ID)');
ylabel('SID 标准差 (光谱差异丰富度)');
title('50个户外场景的光谱变异性对比 (SID Metric)');
subtitle(['最复杂的场景: #' num2str(max_idx) ' (红), 最单一的场景: #' num2str(min_idx) ' (绿)']);

% 添加文字标注
text(max_idx, max_val, [' \leftarrow Scene ' num2str(max_idx)], 'FontSize', 10, 'FontWeight', 'bold');
text(min_idx, min_val, [' \leftarrow Scene ' num2str(min_idx)], 'FontSize', 10, 'FontWeight', 'bold');
%% 
%% 可视化 B: "最复杂" vs "最简单" 场景对比
% 设置你的路径
data_folder = "W:\dataset\50-Scenes\"; 

% 自动确定要对比的两个场景 ID
scene_complex_id = max_idx; % 刚才算出来的最大值 ID (应该是 41)
scene_simple_id = min_idx;  % 刚才算出来的最小值 ID

% 定义一个用来读取和计算 SID 的局部函数 (为了代码简洁)
calc_sid_map = @(data) process_scene_for_vis(data);

% --- 加载并处理"最复杂"场景 ---
fprintf('正在读取最复杂的场景: hsi_%d ...\n', scene_complex_id);
tmp1 = load(fullfile(data_folder, sprintf('hsi_%d.mat', scene_complex_id)));
% 兼容变量名可能是 hsi 或其他情况
fn1 = fieldnames(tmp1); img_complex = tmp1.(fn1{1});
sid_map_complex = calc_sid_map(img_complex);

% --- 加载并处理"最简单"场景 ---
fprintf('正在读取最简单的场景: hsi_%d ...\n', scene_simple_id);
tmp2 = load(fullfile(data_folder, sprintf('hsi_%d.mat', scene_simple_id)));
fn2 = fieldnames(tmp2); img_simple = tmp2.(fn2{1});
sid_map_simple = calc_sid_map(img_simple);

% --- 绘图对比 ---
figure('Color', 'w', 'Position', [100, 100, 1200, 500]);

% 左图：最复杂的
subplot(1, 2, 1);
imagesc(sid_map_complex);
colormap jet; colorbar; axis image;
title({['Scene ' num2str(scene_complex_id) ' (最丰富)'], ['SID Std: ' num2str(max_val)]});
xlabel('能够清晰看到纹理、边缘和材质区别');

% 右图：最简单的
subplot(1, 2, 2);
imagesc(sid_map_simple);
colormap jet; colorbar; axis image;
title({['Scene ' num2str(scene_simple_id) ' (最单一)'], ['SID Std: ' num2str(min_val)]});
xlabel('差异较小，通常是大面积同色区域（如天空、草地）');

sgtitle('SID 光谱信息散度图对比 (颜色越红，代表该像素越"独特")');


% -----------------------------------------------------------


%% 1. 数据准备与检查
% 检查工作区是否存在 img_31，如果不存在则生成随机数据用于测试
if ~exist('img_31', 'var')
    warning('未找到 img_31变量，正在生成模拟数据...');
    % 生成模拟高光谱数据 (250x329, 31个波段)
    img_31 = rand(250, 329, 31); 
end

% 获取图像尺寸
[H, W, B] = size(img_31);
fprintf('正在处理图像尺寸: %d x %d, 波段数: %d\n', H, W, B);

% 将图像重塑为 2D 矩阵 (N_pixels x N_bands) 以便进行矩阵运算
% 每一行是一个像素的光谱
data_2d = reshape(img_31, H*W, B);

% 确保数据为 double 类型且非负 (避免 log(负数) 错误)
data_2d = double(data_2d);
data_2d(data_2d < 0) = 0;

%% 2. 定义参考光谱 (Target)
% 为了量化区别，我们需要一个"基准"。
% 方法 A: 使用整张图的【平均光谱】作为基准 (这样高亮的是"离群点"或最独特的像素)
target_spectrum = mean(data_2d, 1);

% 方法 B: (可选) 如果你想计算所有点与【左上角第一个点】的区别，取消下面注释
% target_spectrum = data_2d(1, :);

fprintf('基准光谱已设定。\n');

%% 3. 算法 1: 光谱角填图 (SAM) - 对光照不敏感，看重形状
fprintf('正在计算 SAM (Spectral Angle Mapper)...\n');

% 计算点积 (A . B)
dot_prod = data_2d * target_spectrum'; 

% 计算模长 (Norm)
norm_data = sqrt(sum(data_2d.^2, 2));
norm_target = sqrt(sum(target_spectrum.^2));

% 计算余弦值 (防除零，防浮点误差超出[-1, 1])
cos_val = dot_prod ./ (norm_data * norm_target + eps);
cos_val(cos_val > 1) = 1; 
cos_val(cos_val < -1) = -1;

% 计算反余弦得到角度 (弧度)
sam_result = acos(cos_val);

% 重塑回图像
map_sam = reshape(sam_result, H, W);

%% 4. 算法 2: 光谱信息散度 (SID) - 灵敏度极高，放大细微差异
fprintf('正在计算 SID (Spectral Information Divergence)...\n');

% 归一化为概率分布 (和为1)
p = data_2d ./ (sum(data_2d, 2) + eps);       % 所有像素
q = target_spectrum ./ (sum(target_spectrum) + eps); % 目标像素

% 再次防止 log(0)
p = p + eps; 
q = q + eps;

% 计算 KL 散度项
% SID(p,q) = sum(p*log(p/q)) + sum(q*log(q/p))
term1 = sum(p .* log(p ./ q), 2);
term2 = sum(q .* log(q ./ p), 2); % 注意这里 q 是 1xB，MATLAB会自动广播

sid_result = term1 + term2;

% 重塑回图像
map_sid = reshape(sid_result, H, W);

%% 5. 算法 3: 欧氏距离 (Euclidean) - 包含亮度差异
fprintf('正在计算 Euclidean Distance...\n');

diff = data_2d - target_spectrum; % 差值
ed_result = sqrt(sum(diff.^2, 2)); % 平方和开根号

map_ed = reshape(ed_result, H, W);

%% 6. 结果可视化与对比
figure('Name', '光谱差异量化对比', 'Color', 'w', 'Position', [100, 100, 1200, 400]);

% --- 显示 SAM ---
subplot(1, 3, 1);
imagesc(map_sam);
axis image; colorbar;
title({'SAM (光谱角)', '对阴影/亮度不敏感', '纯材质差异'});
xlabel('Pixel X'); ylabel('Pixel Y');

% --- 显示 SID ---
subplot(1, 3, 2);
imagesc(map_sid);
axis image; colorbar;
title({'SID (信息散度)', '【推荐】灵敏度最高', '最大化微小差异'});
xlabel('Pixel X'); ylabel('Pixel Y');

% --- 显示 Euclidean ---
subplot(1, 3, 3);
imagesc(map_ed);
axis image; colorbar;
title({'Euclidean (欧氏距离)', '包含亮度差异', '物理数值距离'});
xlabel('Pixel X'); ylabel('Pixel Y');

colormap jet; % 使用 jet 色图以获得高对比度
sgtitle('不同量化方法下的光谱差异图 (颜色越红表示差异越大)');

%% 7. 统计分析：哪个指标区分度最大？
% 计算标准差 (Standard Deviation) 来衡量图像的对比度
std_sam = std(sam_result(:));
std_sid = std(sid_result(:));
std_ed  = std(ed_result(:));

fprintf('\n=== 区分度分析 (方差越大，区分出的细节越多) ===\n');
fprintf('SAM 标准差: %.4f (关注材质)\n', std_sam);
fprintf('SID 标准差: %.4f (关注概率分布，通常对细节最敏感)\n', std_sid);
fprintf('ED  标准差: %.4f (受亮度影响大)\n', std_ed);

% 辅助函数：计算 SID 图
function map_sid = process_scene_for_vis(img_full)
    % 截取前31波段
    img = img_full(:, :, 1:31);
    [H, W, B] = size(img);
    data_2d = reshape(img, H*W, B);
    
    % 转为 double 并处理负值
    data_2d = double(data_2d);
    data_2d(data_2d < 0) = 0;
    
    % 计算均值作为 Target
    target = mean(data_2d, 1);
    
    % SID 计算
    p = data_2d ./ (sum(data_2d, 2) + eps) + eps;
    q = target ./ (sum(target) + eps) + eps;
    
    sid_val = sum(p .* log(p ./ q), 2) + sum(q .* log(q ./ p), 2);
    map_sid = reshape(sid_val, H, W);
end
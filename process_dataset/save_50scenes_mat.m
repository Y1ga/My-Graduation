%% 合并 50-Scenes 为 1D 和 2D 格式
% 输出: 50Scenes_1D.mat (N×31) 和 50Scenes_2D.mat (50×H×W×31)

clear; clc;

%% 配置
input_dir = 'W:\dataset\50-Scenes-31ch';  % 转换后的31通道数据
output_dir = 'W:\dataset\benchmark\merged_data';

if ~exist(output_dir, 'dir')
    mkdir(output_dir);
end

%% 获取文件列表
files = dir(fullfile(input_dir, 'scene*.mat'));
n_scenes = length(files);

fprintf('========================================\n');
fprintf('合并 50-Scenes 数据集\n');
fprintf('========================================\n');
fprintf('输入目录: %s\n', input_dir);
fprintf('输出目录: %s\n', output_dir);
fprintf('场景数量: %d\n', n_scenes);
fprintf('========================================\n\n');

%% 第一遍：统计尺寸
fprintf('[1/3] 统计数据尺寸...\n');

sizes = zeros(n_scenes, 3);  % [H, W, C]
total_pixels = 0;

for i = 1:n_scenes
    file_path = fullfile(input_dir, files(i).name);
    info = whos('-file', file_path, 'hsi');
    sizes(i, :) = info.size;
    total_pixels = total_pixels + sizes(i, 1) * sizes(i, 2);
    fprintf('  scene%02d: [%d × %d × %d]\n', i, sizes(i, :));
end

fprintf('\n总像素数: %d (%.2f M)\n', total_pixels, total_pixels/1e6);

% 检查是否所有场景尺寸相同（用于2D）
unique_sizes = unique(sizes(:, 1:2), 'rows');
same_size = size(unique_sizes, 1) == 1;

if same_size
    H = sizes(1, 1);
    W = sizes(1, 2);
    fprintf('所有场景尺寸相同: [%d × %d]\n', H, W);
else
    fprintf('警告: 场景尺寸不同，2D 将使用最大尺寸并填充\n');
    H = max(sizes(:, 1));
    W = max(sizes(:, 2));
end

n_channels = 31;

%% 第二遍：读取数据并合并
fprintf('\n[2/3] 读取并合并数据...\n');

% 预分配
data_1d = zeros(total_pixels, n_channels, 'single');
data_2d = zeros(n_scenes, H, W, n_channels, 'single');

pixel_idx = 1;

for i = 1:n_scenes
    file_path = fullfile(input_dir, files(i).name);
    tmp = load(file_path);
    hsi = single(tmp.hsi);  % [H, W, 31]
    
    [h, w, c] = size(hsi);
    n_pixels = h * w;
    
    % 1D: 展平
    hsi_flat = reshape(hsi, [], c);  % [H*W, 31]
    data_1d(pixel_idx:pixel_idx + n_pixels - 1, :) = hsi_flat;
    pixel_idx = pixel_idx + n_pixels;
    
    % 2D: 保持结构（如果尺寸不同则填充）
    data_2d(i, 1:h, 1:w, :) = hsi;
    
    fprintf('  [%2d/%d] %s: %d 像素\n', i, n_scenes, files(i).name, n_pixels);
end

fprintf('\n数据合并完成!\n');
fprintf('  1D: [%d × %d] (%.2f MB)\n', size(data_1d), numel(data_1d)*4/1e6);
fprintf('  2D: [%d × %d × %d × %d] (%.2f MB)\n', size(data_2d), numel(data_2d)*4/1e6);

%% 统计信息
fprintf('\n数据统计:\n');
fprintf('  范围: [%.4f, %.4f]\n', min(data_1d(:)), max(data_1d(:)));
fprintf('  均值: %.4f\n', mean(data_1d(:)));
fprintf('  标准差: %.4f\n', std(data_1d(:)));

%% 保存
fprintf('\n[3/3] 保存数据...\n');

% 保存 1D
output_1d = fullfile(output_dir, '50Scenes_1D.mat');
data = data_1d;
fprintf('  保存 %s ...\n', output_1d);
save(output_1d, 'data', '-v7.3');
fprintf('    完成: [%d × %d]\n', size(data));
clear data;

% 保存 2D
output_2d = fullfile(output_dir, '50Scenes_2D.mat');
data = data_2d;
fprintf('  保存 %s ...\n', output_2d);
save(output_2d, 'data', '-v7.3');
fprintf('    完成: [%d × %d × %d × %d]\n', size(data));
clear data;

%% 验证
fprintf('\n========================================\n');
fprintf('验证保存的文件\n');
fprintf('========================================\n');

% 验证 1D
fprintf('\n50Scenes_1D.mat:\n');
info = whos('-file', output_1d);
fprintf('  变量: %s\n', info.name);
fprintf('  大小: [%s]\n', num2str(info.size));
fprintf('  类型: %s\n', info.class);
fprintf('  文件大小: %.2f MB\n', info.bytes/1e6);

% 验证 2D
fprintf('\n50Scenes_2D.mat:\n');
info = whos('-file', output_2d);
fprintf('  变量: %s\n', info.name);
fprintf('  大小: [%s]\n', num2str(info.size));
fprintf('  类型: %s\n', info.class);
fprintf('  文件大小: %.2f MB\n', info.bytes/1e6);

fprintf('\n========================================\n');
fprintf('完成!\n');
fprintf('========================================\n');

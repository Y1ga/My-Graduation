%% 批量转换 50-Scenes 数据集
% 将 hsi_X.mat (H×W×33) 转换为 scene0X.mat (H×W×31)

clear; clc;

%% 配置
input_dir = 'W:\dataset\50-Scenes';
output_dir = 'W:\dataset\50-Scenes-31ch';

% 归一化选项
normalize_to_01 = true;  % true: 归一化到[0,1], false: 保持原始值

if ~exist(output_dir, 'dir')
    mkdir(output_dir);
end

%% 获取文件
files = dir(fullfile(input_dir, 'hsi_*.mat'));
n_files = length(files);

fprintf('========================================\n');
fprintf('50-Scenes 数据集转换\n');
fprintf('========================================\n');
fprintf('输入目录: %s\n', input_dir);
fprintf('输出目录: %s\n', output_dir);
fprintf('归一化到[0,1]: %s\n', string(normalize_to_01));
fprintf('找到 %d 个文件\n', n_files);
fprintf('========================================\n\n');

% 记录统计信息
all_max = zeros(n_files, 1);
all_min = zeros(n_files, 1);

%% 批量转换
for i = 1:n_files
    input_file = fullfile(input_dir, files(i).name);
    
    % 解析文件名
    tokens = regexp(files(i).name, 'hsi_(\d+)\.mat', 'tokens');
    if ~isempty(tokens)
        idx = str2double(tokens{1}{1});
        output_name = sprintf('scene%02d.mat', idx);
    else
        output_name = strrep(files(i).name, 'hsi_', 'scene');
    end
    output_file = fullfile(output_dir, output_name);
    
    fprintf('[%2d/%d] %s -> %s ... ', i, n_files, files(i).name, output_name);
    
    try
        data = load(input_file);
        
        if isfield(data, 'hsi')
            hsi_orig = data.hsi;
        else
            fn = fieldnames(data);
            for j = 1:length(fn)
                if numel(data.(fn{j})) > 1000
                    hsi_orig = data.(fn{j});
                    break;
                end
            end
        end
        
        [H, W, C] = size(hsi_orig);
        
        if C >= 31
            % 提取前31个通道
            hsi = double(hsi_orig(:, :, 1:31));
            
            % 记录原始范围
            all_min(i) = min(hsi(:));
            all_max(i) = max(hsi(:));
            
            % 归一化
            if normalize_to_01
                % 每个场景单独归一化到 [0, 1]
                hsi = hsi / max(hsi(:));
            end
            
            % 转为 single 节省空间
            hsi = single(hsi);
            
            save(output_file, 'hsi', '-v7.3');
            
            fprintf('完成 [%d×%d×%d] 原始范围:[%.2f,%.2f]\n', H, W, C, all_min(i), all_max(i));
        else
            fprintf('跳过 (通道数=%d)\n', C);
        end
        
    catch ME
        fprintf('错误: %s\n', ME.message);
    end
end

%% 统计
fprintf('\n========================================\n');
fprintf('原始数据统计\n');
fprintf('========================================\n');
fprintf('最小值范围: [%.4f, %.4f]\n', min(all_min), max(all_min));
fprintf('最大值范围: [%.4f, %.4f]\n', min(all_max), max(all_max));
fprintf('全局最大值: %.4f\n', max(all_max));

%% 验证
fprintf('\n========================================\n');
fprintf('验证输出\n');
fprintf('========================================\n');

output_files = dir(fullfile(output_dir, 'scene*.mat'));
fprintf('输出文件数: %d\n', length(output_files));

if ~isempty(output_files)
    test_file = fullfile(output_dir, output_files(1).name);
    test_data = load(test_file);
    fprintf('验证 %s:\n', output_files(1).name);
    fprintf('  大小: [%d × %d × %d]\n', size(test_data.hsi));
    fprintf('  类型: %s\n', class(test_data.hsi));
    fprintf('  范围: [%.4f, %.4f]\n', min(test_data.hsi(:)), max(test_data.hsi(:)));
end

fprintf('\n完成！\n');
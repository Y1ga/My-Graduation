%% ==================== 3. 加载色卡真值 x ====================
function [x, info] = load_ground_truth(color_index, varargin)
% LOAD_GROUND_TRUTH 加载色卡真值光谱
%
% 用法：
%   x = load_ground_truth(color_index)
%   [x, info] = load_ground_truth(color_index, 'Name', Value)
%
% 输入：
%   color_index - 色卡索引 (1-24)
%
% 可选参数：
%   'ColorChecker' - 直接提供色卡数据 [31 × n]
%   'ColorPath'    - 色卡mat文件路径
%
% 输出：
%   x    - 光谱真值 [31 × 1]
%   info - 结构体，包含 colorchecker, wavelengths 等

    p = inputParser;
    p.addRequired('color_index', @isnumeric);
    p.addParameter('ColorChecker', [], @isnumeric);
    p.addParameter('ColorPath', '', @(x) ischar(x) || isstring(x));
    p.parse(color_index, varargin{:});
    opts = p.Results;
    
    % 加载色卡数据
    if isempty(opts.ColorChecker)
        if isempty(opts.ColorPath)
            base_dir = fileparts(mfilename('fullpath'));
            opts.ColorPath = fullfile(base_dir, 'data', 'mat');
        end
        colorchecker = load_mat('colorchecker', opts.ColorPath);
    else
        colorchecker = opts.ColorChecker;
    end
    
    % 检查索引
    if color_index < 1 || color_index > size(colorchecker, 2)
        error('色卡索引 %d 超出范围 [1, %d]', color_index, size(colorchecker, 2));
    end
    
    x = colorchecker(:, color_index);
    
    % 输出信息
    if nargout >= 2
        info.colorchecker = colorchecker;
        info.wavelengths = linspace(400, 700, 31)';
        info.num_colors = size(colorchecker, 2);
    end
end
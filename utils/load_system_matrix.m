%% ==================== 1. 加载系统矩阵 A ====================
function [A, info] = load_system_matrix(varargin)
% LOAD_SYSTEM_MATRIX 加载LED光谱矩阵
%
% 用法：
%   A = load_system_matrix()
%   [A, info] = load_system_matrix('Name', Value)
%
% 可选参数：
%   'SkipLEDs'    - 跳过的LED索引，默认 [8,9]
%   'A0Path'      - mat文件路径
%   'A0Name'      - mat文件名，默认 'led_0711'
%   'NumChannels' - 光谱通道数，默认 31
%
% 输出：
%   A    - 系统矩阵 [num_working × 31]
%   info - 结构体

    p = inputParser;
    p.addParameter('SkipLEDs', [8,9], @isnumeric);
    p.addParameter('A0Path', '', @(x) ischar(x) || isstring(x));
    p.addParameter('A0Name', 'led_0711', @(x) ischar(x) || isstring(x));
    p.addParameter('NumChannels', 31, @isnumeric);
    p.parse(varargin{:});
    opts = p.Results;
    
    % 默认路径
    if isempty(opts.A0Path)
        base_dir = fileparts(mfilename('fullpath'));
        opts.A0Path = fullfile(base_dir, 'data', 'mat');
    end
    
    % 加载
    A0 = load_mat(opts.A0Name, opts.A0Path);
    
    % 检查维度
    [rows, cols] = size(A0);
    if rows == opts.NumChannels && cols ~= opts.NumChannels
        A0 = A0';
        [rows, cols] = size(A0);
    end
    
    if cols ~= opts.NumChannels
        error('A0 列数 (%d) 与光谱通道数 (%d) 不匹配', cols, opts.NumChannels);
    end
    
    % 提取工作LED
    num_leds = rows;
    working_leds = setdiff(1:num_leds, opts.SkipLEDs(:)');
    A = A0(working_leds, :);
    
    % 输出信息
    if nargout >= 2
        info.A0_full = A0;
        info.working_leds = working_leds;
        info.skip_leds = opts.SkipLEDs(:)';
        info.num_working = length(working_leds);
        info.num_channels = opts.NumChannels;
        info.wavelengths = linspace(400, 700, opts.NumChannels)';
    end
end
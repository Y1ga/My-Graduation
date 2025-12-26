%% ==================== 1. 构建系统矩阵 A ====================
function [A, info] = build_system_matrix(white_csv, varargin)
% BUILD_SYSTEM_MATRIX 从白板测量构建FDM系统矩阵
%
% 用法：
%   A = build_system_matrix(white_csv)
%   [A, info] = build_system_matrix(white_csv, 'Name', Value)
%
% 输入：
%   white_csv  - 白板参考CSV文件
%
% 可选参数：
%   'Freqs'     - LED频率(kHz)，默认 [118,128,...,228]
%   'SkipLEDs'  - 跳过的LED索引，默认 [8,9]
%   'A0'        - LED光谱矩阵 [num_leds × 31]，若不提供则自动加载
%   'A0Path'    - LED光谱矩阵路径
%
% 输出：
%   A    - 系统矩阵 [num_working × 31]
%   info - 结构体，包含 y_white, working_leds, freqs 等

    p = inputParser;
    p.addRequired('white_csv');
    p.addParameter('Freqs', [118,128,138,148,158,168,178,188,198,208,218,228], @isnumeric);
    p.addParameter('SkipLEDs', [8,9], @isnumeric);
    p.addParameter('A0', [], @isnumeric);
    p.addParameter('A0Path', '', @(x) ischar(x) || isstring(x));
    p.parse(white_csv, varargin{:});
    opts = p.Results;
    
    all_freqs = opts.Freqs(:)';
    num_leds = length(all_freqs);
    working_leds = setdiff(1:num_leds, opts.SkipLEDs(:)');
    
    % 加载或使用提供的 A0
    if isempty(opts.A0)
        if isempty(opts.A0Path)
            base_dir = fileparts(mfilename('fullpath'));
            opts.A0Path = fullfile(base_dir, 'data', 'mat');
        end
        A0 = load_mat('led_0711', opts.A0Path);
    else
        A0 = opts.A0;
    end
    
    % 提取白板响应
    [y_white_full, df] = extract_freq_amplitudes(white_csv, all_freqs);
    y_white = y_white_full(working_leds);
    
    % 构建系统矩阵
    A0_working = A0(working_leds, :);   % [num_working × 31]
    A = A0_working .* y_white;          % 逐行乘以白板响应
    
    % 输出信息
    if nargout >= 2
        info.y_white = y_white;
        info.working_leds = working_leds;
        info.freqs = all_freqs(working_leds);
        info.all_freqs = all_freqs;
        info.A0 = A0_working;
        info.df = df;
    end
end
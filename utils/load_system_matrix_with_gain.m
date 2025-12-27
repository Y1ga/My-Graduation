function [A, k_A, info] = load_system_matrix_with_gain(white_csv, varargin)
% LOAD_SYSTEM_MATRIX_WITH_GAIN 加载LED光谱矩阵并计算强度系数
%
% 用法：
%   [A, k_A] = load_system_matrix_with_gain(white_csv)
%   [A, k_A, info] = load_system_matrix_with_gain(white_csv, 'Name', Value)
%
% 输入：
%   white_csv - 白板参考CSV文件
%
% 可选参数：
%   'Freqs'       - LED频率(kHz)，默认 [118,128,...,228]
%   'SkipLEDs'    - 跳过的LED索引，默认 [8,9]
%   'A0Path'      - mat文件路径
%   'A0Name'      - mat文件名，默认 'led_0711'
%
% 输出：
%   A    - LED光谱矩阵 [num_working × 31]，不变
%   k_A  - 强度系数 [num_working × 1]
%   info - 结构体
%
% 模型：
%   y_measured = diag(k_A) * A * x
%   y_normalized = y_measured ./ k_A = A * x

    p = inputParser;
    p.addRequired('white_csv');
    p.addParameter('Freqs', [118,128,138,148,158,168,178,188,198,208,218,228], @isnumeric);
    p.addParameter('SkipLEDs', [8,9], @isnumeric);
    p.addParameter('A0Path', '', @(x) ischar(x) || isstring(x));
    p.addParameter('A0Name', 'led_0711', @(x) ischar(x) || isstring(x));
    p.addParameter('NumChannels', 31, @isnumeric);
    p.parse(white_csv, varargin{:});
    opts = p.Results;
    
    all_freqs = opts.Freqs(:)';
    num_leds = length(all_freqs);
    working_leds = setdiff(1:num_leds, opts.SkipLEDs(:)');
    
    %% 加载 A0
    if isempty(opts.A0Path)
        base_dir = fileparts(mfilename('fullpath'));
        opts.A0Path = fullfile(base_dir, 'data', 'mat');
    end
    A0 = load_mat(opts.A0Name, opts.A0Path);
    
    % 检查维度并修正
    [rows, cols] = size(A0);
    if rows == opts.NumChannels && cols ~= opts.NumChannels
        A0 = A0';
    end
    
    % 提取工作LED
    A = A0(working_leds, :);  % [num_working × 31]
    
    %% 提取白板响应
    [y_white_full, df] = extract_freq_amplitudes(white_csv, all_freqs);
    y_white = y_white_full(working_leds);
    y_white = y_white(:);
    
    %% 计算强度系数 k_A
    % y_white = k_A .* (A * ones(31,1))
    % k_A = y_white ./ (A * ones(31,1))
    A_sum = A * ones(opts.NumChannels, 1);  % 每个LED的光谱积分 [num_working × 1]
    k_A = y_white ./ A_sum;
    
    %% 输出信息
    if nargout >= 3
        info.y_white = y_white;
        info.A_sum = A_sum;
        info.working_leds = working_leds;
        info.skip_leds = opts.SkipLEDs(:)';
        info.freqs = all_freqs(working_leds);
        info.all_freqs = all_freqs;
        info.df = df;
        info.num_working = length(working_leds);
        info.num_channels = opts.NumChannels;
        info.wavelengths = linspace(400, 700, opts.NumChannels)';
    end
end
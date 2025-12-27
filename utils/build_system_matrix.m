%% ==================== 构建系统矩阵 ====================
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
%   'Freqs'       - LED频率(kHz)，默认 [30,50,70,110,130,170,190,230,270,290,310,370]
%   'SkipLEDs'    - 跳过的LED索引，默认 []
%   'Duration'    - 截取时长(μs)，默认 100
%   'UseWindow'   - 是否使用窗函数，默认 false
%   'A0'          - LED光谱矩阵 [12 × 31]，若不提供则自动加载
%   'A0Path'      - LED光谱矩阵路径
%   'NumChannels' - 光谱通道数，默认 31
%
% 输出：
%   A    - 系统矩阵 [num_working × 31]
%   info - 结构体

    p = inputParser;
    p.addRequired('white_csv');
    p.addParameter('Freqs', [30,50,70,110,130,170,190,230,270,290,310,370], @isnumeric);
    p.addParameter('SkipLEDs', [], @isnumeric);
    p.addParameter('Duration', 100, @isnumeric);
    p.addParameter('UseWindow', false, @islogical);
    p.addParameter('A0', [], @isnumeric);
    p.addParameter('A0Path', '', @(x) ischar(x) || isstring(x));
    p.addParameter('NumChannels', 31, @isnumeric);
    p.parse(white_csv, varargin{:});
    opts = p.Results;
    
    all_freqs = opts.Freqs(:)';
    num_leds = length(all_freqs);
    working_leds = setdiff(1:num_leds, opts.SkipLEDs(:)');
    num_working = length(working_leds);
    num_channels = opts.NumChannels;
    
    %% 加载或使用提供的 A0
    if isempty(opts.A0)
        if isempty(opts.A0Path)
            base_dir = fileparts(mfilename('fullpath'));
            opts.A0Path = fullfile(base_dir, 'data', 'mat');
        end
        A0 = load_mat('led_0711', opts.A0Path);
    else
        A0 = opts.A0;
    end
    
    %% 检查 A0 维度
    [rows, cols] = size(A0);
    
    if rows == num_channels && cols == num_leds
        warning('A0 维度为 [%d × %d]，已自动转置为 [%d × %d]', rows, cols, cols, rows);
        A0 = A0';
        [rows, cols] = size(A0);
    end
    
    if rows ~= num_leds
        error('A0 行数 (%d) 与LED数量 (%d) 不匹配', rows, num_leds);
    end
    
    if cols ~= num_channels
        error('A0 列数 (%d) 与光谱通道数 (%d) 不匹配', cols, num_channels);
    end
    
    fprintf('A0 维度检查通过: [%d LEDs × %d channels]\n', rows, cols);
    
    %% 提取白板响应（调用通用函数）
    [y_white_full, fft_info] = extract_freq_amplitudes(white_csv, all_freqs, ...
                                                        'Duration', opts.Duration, ...
                                                        'UseWindow', opts.UseWindow);
    y_white = y_white_full(working_leds);
    y_white = y_white(:);
    
    %% 构建系统矩阵
    A0_working = A0(working_leds, :);
    A = A0_working .* y_white;
    
    fprintf('系统矩阵 A 构建完成: [%d × %d]\n', size(A, 1), size(A, 2));
    
    %% 输出信息
    if nargout >= 2
        info.y_white = y_white;
        info.y_white_full = y_white_full;
        info.working_leds = working_leds;
        info.skip_leds = opts.SkipLEDs(:)';
        info.freqs = all_freqs(working_leds);
        info.all_freqs = all_freqs;
        info.A0 = A0_working;
        info.A0_full = A0;
        info.num_working = num_working;
        info.num_channels = num_channels;
        info.wavelengths = linspace(400, 700, num_channels)';
        info.fft_info = fft_info;  % 包含 fs, df, N 等
    end
end
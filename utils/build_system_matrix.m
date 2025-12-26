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
%   'A0'        - LED光谱矩阵 [12 × 31]，若不提供则自动加载
%   'A0Path'    - LED光谱矩阵路径
%   'NumChannels' - 光谱通道数，默认 31 (400-700nm)
%
% 输出：
%   A    - 系统矩阵 [num_working × 31]
%   info - 结构体，包含 y_white, working_leds, freqs 等
%
% 矩阵维度说明：
%   A0: [num_leds × num_channels] = [12 × 31]
%   y_white: [num_working × 1]
%   A:  [num_working × num_channels] = [10 × 31] (跳过2个LED时)

    p = inputParser;
    p.addRequired('white_csv');
    p.addParameter('Freqs', [118,128,138,148,158,168,178,188,198,208,218,228], @isnumeric);
    p.addParameter('SkipLEDs', [8,9], @isnumeric);
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
    
    % 期望: [num_leds × num_channels] = [12 × 31]
    if rows == num_channels && cols == num_leds
        % A0 是 [31 × 12]，需要转置
        warning('A0 维度为 [%d × %d]，已自动转置为 [%d × %d]', rows, cols, cols, rows);
        A0 = A0';
        [rows, cols] = size(A0);
    end
    
    if rows ~= num_leds
        error('A0 行数 (%d) 与LED数量 (%d) 不匹配', rows, num_leds);
    end
    
    if cols ~= num_channels
        error('A0 列数 (%d) 与光谱通道数 (%d) 不匹配\n期望: [%d × %d]，实际: [%d × %d]', ...
              cols, num_channels, num_leds, num_channels, rows, cols);
    end
    
    fprintf('A0 维度检查通过: [%d LEDs × %d channels]\n', rows, cols);
    
    %% 提取白板响应
    [y_white_full, df] = extract_freq_amplitudes(white_csv, all_freqs);
    y_white = y_white_full(working_leds);
    
    % 确保 y_white 是列向量
    y_white = y_white(:);
    
    %% 构建系统矩阵
    % A0_working: [num_working × num_channels]
    % y_white:    [num_working × 1]
    % A:          [num_working × num_channels]
    A0_working = A0(working_leds, :);
    A = A0_working .* y_white;  % 广播：每行乘以对应的白板响应
    
    %% 检查输出维度
    [out_rows, out_cols] = size(A);
    if out_rows ~= num_working || out_cols ~= num_channels
        error('系统矩阵 A 维度错误: 期望 [%d × %d]，实际 [%d × %d]', ...
              num_working, num_channels, out_rows, out_cols);
    end
    
    fprintf('系统矩阵 A 构建完成: [%d × %d]\n', out_rows, out_cols);
    
    %% 输出信息
    if nargout >= 2
        info.y_white = y_white;
        info.working_leds = working_leds;
        info.skip_leds = opts.SkipLEDs(:)';
        info.freqs = all_freqs(working_leds);
        info.all_freqs = all_freqs;
        info.A0 = A0_working;
        info.A0_full = A0;
        info.df = df;
        info.num_working = num_working;
        info.num_channels = num_channels;
        info.wavelengths = linspace(400, 700, num_channels)';
    end
end

%% ==================== 内部函数 ====================
function [amplitudes, df] = extract_freq_amplitudes(csv_file, target_freqs)
    fid = fopen(csv_file, 'r');
    if fid == -1
        error('无法打开文件: %s', csv_file);
    end
    fgetl(fid);
    line2 = fgetl(fid);
    fclose(fid);
    
    parts = strsplit(line2, ',');
    dt = str2double(parts{4});
    Fs = 1 / dt;
    
    data = readmatrix(csv_file, 'NumHeaderLines', 2);
    voltage = data(:, 2);
    voltage = voltage(~isnan(voltage));
    
    N = length(voltage);
    df = Fs / N;
    
    voltage_ac = voltage - mean(voltage);
    Y = fft(voltage_ac);
    P = 2 * abs(Y(1:floor(N/2)+1)) / N;
    f = Fs * (0:floor(N/2)) / N;
    
    amplitudes = zeros(length(target_freqs), 1);
    for i = 1:length(target_freqs)
        target = target_freqs(i) * 1000;
        [~, idx] = min(abs(f - target));
        amplitudes(i) = P(idx);
    end
end
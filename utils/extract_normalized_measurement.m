function [y, info] = extract_normalized_measurement(sample_csv, k_A, varargin)
% EXTRACT_NORMALIZED_MEASUREMENT 提取归一化测量值
%
% 用法：
%   y = extract_normalized_measurement(sample_csv, k_A)
%   [y, info] = extract_normalized_measurement(sample_csv, k_A, 'Name', Value)
%
% 输入：
%   sample_csv - 样本测量CSV
%   k_A        - 强度系数（来自 load_system_matrix_with_gain）
%
% 输出：
%   y - 归一化测量值 [num_working × 1]，满足 y = A * x

    p = inputParser;
    p.addRequired('sample_csv');
    p.addRequired('k_A', @isnumeric);
    p.addParameter('Freqs', [118,128,138,148,158,168,178,188,198,208,218,228], @isnumeric);
    p.addParameter('SkipLEDs', [8,9], @isnumeric);
    p.parse(sample_csv, k_A, varargin{:});
    opts = p.Results;
    
    all_freqs = opts.Freqs(:)';
    num_leds = length(all_freqs);
    working_leds = setdiff(1:num_leds, opts.SkipLEDs(:)');
    
    % 提取样本响应
    [y_sample_full, df] = extract_freq_amplitudes(sample_csv, all_freqs);
    y_sample = y_sample_full(working_leds);
    y_sample = y_sample(:);
    
    % 归一化：除以强度系数
    y = y_sample ./ k_A;
    
    % 输出信息
    if nargout >= 2
        info.y_raw = y_sample;
        info.k_A = k_A;
        info.working_leds = working_leds;
        info.freqs = all_freqs(working_leds);
        info.df = df;
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
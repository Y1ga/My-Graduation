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
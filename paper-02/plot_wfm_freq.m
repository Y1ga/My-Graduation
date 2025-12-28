%% WFM 文件 FFT 频谱分析
% 绘制原始频谱图，用于检查各LED频率的响应

clear; clc; close all;

%% 配置
path = "D:\Measure\";
wfm_file = path+"新建文件5.wfm";  % 修改为你的文件路径
fs = 1e9;  % 采样率 1 GSa/s

% 12个LED频率 (kHz)
led_freqs = [30, 50, 70, 110, 130, 170, 190, 230, 290, 310, 370, 410];

%% 读取 WFM 文件
fid = fopen(wfm_file, 'rb');
fseek(fid, hex2dec('A0'), 'bof');
volt_scale = fread(fid, 1, 'float32');
fseek(fid, 3334, 'bof');
raw_data = fread(fid, inf, 'uint8');
fclose(fid);

signal = (double(raw_data) - 128) * volt_scale;
signal_ac = signal - mean(signal);

fprintf('数据点数: %d\n', length(signal));
fprintf('电压范围: [%.3f, %.3f] V\n', min(signal), max(signal));

%% FFT
n_fft = 2^nextpow2(length(signal_ac));
fft_result = abs(fft(signal_ac, n_fft));
fft_mag = fft_result(1:n_fft/2);
freq_axis = (0:n_fft/2-1) * fs / n_fft / 1e3;  % kHz

%% 绘图
figure('Position', [100, 100, 1600, 600]);

plot(freq_axis, fft_mag, 'b-', 'LineWidth', 0.5);
hold on;

% 标记LED频率
for i = 1:length(led_freqs)
    xline(led_freqs(i), 'r--', sprintf('%dkHz', led_freqs(i)), ...
        'LineWidth', 1.5, 'Alpha', 0.7, 'LabelOrientation', 'horizontal');
end

xlim([0, 500]);
xticks(0:10:500);
xlabel('Frequency (kHz)');
ylabel('Amplitude');
title(sprintf('FFT Spectrum: %s', wfm_file));
grid on;

% 显示各LED频率处的幅度
fprintf('\n各LED频率幅度:\n');
fprintf('%-8s %-12s %-15s\n', 'LED', '频率(kHz)', '幅度');
fprintf('%s\n', repmat('-', 1, 35));
for i = 1:length(led_freqs)
    mask = (freq_axis >= led_freqs(i)-2) & (freq_axis <= led_freqs(i)+2);
    [amp, idx] = max(fft_mag .* mask');
    fprintf('LED%-5d %-12d %-15.0f\n', i, led_freqs(i), amp);
end
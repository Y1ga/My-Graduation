%% 理论值 vs 实际测量值 对比分析
% 比较 y_theory = A * x_gt 与 y_measured
% LED8(188kHz)和LED9(198kHz)已损坏，跳过
% 作者: Claude
% 日期: 2024

clear; clc; close all;

%% ==================== 配置 ====================
base_path = 'E:/';
base_path = 'D:\Experiment\pd\1222\';
% 文件路径
white_file = [base_path, '新建文件5.csv'];   % 白板参考
sample_file = [base_path, '新建文件3.csv'];  % 色卡样本测量

% 12个LED目标频率 (kHz)
all_freqs = [118, 128, 138, 148, 158, 168, 178, 188, 198, 208, 218, 228];

% 工作的LED索引 (跳过8和9)
working_leds = [1, 2, 3, 4, 5, 6, 7, 10, 11, 12];
num_working = length(working_leds);

% 加载LED光谱矩阵 A0 [12 x 31]
A0 = load_mat("led_0711", "gt");
% 加载色卡真值
colorchecker = load_mat("colorchecker", "gt");
% 16, 10
x_gt = colorchecker(:, 16);  % 第5个色块的光谱 [31 x 1]

% 波长范围
wavelengths = linspace(400, 700, 31);

fprintf('%s\n', repmat('=', 1, 65));
fprintf('理论值 vs 实际测量值 对比分析\n');
fprintf('%s\n', repmat('=', 1, 65));
fprintf('工作LED: [%s] (共%d个)\n', num2str(working_leds), num_working);
fprintf('跳过LED: 8 (188kHz), 9 (198kHz) - 已损坏\n');

%% ==================== 读取白板数据 ====================
fprintf('\n%s\n', repmat('=', 1, 65));
fprintf('步骤1: 读取白板参考数据\n');
fprintf('%s\n', repmat('=', 1, 65));

[y_white_full, ~] = extract_freq_amplitudes(white_file, all_freqs);

% 只取工作LED的数据
y_white = y_white_full(working_leds);

fprintf('白板%d个频率幅度 (跳过LED8,9):\n', num_working);
for i = 1:num_working
    led_idx = working_leds(i);
    fprintf('  LED%2d (%3dkHz): %.4f\n', led_idx, all_freqs(led_idx), y_white(i));
end
A = y_white .* A0(:,[1:7,10:12])';

%% ==================== 读取样本数据 ====================
fprintf('\n%s\n', repmat('=', 1, 65));
fprintf('步骤2: 读取色卡样本数据\n');
fprintf('%s\n', repmat('=', 1, 65));

[y_sample_full, ~] = extract_freq_amplitudes(sample_file, all_freqs);

% 只取工作LED的数据
y_sample = y_sample_full(working_leds);

fprintf('样本%d个频率幅度 (跳过LED8,9):\n', num_working);
for i = 1:num_working
    led_idx = working_leds(i);
    fprintf('  LED%2d (%3dkHz): %.4f\n', led_idx, all_freqs(led_idx), y_sample(i));
end
y = y_sample;
%% 

%% 
y_norm = norm_1(y);
y_theory = A * x_gt;
y_theory_norm = norm_1(y_theory);
plot(y_norm);
hold on;
plot(y_theory_norm);
%% 
% x = opt_gd(A, y);
% wav = 400:10:700;
% plot(wav, x,wav, x_gt);


%% ==================== 辅助函数 ====================
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


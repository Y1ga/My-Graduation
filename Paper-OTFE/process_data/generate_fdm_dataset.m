clear;
clc;
close all;

%% 参数设置
path = "./data/PD-01-04/";
fs_original = 1e9;
fs_target = 50e6;
downsample_factor = fs_original / fs_target;
duration = 350e-6;

n_samples_original = round(duration * fs_original);
n_samples = round(duration * fs_target);  % 17500
t = (0:n_samples-1) / fs_target;

led_freqs = [30, 50, 70, 110, 130, 170, 190, 230, 290, 310, 370, 410] * 1e3;  % Hz

fprintf('===== 数据集生成 (纯基频合成) =====\n\n');
fprintf('采样率: %.0f MHz\n', fs_target/1e6);
fprintf('采样点数: %d\n', n_samples);
fprintf('时长: %.0f μs\n', duration*1e6);

%% 读取白板，提取基频幅值（用于归一化）
fprintf('\n===== 读取白板基准 =====\n');

filename_white = path + "新建文件-1.wfm";
fid = fopen(filename_white, 'rb');
fseek(fid, hex2dec('84'), 'bof');
volt_div = fread(fid, 1, 'float32');
fseek(fid, hex2dec('A0'), 'bof');
volt_scale = fread(fid, 1, 'float32');
fseek(fid, 3334, 'bof');
raw_data = fread(fid, inf, 'uint8');
fclose(fid);

signal_white = (double(raw_data) - 128) * volt_scale * volt_div;
signal_white = signal_white(1:n_samples_original);
signal_white = signal_white - mean(signal_white);
signal_white_ds = signal_white(1:downsample_factor:end);

n_fft = 2^nextpow2(n_samples);
fft_white = fft(signal_white_ds, n_fft);
fft_mag_white = abs(fft_white(1:n_fft/2));
freq_axis = (0:n_fft/2-1) * fs_target / n_fft;

white_base_amps = zeros(12, 1);
for i = 1:12
    idx = find(freq_axis >= led_freqs(i) - 3e3 & freq_axis <= led_freqs(i) + 3e3);
    white_base_amps(i) = max(fft_mag_white(idx));
end

fprintf('白板基频FFT幅值:\n');
for i = 1:12
    fprintf('  %dkHz: %.2f\n', led_freqs(i)/1e3, white_base_amps(i));
end

%% 提取24色卡的归一化幅值
fprintf('\n===== 提取24色卡归一化幅值 =====\n');

real_normalized_amps = zeros(24, 12);
for card_idx = 1:24
    filename = path + "新建文件" + num2str(card_idx) + ".wfm";
    fid = fopen(filename, 'rb');
    fseek(fid, hex2dec('84'), 'bof');
    volt_div = fread(fid, 1, 'float32');
    fseek(fid, hex2dec('A0'), 'bof');
    volt_scale = fread(fid, 1, 'float32');
    fseek(fid, 3334, 'bof');
    raw_data = fread(fid, inf, 'uint8');
    fclose(fid);
    
    signal = (double(raw_data) - 128) * volt_scale * volt_div;
    signal = signal(1:n_samples_original);
    signal = signal - mean(signal);
    signal_ds = signal(1:downsample_factor:end);
    
    fft_result = fft(signal_ds, n_fft);
    fft_mag = abs(fft_result(1:n_fft/2));
    
    for i = 1:12
        idx = find(freq_axis >= led_freqs(i) - 3e3 & freq_axis <= led_freqs(i) + 3e3);
        real_normalized_amps(card_idx, i) = max(fft_mag(idx)) / white_base_amps(i);
    end
end

fprintf('归一化幅值范围: [%.3f, %.3f]\n', min(real_normalized_amps(:)), max(real_normalized_amps(:)));

%% 数据集参数
n_train = 10000;
n_val = 1000;
n_test = 1000;

amp_min = 0.01;
amp_max = 1.2;

fprintf('\n===== 生成数据集 =====\n');
fprintf('训练集: %d, 验证集: %d, 测试集: %d\n', n_train, n_val, n_test);
fprintf('归一化幅值范围: [%.2f, %.2f]\n', amp_min, amp_max);

%% 生成训练集
fprintf('\n生成训练集...\n');
X_train = zeros(n_train, n_samples);
Y_train = zeros(n_train, 12);

for i = 1:n_train
    normalized_amps = amp_min + (amp_max - amp_min) * rand(12, 1);
    
    % 纯基频合成
    signal = zeros(1, n_samples);
    for j = 1:12
        fft_amp = normalized_amps(j) * white_base_amps(j);
        A = fft_amp * 2 / n_samples;
        phase = rand * 2 * pi;
        signal = signal + A * cos(2*pi*led_freqs(j)*t + phase);
    end
    
    X_train(i, :) = signal;
    Y_train(i, :) = normalized_amps';
    
    if mod(i, 2000) == 0
        fprintf('  %d/%d\n', i, n_train);
    end
end

%% 生成验证集
fprintf('生成验证集...\n');
X_val = zeros(n_val, n_samples);
Y_val = zeros(n_val, 12);

for i = 1:n_val
    normalized_amps = amp_min + (amp_max - amp_min) * rand(12, 1);
    
    signal = zeros(1, n_samples);
    for j = 1:12
        fft_amp = normalized_amps(j) * white_base_amps(j);
        A = fft_amp * 2 / n_samples;
        phase = rand * 2 * pi;
        signal = signal + A * cos(2*pi*led_freqs(j)*t + phase);
    end
    
    X_val(i, :) = signal;
    Y_val(i, :) = normalized_amps';
end

%% 生成测试集
fprintf('生成测试集...\n');
X_test = zeros(n_test, n_samples);
Y_test = zeros(n_test, 12);

for i = 1:n_test
    normalized_amps = amp_min + (amp_max - amp_min) * rand(12, 1);
    
    signal = zeros(1, n_samples);
    for j = 1:12
        fft_amp = normalized_amps(j) * white_base_amps(j);
        A = fft_amp * 2 / n_samples;
        phase = rand * 2 * pi;
        signal = signal + A * cos(2*pi*led_freqs(j)*t + phase);
    end
    
    X_test(i, :) = signal;
    Y_test(i, :) = normalized_amps';
end

%% 真实数据（降采样）
fprintf('提取真实色卡数据...\n');
X_real = zeros(24, n_samples);
Y_real = real_normalized_amps;

for card_idx = 1:24
    filename = path + "新建文件" + num2str(card_idx) + ".wfm";
    fid = fopen(filename, 'rb');
    fseek(fid, hex2dec('84'), 'bof');
    volt_div = fread(fid, 1, 'float32');
    fseek(fid, hex2dec('A0'), 'bof');
    volt_scale = fread(fid, 1, 'float32');
    fseek(fid, 3334, 'bof');
    raw_data = fread(fid, inf, 'uint8');
    fclose(fid);
    
    signal = (double(raw_data) - 128) * volt_scale * volt_div;
    signal = signal(1:n_samples_original);
    signal = signal - mean(signal);
    signal_ds = signal(1:downsample_factor:end);
    X_real(card_idx, :) = signal_ds';
end

%% 验证合成质量
fprintf('\n===== 验证合成质量 =====\n');

fprintf('FFT还原验证:\n');
for test_i = 1:5
    idx = randi(n_train);
    signal_test = X_train(idx, :);
    label_test = Y_train(idx, :);
    
    fft_test = fft(signal_test, n_fft);
    fft_mag_test = abs(fft_test(1:n_fft/2));
    
    extracted_amps = zeros(12, 1);
    for i = 1:12
        freq_idx = find(freq_axis >= led_freqs(i) - 3e3 & freq_axis <= led_freqs(i) + 3e3);
        extracted_amps(i) = max(fft_mag_test(freq_idx)) / white_base_amps(i);
    end
    
    errors = abs(extracted_amps' - label_test) ./ label_test * 100;
    fprintf('  样本%d: 平均FFT误差 = %.2f%%\n', idx, mean(errors));
end

%% 保存数据集
fprintf('\n===== 保存数据集 =====\n');

save('dataset_50MHz_train.mat', 'X_train', 'Y_train', '-v7.3');
save('dataset_50MHz_val.mat', 'X_val', 'Y_val', '-v7.3');
save('dataset_50MHz_test.mat', 'X_test', 'Y_test', '-v7.3');
save('dataset_50MHz_real.mat', 'X_real', 'Y_real', '-v7.3');

% 元数据
metadata = struct();
metadata.fs = fs_target;
metadata.duration = duration;
metadata.n_samples = n_samples;
metadata.n_fft = n_fft;
metadata.led_freqs = led_freqs;
metadata.white_base_amps = white_base_amps;
metadata.amp_min = amp_min;
metadata.amp_max = amp_max;
metadata.n_train = n_train;
metadata.n_val = n_val;
metadata.n_test = n_test;
metadata.synthesis_method = 'pure_basefreq';
metadata.formula = 'A = fft_amp * 2 / n_samples';
metadata.fft_error = '~4%';
metadata.std_ratio = '~0.75';

save('dataset_50MHz_metadata.mat', '-struct', 'metadata');

fprintf('\n===== 数据集已保存 =====\n');
fprintf('  dataset_50MHz_train.mat: X(%dx%d), Y(%dx%d)\n', size(X_train,1), size(X_train,2), size(Y_train,1), size(Y_train,2));
fprintf('  dataset_50MHz_val.mat:   X(%dx%d), Y(%dx%d)\n', size(X_val,1), size(X_val,2), size(Y_val,1), size(Y_val,2));
fprintf('  dataset_50MHz_test.mat:  X(%dx%d), Y(%dx%d)\n', size(X_test,1), size(X_test,2), size(Y_test,1), size(Y_test,2));
fprintf('  dataset_50MHz_real.mat:  X(%dx%d), Y(%dx%d)\n', size(X_real,1), size(X_real,2), size(Y_real,1), size(Y_real,2));
fprintf('  dataset_50MHz_metadata.mat\n');

%% 可视化
figure('Position', [50, 50, 1400, 500]);

subplot(1, 3, 1);
idx = 1;
t_us = (0:n_samples-1) / fs_target * 1e6;
plot(t_us, X_train(idx, :));
xlabel('时间 (μs)');
ylabel('电压 (V)');
title(sprintf('合成样本 #%d', idx));
xlim([0, 50]);
grid on;

subplot(1, 3, 2);
plot(t_us, X_real(1, :));
xlabel('时间 (μs)');
ylabel('电压 (V)');
title('真实色卡 #1');
xlim([0, 50]);
grid on;

subplot(1, 3, 3);
histogram(Y_train(:), 30);
hold on;
xline(min(real_normalized_amps(:)), 'r--', 'LineWidth', 2);
xline(max(real_normalized_amps(:)), 'r--', 'LineWidth', 2);
xlabel('归一化幅值');
ylabel('频次');
title('训练集标签分布');
legend('训练集', '真实范围');
grid on;

sgtitle('数据集概览', 'FontSize', 14);
saveas(gcf, 'dataset_overview.png');

fprintf('\n图像已保存: dataset_overview.png\n');
fprintf('\n===== 完成 =====\n');
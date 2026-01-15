clear;
clc;
close all;

%% 参数设置
path = "./data/PD-01-04/";
duration = 350e-6;
fs = 1e9;
n_samples = round(duration * fs);

led_freqs = [30, 50, 70, 110, 130, 170, 190, 230, 290, 310, 370, 410];  % kHz

%% 提取所有24色卡的12个频率幅值
all_fft_amps = zeros(24, 12);

for idx = 1:24
    filename = path + "新建文件" + num2str(idx) + ".wfm";
    
    fid = fopen(filename, 'rb');
    fseek(fid, hex2dec('84'), 'bof');
    volt_div = fread(fid, 1, 'float32');
    fseek(fid, hex2dec('A0'), 'bof');
    volt_scale = fread(fid, 1, 'float32');
    volt_offset = fread(fid, 1, 'float32');
    fseek(fid, 3334, 'bof');
    raw_data = fread(fid, n_samples, 'uint8');
    fclose(fid);
    
    % 修正后的电压转换：乘以 volt_div
    signal = (double(raw_data) - 128) * volt_scale * volt_div;
    signal = signal - mean(signal);
    
    % FFT
    n_fft = 2^nextpow2(n_samples);
    fft_result = fft(signal, n_fft);
    fft_mag = abs(fft_result(1:n_fft/2));
    freq_axis = (0:n_fft/2-1) * fs / n_fft / 1e3;  % kHz
    
    % 提取12个频率的幅值
    for i = 1:12
        idx_range = find(freq_axis >= led_freqs(i) - 3 & freq_axis <= led_freqs(i) + 3);
        all_fft_amps(idx, i) = max(fft_mag(idx_range));
    end
end

%% 读取白板参考
filename_ref = path + "新建文件-1.wfm";
fid = fopen(filename_ref, 'rb');
fseek(fid, hex2dec('84'), 'bof');
volt_div_ref = fread(fid, 1, 'float32');
fseek(fid, hex2dec('A0'), 'bof');
volt_scale_ref = fread(fid, 1, 'float32');
volt_offset_ref = fread(fid, 1, 'float32');
fseek(fid, 3334, 'bof');
raw_ref = fread(fid, n_samples, 'uint8');
fclose(fid);

signal_ref = (double(raw_ref) - 128) * volt_scale_ref * volt_div_ref;
signal_ref = signal_ref - mean(signal_ref);

n_fft = 2^nextpow2(n_samples);
fft_ref = fft(signal_ref, n_fft);
fft_mag_ref = abs(fft_ref(1:n_fft/2));
freq_axis = (0:n_fft/2-1) * fs / n_fft / 1e3;

ref_amps = zeros(12, 1);
for i = 1:12
    idx_range = find(freq_axis >= led_freqs(i) - 3 & freq_axis <= led_freqs(i) + 3);
    ref_amps(i) = max(fft_mag_ref(idx_range));
end

%% 归一化（除以白板参考）
all_fft_amps_norm = all_fft_amps ./ ref_amps';

%% 绘图1：绝对幅值
figure('Position', [50, 50, 1400, 600]);

subplot(1, 2, 1);
colors = jet(24);
hold on;
for idx = 1:24
    plot(led_freqs, all_fft_amps(idx, :), '-o', 'Color', colors(idx, :), ...
        'LineWidth', 1.5, 'MarkerSize', 4, 'DisplayName', sprintf('#%d', idx));
end
xlabel('频率 (kHz)');
ylabel('FFT幅值');
title('24色卡 绝对FFT幅值');
grid on;
legend('Location', 'eastoutside', 'NumColumns', 2);

subplot(1, 2, 2);
hold on;
for idx = 1:24
    plot(led_freqs, all_fft_amps_norm(idx, :), '-o', 'Color', colors(idx, :), ...
        'LineWidth', 1.5, 'MarkerSize', 4, 'DisplayName', sprintf('#%d', idx));
end
xlabel('频率 (kHz)');
ylabel('归一化幅值 (相对白板)');
title('24色卡 归一化FFT幅值');
grid on;
legend('Location', 'eastoutside', 'NumColumns', 2);

sgtitle('24色卡 12频率 FFT幅值对比 (修正volt\_div后)', 'FontSize', 14);
saveas(gcf, 'fft_amps_24colors.png');

%% 绘图2：热力图
figure('Position', [50, 50, 1000, 600]);

subplot(1, 2, 1);
imagesc(led_freqs, 1:24, all_fft_amps);
colorbar;
xlabel('频率 (kHz)');
ylabel('色卡编号');
title('绝对FFT幅值');
set(gca, 'YDir', 'normal');

subplot(1, 2, 2);
imagesc(led_freqs, 1:24, all_fft_amps_norm);
colorbar;
xlabel('频率 (kHz)');
ylabel('色卡编号');
title('归一化FFT幅值');
set(gca, 'YDir', 'normal');
clim([0, 1]);

sgtitle('24色卡 FFT幅值热力图', 'FontSize', 14);
saveas(gcf, 'fft_amps_heatmap.png');

%% 打印数值
fprintf('===== 归一化FFT幅值 (相对白板) =====\n');
fprintf('色卡\t');
for i = 1:12
    fprintf('%dkHz\t', led_freqs(i));
end
fprintf('平均\n');

for idx = 1:24
    fprintf('%d\t', idx);
    for i = 1:12
        fprintf('%.3f\t', all_fft_amps_norm(idx, i));
    end
    fprintf('%.3f\n', mean(all_fft_amps_norm(idx, :)));
end

%% 检查色卡24是否最弱
fprintf('\n===== 平均归一化幅值排序 =====\n');
avg_amps = mean(all_fft_amps_norm, 2);
[sorted_avg, sort_idx] = sort(avg_amps, 'descend');
fprintf('排名\t色卡\t平均幅值\n');
for i = 1:24
    fprintf('%d\t%d\t%.4f\n', i, sort_idx(i), sorted_avg(i));
end

fprintf('\n图像已保存\n');
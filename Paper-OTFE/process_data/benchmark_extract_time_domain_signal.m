clear;
clc;
close all;

%% 参数设置
path = "./data/PD-01-04/";
duration = 350e-6;
fs = 1e9;
n_samples = round(duration * fs);
t = (0:n_samples-1) / fs * 1e6;  % 转换为微秒

%% 打印24色卡时域信号幅值情况
fprintf('===== 24色卡时域信号幅值统计 =====\n\n');
fprintf('色卡\tvolt_div\tvolt_scale\tstd\t\tmin\t\tmax\t\tpeak-peak\n');
fprintf('-------------------------------------------------------------------------------------\n');

all_std = zeros(24, 1);
all_min = zeros(24, 1);
all_max = zeros(24, 1);
all_voltdiv = zeros(24, 1);

for idx = 1:24
    filename = path + "新建文件" + num2str(idx) + ".wfm";
    
    fid = fopen(filename, 'rb');
    
    % 读取 volt_div (0x84)
    fseek(fid, hex2dec('84'), 'bof');
    volt_div = fread(fid, 1, 'float32');
    
    % 读取 volt_scale (0xA0)
    fseek(fid, hex2dec('A0'), 'bof');
    volt_scale = fread(fid, 1, 'float32');
    
    % 读取数据
    fseek(fid, 3334, 'bof');
    raw_data = fread(fid, n_samples, 'uint8');
    fclose(fid);
    
    % 修正后的转换：乘以 volt_scale * volt_div
    signal = (double(raw_data) - 128) * volt_scale * volt_div;
    signal = signal - mean(signal);
    
    all_std(idx) = std(signal);
    all_min(idx) = min(signal);
    all_max(idx) = max(signal);
    all_voltdiv(idx) = volt_div;
    
    fprintf('%d\t%.4f\t\t%.4f\t\t%.4f\t\t%.4f\t\t%.4f\t\t%.4f\n', ...
        idx, volt_div, volt_scale, all_std(idx), all_min(idx), all_max(idx), all_max(idx)-all_min(idx));
end

%% 按std排序
fprintf('\n===== 按幅值(std)排序 =====\n');
[sorted_std, sort_idx_std] = sort(all_std, 'descend');
fprintf('排名\t色卡\tstd\n');
for i = 1:24
    fprintf('%d\t%d\t%.4f\n', i, sort_idx_std(i), sorted_std(i));
end

%% 按峰峰值排序
all_pp = all_max - all_min;  % peak-to-peak
fprintf('\n===== 按峰峰值(peak-peak)排序 =====\n');
[sorted_pp, sort_idx_pp] = sort(all_pp, 'descend');
fprintf('排名\t色卡\t峰峰值\n');
for i = 1:24
    fprintf('%d\t%d\t%.4f\n', i, sort_idx_pp(i), sorted_pp(i));
end

%% 按峰值排序
all_peak = max(abs(all_min), abs(all_max));  % 绝对值最大
fprintf('\n===== 按峰值(peak)排序 =====\n');
[sorted_peak, sort_idx_peak] = sort(all_peak, 'descend');
fprintf('排名\t色卡\t峰值\n');
for i = 1:24
    fprintf('%d\t%d\t%.4f\n', i, sort_idx_peak(i), sorted_peak(i));
end

%% 解释幅值计算方法
fprintf('\n===== 幅值计算方法说明 =====\n');
fprintf('转换公式: signal = (raw_data - 128) * volt_scale * volt_div\n');
fprintf('\n');
fprintf('其中:\n');
fprintf('  - raw_data: 示波器存储的原始ADC值 (0-255, 中心128)\n');
fprintf('  - volt_scale: 固定值0.05，表示每个ADC count对应的基础电压\n');
fprintf('  - volt_div: 示波器V/div设置 (0.05~0.5V)，表示实际测量档位\n');
fprintf('\n');
fprintf('物理意义:\n');
fprintf('  - volt_div小 = 信号弱，示波器用高增益放大后存储\n');
fprintf('  - volt_div大 = 信号强，示波器用低增益存储\n');
fprintf('  - 乘以volt_div是为了还原真实电压值\n');

%% 创建图形窗口
figure('Position', [50, 50, 1600, 900], 'Name', '24色卡时域信号（修正后）');

for idx = 1:24
    subplot(4, 6, idx);
    
    filename = path + "新建文件" + num2str(idx) + ".wfm";
    
    fid = fopen(filename, 'rb');
    fseek(fid, hex2dec('84'), 'bof');
    volt_div = fread(fid, 1, 'float32');
    fseek(fid, hex2dec('A0'), 'bof');
    volt_scale = fread(fid, 1, 'float32');
    fseek(fid, 3334, 'bof');
    raw_data = fread(fid, n_samples, 'uint8');
    fclose(fid);
    
    signal = (double(raw_data) - 128) * volt_scale * volt_div;
    signal = signal - mean(signal);
    
    plot(t, signal, 'b', 'LineWidth', 0.5);
    pp = max(signal) - min(signal);
    title(sprintf('#%d (pp=%.3f)', idx, pp), 'FontSize', 9);
    xlabel('时间 (μs)', 'FontSize', 8);
    ylabel('电压 (V)', 'FontSize', 8);
    grid on;
    xlim([0, duration*1e6]);
end

sgtitle('24色卡时域信号 - 修正后（真实电压值）', 'FontSize', 14, 'FontWeight', 'bold');
saveas(gcf, 'time_signals_24colors_corrected_v2.png');
fprintf('\n图像已保存\n');
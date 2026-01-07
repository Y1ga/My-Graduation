clear;
clc;
close all;

%% 参数设置
path = "./data/PD-01-04/";
duration = 350e-6;
fs = 1e9;
n_samples = round(duration * fs);
t = (0:n_samples-1) / fs * 1e6;  % 转换为微秒

%% 创建图形窗口
figure('Position', [50, 50, 1600, 900], 'Name', '24色卡时域信号（修正后）');

%% 循环读取并绘制1~24的时域信号
for idx = 1:24
    subplot(4, 6, idx);
    
    filename = path + "新建文件" + num2str(idx) + ".wfm";
    
    % 读取修正后的时域信号
    signal = read_rigol_wfm_raw_corrected(filename, fs, duration);
    
    % 绘制
    plot(t, signal, 'b', 'LineWidth', 0.5);
    
    title(['色卡 #' num2str(idx)], 'FontSize', 10);
    xlabel('时间 (μs)', 'FontSize', 8);
    ylabel('电压 (V)', 'FontSize', 8);
    grid on;
    xlim([0, duration*1e6]);
end

sgtitle('24色卡时域信号 - 修正后（真实电压值）', 'FontSize', 14, 'FontWeight', 'bold');
saveas(gcf, 'time_signals_24colors_corrected.png');
fprintf('图像已保存\n');

%% ================== 修正后的时域信号读取函数 ==================
function signal = read_rigol_wfm_raw_corrected(filename, fs, duration)
    if nargin < 2 || isempty(fs), fs = 1e9; end
    if nargin < 3 || isempty(duration), duration = inf; end
    
    fid = fopen(filename, 'rb');
    if fid == -1, error('无法打开文件: %s', filename); end
    
    % 读取 volt_div (0x84)
    fseek(fid, hex2dec('84'), 'bof');
    volt_div = fread(fid, 1, 'float32');
    
    % 读取 volt_scale (0xA0)
    fseek(fid, hex2dec('A0'), 'bof');
    volt_scale = fread(fid, 1, 'float32');
    
    % 读取 volt_offset (0xA4) - 这个不需要了，去DC后会消除
    % volt_offset = fread(fid, 1, 'float32');
    
    % 读取数据
    fseek(fid, 3334, 'bof');
    raw_data = fread(fid, inf, 'uint8');
    fclose(fid);
    
    % 修正后的转换：乘以 volt_scale * volt_div
    signal = (double(raw_data) - 128) * volt_scale * volt_div;
    
    % 截取指定时长
    if isfinite(duration)
        n_use = min(round(duration * fs), length(signal));
        signal = signal(1:n_use);
    end
    
    % 去除DC
    signal = signal - mean(signal);
end
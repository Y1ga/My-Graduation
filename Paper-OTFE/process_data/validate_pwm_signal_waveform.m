clear;
clc;
close all;

%% 参数设置
path = "./data/PD-01-04/";
fs_original = 1e9;
duration = 350e-6;
n_samples = round(duration * fs_original);

%% 读取3个单独LED的波形
files = {'新建文件30khz.wfm', '新建文件130khz.wfm', '新建文件290khz.wfm'};
freqs = [30, 130, 290];  % kHz

figure('Position', [50, 50, 1600, 900]);

for f_idx = 1:3
    filename = path + files{f_idx};
    freq = freqs(f_idx);
    
    % 读取
    fid = fopen(filename, 'rb');
    if fid == -1
        fprintf('无法打开: %s\n', filename);
        continue;
    end
    fseek(fid, hex2dec('84'), 'bof');
    volt_div = fread(fid, 1, 'float32');
    fseek(fid, hex2dec('A0'), 'bof');
    volt_scale = fread(fid, 1, 'float32');
    fseek(fid, 3334, 'bof');
    raw_data = fread(fid, inf, 'uint8');
    fclose(fid);
    
    signal = (double(raw_data) - 128) * volt_scale * volt_div;
    signal = signal(1:min(n_samples, length(signal)));
    signal = signal - mean(signal);
    
    t_us = (0:length(signal)-1) / fs_original * 1e6;
    
    % 时域波形 - 完整
    subplot(3, 4, (f_idx-1)*4 + 1);
    plot(t_us, signal, 'b');
    xlabel('时间 (μs)');
    ylabel('电压 (V)');
    title(sprintf('%dkHz - 完整波形', freq));
    xlim([0, 100]);
    grid on;
    
    % 时域波形 - 放大看细节
    subplot(3, 4, (f_idx-1)*4 + 2);
    period_us = 1000 / freq;  % 周期 (μs)
    plot(t_us, signal, 'b');
    xlabel('时间 (μs)');
    ylabel('电压 (V)');
    title(sprintf('%dkHz - 放大 (周期=%.1fμs)', freq, period_us));
    xlim([0, 3*period_us]);  % 显示3个周期
    grid on;
    
    % FFT频谱
    n_fft = 2^nextpow2(length(signal));
    fft_result = fft(signal, n_fft);
    fft_mag = abs(fft_result(1:n_fft/2));
    freq_axis = (0:n_fft/2-1) * fs_original / n_fft / 1e3;  % kHz
    
    subplot(3, 4, (f_idx-1)*4 + 3);
    plot(freq_axis, fft_mag, 'b');
    xlabel('频率 (kHz)');
    ylabel('FFT幅度');
    title(sprintf('%dkHz - 频谱 (0-500kHz)', freq));
    xlim([0, 500]);
    grid on;
    
    % 标注基频和谐波
    hold on;
    for h = 1:10
        xline(freq * h, 'r--', 'Alpha', 0.5);
    end
    
    % FFT频谱 - 放大到基频附近
    subplot(3, 4, (f_idx-1)*4 + 4);
    plot(freq_axis, fft_mag, 'b');
    xlabel('频率 (kHz)');
    ylabel('FFT幅度');
    title(sprintf('%dkHz - 基频附近', freq));
    xlim([freq-20, freq+20]);
    grid on;
    
    % 分析谐波
    fprintf('\n===== %dkHz 谐波分析 =====\n', freq);
    fprintf('谐波\t频率(kHz)\tFFT幅值\t\t相对基频\n');
    fprintf('--------------------------------------------\n');
    
    base_amp = 0;
    for h = 1:15
        f_h = freq * h;
        if f_h > 500e3/1e3, break; end  % 超过500kHz停止
        
        idx = find(freq_axis >= f_h - 3 & freq_axis <= f_h + 3);
        if ~isempty(idx)
            amp = max(fft_mag(idx));
            if h == 1
                base_amp = amp;
                fprintf('%d\t%d\t\t%.2f\t\t1.000\n', h, f_h, amp);
            else
                fprintf('%d\t%d\t\t%.2f\t\t%.4f\n', h, f_h, amp, amp/base_amp);
            end
        end
    end
end

sgtitle('单独LED波形分析 - 确认调制类型', 'FontSize', 14);
saveas(gcf, 'single_led_waveform.png');

%% 理论对比：方波 vs 三角波 vs 正弦波的谐波
fprintf('\n\n===== 理论谐波分布 =====\n');
fprintf('波形类型\t奇次谐波\t\t偶次谐波\n');
fprintf('--------------------------------------------\n');
fprintf('方波\t\t1/n (n=1,3,5...)\t0\n');
fprintf('三角波\t\t1/n² (n=1,3,5...)\t0\n');
fprintf('正弦波\t\t只有基频\t\t0\n');
fprintf('锯齿波\t\t1/n (n=1,2,3...)\t1/n\n');
fprintf('\n');

fprintf('方波谐波: 1, 0, 1/3, 0, 1/5, 0, 1/7...\n');
fprintf('         = 1, 0, 0.333, 0, 0.200, 0, 0.143...\n\n');
fprintf('三角波谐波: 1, 0, 1/9, 0, 1/25, 0, 1/49...\n');
fprintf('           = 1, 0, 0.111, 0, 0.040, 0, 0.020...\n\n');
fprintf('锯齿波谐波: 1, 1/2, 1/3, 1/4, 1/5...\n');
fprintf('           = 1, 0.500, 0.333, 0.250, 0.200...\n');

fprintf('\n图像已保存: single_led_waveform.png\n');
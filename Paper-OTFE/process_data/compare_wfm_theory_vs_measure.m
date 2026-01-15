clear; 
clc;
%% 
A0 = load_mat("led_0115", "gt")';
% A0 = load_mat("led_0711", "gt")';

colorchecker = load_mat("colorchecker_trans", "gt");
idx = 19;
x = colorchecker(:, idx);

%% 
% 1~12是LED1~12单独发光
% 13是白板,
% 14对应色卡18
path = "./data/PD-01-15/D/";
duration = 100e-5;
k_A = read_rigol_wfm(path+"新建文件1.wfm", 1e9, duration);
A = k_A .* A0;
y_measured = read_rigol_wfm(path+"新建文件"+num2str(idx+1)+".wfm", 1e9, duration);
y_theory = A * x;
%% 
A_0115 = A;
save_mat(A_0115,"gt");
%% 
figure(1);
y_measured_norm = y_measured ./ max(y_measured);
y_theory_norm = y_theory ./ max(y_theory);
plot(y_measured_norm);
hold on;
plot(y_theory_norm);
legend('测量值','理论值');
hold off; 
rel_error = abs(y_measured_norm - y_theory_norm) ./ abs(y_theory_norm);
mean_rel_error = mean(rel_error) * 100;
fprintf('平均相对误差为: %.2f%%\n', mean_rel_error);
%% 
figure(2);
clf;
k_beta = max(y_theory,[],'all') / max(y_measured,[],'all');
k_beta = 1;
y = y_measured * k_beta;
x_est = fdm_reconstruct(y ./ k_A, A0, 'Method', 'tv');
wav = 400:10:700;
rmse = RMSE(x_est, x);
psnr = PSNR(rmse);
rgb_est = spec2rgb_simple(x_est);
rgb_gt = spec2rgb_simple(x);

% 确保rgb是1x3行向量
rgb_est = reshape(rgb_est, 1, 3);
rgb_gt = reshape(rgb_gt, 1, 3);

fprintf('PSNR为: %.1f dB\n', psnr);

% 绘制光谱曲线
plot(wav, x_est, 'LineWidth', 1.5);
hold on;
plot(wav, x, 'LineWidth', 1.5);
legend('预测', '真实', 'Location', 'southwest');
xlabel('波长 (nm)');
ylabel('反射率');
title(sprintf('光谱重建 (PSNR=%.1f dB)', psnr));
ylim([0, 1]);
xlim([400, 700]);
grid on;

% 用fill在数据坐标系内画色块（右上角区域）
block_w = 30;
block_h = 0.15;
x_start = 680;
y_start = 0.98;

% 预测颜色（右边）
fill([x_start-block_w, x_start, x_start, x_start-block_w], ...
     [y_start-block_h, y_start-block_h, y_start, y_start], ...
     rgb_est, 'EdgeColor', 'k', 'LineWidth', 1);
text(x_start - block_w/2, y_start - block_h - 0.03, '预测', ...
     'HorizontalAlignment', 'center', 'FontSize', 9);

% 真实颜色（左边）
x_start2 = x_start - block_w - 5;
fill([x_start2-block_w, x_start2, x_start2, x_start2-block_w], ...
     [y_start-block_h, y_start-block_h, y_start, y_start], ...
     rgb_gt, 'EdgeColor', 'k', 'LineWidth', 1);
text(x_start2 - block_w/2, y_start - block_h - 0.03, '真实', ...
     'HorizontalAlignment', 'center', 'FontSize', 9);

hold off;

%% 

%% 
%% ================== 读取函数（修正校正方向） ==================
function [amps, freq_detected, volt_div, v_min, v_max] = read_rigol_wfm(filename, fs, duration)
    if nargin < 2 || isempty(fs), fs = 1e9; end
    if nargin < 3 || isempty(duration), duration = inf; end

    led_freqs = [30, 50, 70, 110, 130, 170, 190, 230, 290, 310, 370, 410];
    n_leds = length(led_freqs);

    fid = fopen(filename, 'rb');
    if fid == -1, error('无法打开文件: %s', filename); end

    % 读取真实V/div (0x84)
    fseek(fid, hex2dec('84'), 'bof');
    volt_div = fread(fid, 1, 'float32');
    
    % 读取电压刻度因子 (0xA0)
    fseek(fid, hex2dec('A0'), 'bof');
    volt_scale = fread(fid, 1, 'float32');
    
    % 读取电压偏移 (0xA4)
    volt_offset = fread(fid, 1, 'float32');

    % 读取数据
    fseek(fid, 3334, 'bof');
    raw_data = fread(fid, inf, 'uint8');
    fclose(fid);

    % 转换为电压
    signal = (double(raw_data) - 128) * volt_scale + volt_offset;
    
    % 截取指定时长
    if isfinite(duration)
        n_use = min(round(duration * fs), length(signal));
        signal = signal(1:n_use);
    end

    % 输出电压范围
    v_min = min(signal);
    v_max = max(signal);

    % FFT
    signal_ac = signal - mean(signal);
    n_fft = 2^nextpow2(length(signal_ac));
    fft_result = fft(signal_ac, n_fft);
    fft_mag = abs(fft_result(1:n_fft/2));
    freq_axis = (0:n_fft/2-1) * fs / n_fft / 1e3;
    freq_resolution = fs / n_fft / 1e3;

    % 提取幅度
    amps = zeros(n_leds, 1);
    freq_detected = zeros(n_leds, 1);
    search_width = max(5, freq_resolution * 2);

    for i = 1:n_leds
        f_target = led_freqs(i);
        mask = (freq_axis >= f_target - search_width) & (freq_axis <= f_target + search_width);
        [max_val, max_idx] = max(fft_mag .* mask');
        amps(i) = max_val;
        freq_detected(i) = freq_axis(max_idx);
    end

    % 直接乘以V/div得到绝对强度
    amps = amps * volt_div;
end
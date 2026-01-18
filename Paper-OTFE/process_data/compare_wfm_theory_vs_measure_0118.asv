clear; 
clc;
%% 
A0 = load_mat("led_pd_0118", "gt")';
colorchecker = load_mat("colorchecker_trans_0118", "gt");
idx = 15;
x = colorchecker(:, idx);
%% 
path = "./data/PD-01-18/J/";
duration = 100e-5;
k_A = read_rigol_wfm(path+"新建文件-3.wfm", 1e9, duration);
A = k_A .* A0;
% A_0118 = A;
% save_mat(A_0118, "gt");
% 10~14强白光（1v量程）
% 15无噪声（1v量程）
% 16~42都是白光（1V量程）
% 43開始是手電
y_measured = read_rigol_wfm(path+"新建文件"+num2str(5)+".wfm", 1e9, duration);
y_theory = A * x;

%% 
% vpp 4.32v为极限最优
% 41的vpp是4.28v,42vpp是4.04v
% 以下為手電
% 46的vpp是4.64v
% 2+46是3.96v,3+46是4.96v,4是4.88v
% 5是6.24v（nice），6是6.48v,7是純净無噪聲（2V量程）
% 8是9.52v，9是7.2v，10是5.76v，11是5.24v(1v量程)
% 12是6.52v,13是3.4v，14是5.12v,15是4.52v
% 16是4.64v，17是3.36v，18是4.04v
% fft_data = plot_rigol_fft(path+"新建文件5.wfm", 1e9, duration);
% fft_data2 = plot_rigol_fft(path+"新建文件15.wfm", 1e9, duration);
% 
% tmp1 = max(fft_data(:, 2),[], "all");
% tmp2 = max(fft_data2(:, 2),[], "all");
% k_tmp = tmp1 ./ tmp2;
% %
% a9 = sum(A(9,:));
% y9 = y_theory(9);
% k2 = a9 ./ y9;
%% 
figure(1);
plot(y_measured);
hold on;
plot(y_theory);
legend('测量值','理论值');
hold off; 
rel_error = abs(y_measured - y_theory) ./ abs(y_theory);
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
    % led_freqs = [130, 140, 150, 160, 170, 180, 190, 200, 210, 220, 230, 240];
    led_freqs = [380, 390, 400, 410, 420, 430, 440, 450, 460, 470, 480, 490];
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
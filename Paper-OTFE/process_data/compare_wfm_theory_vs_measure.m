clear; 
clc;
%% 
A0 = load_mat("led_0711", "gt")';
A0 = A0 ./ sum(A0, 2);
colorchecker = load_mat("colorchecker", "gt");
idx = 5;
x = colorchecker(:, idx);

%% 
% -1,0是白板,
% 1~24对应24色卡
path = "./data/PD-01-04/";
duration = 100e-5;
k_A = read_rigol_wfm(path+"新建文件-1.wfm", 1e9, duration);
% k_A = load_mat("k_A_best", "gt");
A = k_A .* A0;

y_measured = read_rigol_wfm(path+"新建文件"+num2str(idx)+".wfm", 1e9, duration);
y_theory = A * x;
%% 
figure(1);
y_measured_norm = y_measured ./ max(y_measured);
y_theory_norm = y_theory ./ max(y_theory);
plot(y_measured_norm);
hold on;
plot(y_theory_norm);
legend('测量值','理论值');
hold off;
%% 
% 1. 计算点对点的相对误差 (得到一个 12x1 的向量)
rel_error = abs(y_measured_norm - y_theory_norm) ./ abs(y_theory_norm);
% 2. 如果你想看平均相对误差 (百分比形式)
mean_rel_error = mean(rel_error) * 100;
% 3. 输出结果
fprintf('平均相对误差为: %.2f%%\n', mean_rel_error);
%% 
figure(2);
k_beta = max(y_theory,[],'all') / max(y_measured,[],'all') ;
k_beta = 1;
y = y_measured * k_beta;
x_est = fdm_reconstruct(y ./ k_A, A0, 'Method', 'tv');
x_est = norm_1(x_est,'all');
wav = 400:10:700;
rmse = RMSE(x_est, x);
psnr = PSNR(rmse);
fprintf('PSNR为: %.1f dB\n', psnr);
plot(wav, x_est,wav, x);
legend('预测','真实');
ylim([0,1]);

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
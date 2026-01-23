%% FDM相位噪声分析
% 分析振荡器相位噪声对FDM系统的影响
% 相位噪声导致载波频谱展宽，可能引起邻道干扰
clear; clc; close all;

%% 相位噪声模型选择
% MODEL = 1: 白相位噪声 (White Phase Noise)
% MODEL = 2: 随机游走相位噪声 (Random Walk / Wiener Process)
% MODEL = 3: 1/f 相位噪声 (Flicker Phase Noise)
MODEL = 1;

%% 参数设置
% 相位噪声标准差 (弧度)
% 典型值: 0.01-0.1 rad (低噪声), 0.1-0.5 rad (中等), >0.5 rad (高噪声)
phase_noise_std_list = [0, 0.01, 0.05, 0.1, 0.2, 0.5, 1.0];

%% 绘图设置 (与论文风格统一)
FONTSIZE = 12;
FONTSIZE_TICK = 10;
FONTSIZE_LEGEND = 9;
LINE_WIDTH = 1.0;
MARKER_SIZE = 6;

% 配色方案 (低饱和度)
color_clean = [0.2, 0.2, 0.2];      % 深灰
color_noisy = [0.7, 0.3, 0.3];      % 暗红
color_rmse = [0.2, 0.4, 0.6];       % 深蓝
color_psnr = [0.6, 0.3, 0.5];       % 紫色
color_phase = [0.3, 0.5, 0.4];      % 深绿

%% 加载数据
A0 = load_mat("led_0711", "gt");
colorchecker = load_mat("colorchecker", "gt");

if size(A0,1) == 31, A0 = A0'; end
if size(colorchecker,1) == 31, colorchecker = colorchecker'; end

working_leds = [1,2,3,4,5,6,7,10,11,12];
A0_working = A0(working_leds, :);
x_gt = colorchecker(16, :)';
y_theory = A0_working * x_gt;
num_led = length(y_theory);

%% 信号参数
Fs = 1e6;           % 采样率 1 MHz
T = 100e-6;         % 采样时间 100 μs
N = round(Fs * T);  % 采样点数
t = (0:N-1) / Fs;   % 时间轴
df = Fs / N;        % 频率分辨率

% 载波频率 (自动选择)
f_base = 40e3;
f_spacing = 2e3;
freqs_Hz = f_base + (0:num_led-1) * f_spacing * 5;  % 10kHz间隔

%% 仿真不同相位噪声水平
n_test = length(phase_noise_std_list);
rmse_list = zeros(n_test, 1);
psnr_list = zeros(n_test, 1);
y_error_list = zeros(n_test, 1);
x_est_all = zeros(31, n_test);

fprintf('============================================================\n');
fprintf('Phase Noise Analysis\n');
fprintf('============================================================\n');
fprintf('Model: ');
switch MODEL
    case 1, fprintf('White Phase Noise\n');
    case 2, fprintf('Random Walk (Wiener Process)\n');
    case 3, fprintf('1/f Flicker Phase Noise\n');
end
fprintf('------------------------------------------------------------\n');
fprintf('%10s %12s %12s %12s\n', 'σ_φ (rad)', 'y Error(%)', 'RMSE', 'PSNR(dB)');
fprintf('%s\n', repmat('-', 1, 50));

for i = 1:n_test
    phase_std = phase_noise_std_list(i);
    
    [v_clean, v_noisy, ~] = generate_fdm_with_phase_noise(...
        y_theory, freqs_Hz, t, phase_std, MODEL, Fs);
    
    params.Fs = Fs;
    params.N = N;
    params.T = T;
    params.FreqsHz = freqs_Hz;
    params.FreqsKHz = freqs_Hz / 1000;
    
    y_exp = fdm_demodulate(v_noisy, params);
    y_error_list(i) = norm(y_exp - y_theory) / norm(y_theory) * 100;
    
    x_est = fdm_reconstruct(y_exp, A0_working, 'Method', 'tv');
    [rmse_list(i), psnr_list(i)] = fdm_metrics(x_gt, x_est);
    x_est_all(:, i) = x_est;
    
    fprintf('%10.2f %12.2f %12.4f %12.2f\n', ...
        phase_std, y_error_list(i), rmse_list(i), psnr_list(i));
end

%% 生成展示用信号 (中等相位噪声)
phase_std_demo = 0.5;  % 0.5 rad 用于展示
[v_clean_demo, v_noisy_demo, phi_noise_demo] = generate_fdm_with_phase_noise(...
    y_theory, freqs_Hz, t, phase_std_demo, MODEL, Fs);

% FFT
V_clean = abs(fft(v_clean_demo)) / N * 2;
V_noisy = abs(fft(v_noisy_demo)) / N * 2;
f_axis = (0:N-1) * df / 1000;  % kHz

%% 绘制综合图 (2行2列)
fig = figure('Position', [50, 50, 1000, 800], 'Color', 'w');

% 时间轴
t_us = t * 1e6;
T_DISPLAY = 50;  % 显示50μs
idx_display = t_us <= T_DISPLAY;

% (a) 相位噪声时域波形
subplot(2, 2, 1);
plot(t_us, phi_noise_demo(1,:), '-', 'LineWidth', LINE_WIDTH, 'Color', color_phase);
xlabel('Time (\mus)', 'FontSize', FONTSIZE);
ylabel('Phase (rad)', 'FontSize', FONTSIZE);
title(sprintf('(a) Phase Noise (\\sigma_\\phi = %.1f rad)', phase_std_demo), 'FontSize', FONTSIZE);
set(gca, 'FontSize', FONTSIZE_TICK, 'LineWidth', 0.8);
grid on; box on;

% (b) 时域信号对比
subplot(2, 2, 2);
plot(t_us(idx_display), v_clean_demo(idx_display), '-', ...
    'LineWidth', LINE_WIDTH, 'Color', color_clean, 'DisplayName', 'Clean');
hold on;
plot(t_us(idx_display), v_noisy_demo(idx_display), '-', ...
    'LineWidth', LINE_WIDTH, 'Color', color_noisy, 'DisplayName', 'With Phase Noise');
xlabel('Time (\mus)', 'FontSize', FONTSIZE);
ylabel('Amplitude', 'FontSize', FONTSIZE);
title('(b) Time Domain Signal', 'FontSize', FONTSIZE);
legend('Location', 'best', 'FontSize', FONTSIZE_LEGEND);
set(gca, 'FontSize', FONTSIZE_TICK, 'LineWidth', 0.8);
grid on; box on;
xlim([0, T_DISPLAY]);

% (c) RMSE vs 相位噪声
subplot(2, 2, 3);
plot(phase_noise_std_list, rmse_list, '-o', ...
    'LineWidth', LINE_WIDTH, 'MarkerSize', MARKER_SIZE, ...
    'Color', color_rmse, 'MarkerFaceColor', color_rmse);
xlabel('Phase Noise \sigma_\phi (rad)', 'FontSize', FONTSIZE);
ylabel('RMSE', 'FontSize', FONTSIZE);
title('(c) RMSE vs Phase Noise', 'FontSize', FONTSIZE);
set(gca, 'FontSize', FONTSIZE_TICK, 'LineWidth', 0.8);
grid on; box on;

% (d) 重建光谱对比
subplot(2, 2, 4);
wl = 400:10:700;
plot(wl, x_gt, '-', 'LineWidth', LINE_WIDTH, 'Color', color_clean, 'DisplayName', 'Ground Truth');
hold on;
% 选择几个典型相位噪声水平
idx_show = [1, 4, 7];  % 0, 0.1, 1.0 rad
colors_spec = {[0.3, 0.6, 0.4], [0.6, 0.5, 0.2], [0.7, 0.3, 0.3]};
for k = 1:length(idx_show)-1
    idx = idx_show(k);
    plot(wl, x_est_all(:, idx), '--', 'LineWidth', LINE_WIDTH, ...
        'Color', colors_spec{k}, ...
        'DisplayName', sprintf('\\sigma_\\phi = %.1f rad', phase_noise_std_list(idx)));
end
xlabel('Wavelength (nm)', 'FontSize', FONTSIZE);
ylabel('Reflectance', 'FontSize', FONTSIZE);
title('(d) Reconstructed Spectrum', 'FontSize', FONTSIZE);
legend('Location', 'best', 'FontSize', FONTSIZE_LEGEND);
set(gca, 'FontSize', FONTSIZE_TICK, 'LineWidth', 0.8);
grid on; box on;
xlim([400, 700]);

% 保存
savename = 'fig_phase_noise';
print(fig, savename, '-dpng', '-r300');
print(fig, savename, '-depsc', '-r300');
fprintf('\nSaved: %s.png and %s.eps\n', savename, savename);

%% 结论
fprintf('\n============================================================\n');
fprintf('Conclusion\n');
fprintf('============================================================\n');
fprintf('Phase noise causes carrier spectrum broadening.\n');
fprintf('  - σ_φ < 0.1 rad: Negligible impact (RMSE ≈ %.4f)\n', rmse_list(4));
fprintf('  - σ_φ = 0.5 rad: Moderate degradation (RMSE = %.4f)\n', rmse_list(6));
fprintf('  - σ_φ = 1.0 rad: Severe degradation (RMSE = %.4f)\n', rmse_list(7));
fprintf('\nRecommendations:\n');
fprintf('  - Use high-quality oscillators (σ_φ < 0.1 rad)\n');
fprintf('  - Increase carrier spacing to reduce adjacent channel interference\n');
fprintf('  - Use phase-locked loop (PLL) for clock synchronization\n');

%% ==================== 辅助函数 ====================

function phi_n = generate_phase_noise(std_phi, N, model, Fs)
    % 生成相位噪声
    % std_phi: 相位噪声标准差 (rad)
    % N: 采样点数
    % model: 1=白噪声, 2=随机游走, 3=1/f噪声
    
    if std_phi == 0
        phi_n = zeros(1, N);
        return;
    end
    
    switch model
        case 1
            % 白相位噪声: 每个采样点独立的高斯噪声
            phi_n = std_phi * randn(1, N);
            
        case 2
            % 随机游走 (Wiener过程): 相位累积
            dt = 1 / Fs;
            dW = sqrt(dt) * randn(1, N);
            phi_n = std_phi * cumsum(dW);
            
        case 3
            % 1/f 相位噪声 (粉红噪声)
            white = randn(1, N);
            f = (0:N-1) * Fs / N;
            f(1) = 1;  % 避免除零
            H = 1 ./ sqrt(f);
            H(1) = 0;
            phi_n_fft = fft(white) .* H;
            phi_n = std_phi * real(ifft(phi_n_fft));
            phi_n = phi_n / std(phi_n) * std_phi;
            
        otherwise
            phi_n = std_phi * randn(1, N);
    end
end

function [v_signal, v_noisy, phi_noise_all] = generate_fdm_with_phase_noise(...
    amplitudes, freqs_Hz, t, phase_std, model, Fs)
    % 生成带相位噪声的FDM信号
    
    N = length(t);
    num_led = length(amplitudes);
    v_signal = zeros(1, N);
    v_noisy = zeros(1, N);
    phi_noise_all = zeros(num_led, N);
    
    rng(42);
    
    for i = 1:num_led
        phi_0 = 2 * pi * rand();
        v_signal = v_signal + amplitudes(i) * sin(2*pi*freqs_Hz(i)*t + phi_0);
        
        phi_n = generate_phase_noise(phase_std, N, model, Fs);
        phi_noise_all(i, :) = phi_n;
        
        v_noisy = v_noisy + amplitudes(i) * sin(2*pi*freqs_Hz(i)*t + phi_0 + phi_n);
    end
end
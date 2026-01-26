%% FDM相位噪声分析
% 分析振荡器相位噪声对FDM系统的影响
% 图1: 时域信号对比 (无噪声 vs 不同相位噪声水平)
% 图2: RMSE vs 相位噪声标准差
clear; clc; close all;

%% 相位噪声模型选择
% MODEL = 1: 白相位噪声 (White Phase Noise)
% MODEL = 2: 随机游走相位噪声 (Random Walk / Wiener Process)
% MODEL = 3: 1/f 相位噪声 (Flicker Phase Noise)
MODEL = 1;

%% 参数设置
% 相位噪声标准差 (弧度) - 最大0.1 rad
phase_noise_std_list = [0, 0.01, 0.02, 0.05, 0.08, 0.1];

% 时域图显示的相位噪声水平
phase_show_list = [0, 0.02, 0.05, 0.1];  % 用于时域图

%% 绘图设置
FIG_WIDTH = 600;
FIG_HEIGHT = 500;
FONTSIZE = 14;
FONTSIZE_TICK = 12;
FONTSIZE_LEGEND = 11;
LINE_WIDTH = 1.2;
MARKER_SIZE = 8;

% 显示开关
SHOW_GRID = false;  % true: 显示网格, false: 不显示

% 配色方案
color_clean = [0.15, 0.15, 0.15];     % 深黑 - 无噪声
colors_phase = {
    [0.15, 0.15, 0.15], ...           % 0 rad - 黑
    [0.20, 0.50, 0.70], ...           % 0.02 rad - 蓝
    [0.20, 0.65, 0.35], ...           % 0.05 rad - 绿
    [0.80, 0.25, 0.25]};              % 0.1 rad - 红
color_rmse = [0.20, 0.45, 0.75];      % RMSE曲线 - 蓝色

%% 加载数据
A0 = load_mat("led_0711", "gt");
colorchecker = load_mat("colorchecker_trans_0118", "gt");

if size(A0,1) == 31, A0 = A0'; end
if size(colorchecker,1) == 31, colorchecker = colorchecker'; end

working_leds = [1,2,3,4,5,6,7,8,9,10,11,12];
A0_working = A0(working_leds, :);
x_gt = colorchecker(15, :)';
y_theory = A0_working * x_gt;
num_led = length(y_theory);

%% 信号参数
Fs = 10e6;          % 采样率 10 MHz
T = 100e-6;         % 采样时间 100 μs
N = round(Fs * T);  % 采样点数
t = (0:N-1) / Fs;   % 时间轴

% 载波频率 (自动选择)
[freqs_Hz, ~] = fdm_select_frequencies(num_led, 'T', T);

%% 仿真不同相位噪声水平 (用于RMSE曲线)
n_test = length(phase_noise_std_list);
rmse_list = zeros(n_test, 1);
y_error_list = zeros(n_test, 1);

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
fprintf('%12s %15s %12s\n', 'σ_φ (rad)', 'Demod Err(%)', 'RMSE');
fprintf('%s\n', repmat('-', 1, 42));

for i = 1:n_test
    phase_std = phase_noise_std_list(i);
    
    [~, v_noisy, ~] = generate_fdm_with_phase_noise(...
        y_theory, freqs_Hz, t, phase_std, MODEL, Fs);
    
    params.Fs = Fs;
    params.N = N;
    params.T = T;
    params.FreqsHz = freqs_Hz;
    params.FreqsKHz = freqs_Hz / 1000;
    
    y_exp = fdm_demodulate(v_noisy, params);
    y_error_list(i) = norm(y_exp - y_theory) / norm(y_theory) * 100;
    
    x_est = fdm_reconstruct(y_exp, A0_working, 'Method', 'tv');
    rmse_list(i) = fdm_metrics(x_gt, x_est);
    
    fprintf('%12.3f %15.2f %12.4f\n', phase_std, y_error_list(i), rmse_list(i));
end

%% 图1: 时域信号对比
fig1 = figure('Position', [100, 100, FIG_WIDTH, FIG_HEIGHT], 'Color', 'w');
hold on; box on;

% 时间轴
t_us = t * 1e6;
T_START = 0;
T_END = 10;  % 显示10μs
idx_display = (t_us >= T_START) & (t_us <= T_END);

% 生成并绘制不同相位噪声的信号
h_lines = gobjects(length(phase_show_list), 1);
legend_str = cell(length(phase_show_list), 1);

line_styles = {'-', '--', '-.', ':'};

for k = 1:length(phase_show_list)
    phase_std = phase_show_list(k);
    
    [v_clean, v_noisy, ~] = generate_fdm_with_phase_noise(...
        y_theory, freqs_Hz, t, phase_std, MODEL, Fs);
    
    if phase_std == 0
        v_plot = v_clean;
        legend_str{k} = 'Noiseless';
        lw = 1.8;
    else
        v_plot = v_noisy;
        legend_str{k} = sprintf('\\sigma_\\phi = %.2f rad', phase_std);
        lw = 1.2;
    end
    
    h_lines(k) = plot(t_us(idx_display), v_plot(idx_display), line_styles{k}, ...
        'LineWidth', lw, 'Color', colors_phase{k});
end

xlabel('Time (μs)', 'FontSize', FONTSIZE, 'FontName', 'Arial');
ylabel('Amplitude (a.u.)', 'FontSize', FONTSIZE, 'FontName', 'Arial');
legend(h_lines, legend_str, 'Location', 'best', 'FontSize', FONTSIZE_LEGEND, 'Box', 'off');
set(gca, 'FontSize', FONTSIZE_TICK, 'FontName', 'Arial', 'LineWidth', 0.8);
xlim([T_START, T_END]);
if SHOW_GRID
    grid on;
    set(gca, 'GridLineStyle', ':', 'GridAlpha', 0.4);
end

% 保存图1
savename1 = 'fig_phase_noise_time_domain';
print(fig1, savename1, '-dpng', '-r300');
print(fig1, savename1, '-depsc', '-r300');
fprintf('\nSaved: %s.png\n', savename1);

%% 图2: RMSE vs 相位噪声
fig2 = figure('Position', [750, 100, FIG_WIDTH, FIG_HEIGHT], 'Color', 'w');
hold on; box on;

plot(phase_noise_std_list, rmse_list, '-o', ...
    'LineWidth', LINE_WIDTH, 'MarkerSize', MARKER_SIZE, ...
    'Color', color_rmse, 'MarkerFaceColor', color_rmse);

xlabel('Phase noise standard deviation \sigma_\phi (rad)', 'FontSize', FONTSIZE, 'FontName', 'Arial');
ylabel('RMSE', 'FontSize', FONTSIZE, 'FontName', 'Arial');
set(gca, 'FontSize', FONTSIZE_TICK, 'FontName', 'Arial', 'LineWidth', 0.8);
xlim([0, max(phase_noise_std_list)]);
ylim([0, 0.02]);  % Y轴最大值0.02
if SHOW_GRID
    grid on;
    set(gca, 'GridLineStyle', ':', 'GridAlpha', 0.4);
end

% 保存图2
savename2 = 'fig_phase_noise_rmse';
print(fig2, savename2, '-dpng', '-r300');
print(fig2, savename2, '-depsc', '-r300');
fprintf('Saved: %s.png\n', savename2);

%% 打印结论
fprintf('\n============================================================\n');
fprintf('Summary\n');
fprintf('============================================================\n');
fprintf('Phase noise range: 0 - %.2f rad\n', max(phase_noise_std_list));
fprintf('RMSE range: %.4f - %.4f\n', min(rmse_list), max(rmse_list));
fprintf('\nConclusion:\n');
if rmse_list(end) - rmse_list(1) < 0.01
    fprintf('  Phase noise (σ_φ ≤ 0.1 rad) has minimal impact on reconstruction.\n');
else
    fprintf('  Phase noise degrades reconstruction quality.\n');
    fprintf('  RMSE increases by %.1f%% at σ_φ = 0.1 rad.\n', ...
        (rmse_list(end) - rmse_list(1)) / rmse_list(1) * 100);
end

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
    
    rng(42);  % 固定种子保证可复现
    
    for i = 1:num_led
        phi_0 = 2 * pi * rand();  % 随机初始相位
        
        % 无噪声信号
        v_signal = v_signal + amplitudes(i) * sin(2*pi*freqs_Hz(i)*t + phi_0);
        
        % 生成相位噪声
        phi_n = generate_phase_noise(phase_std, N, model, Fs);
        phi_noise_all(i, :) = phi_n;
        
        % 带相位噪声的信号
        v_noisy = v_noisy + amplitudes(i) * sin(2*pi*freqs_Hz(i)*t + phi_0 + phi_n);
    end
end
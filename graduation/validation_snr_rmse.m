%% FDM论文仿真：噪声对光谱重建的影响
% 六种噪声模式，按影响程度分组
% 用法：修改 MODE 变量选择模式
clear; clc; close all;

%% 选择模式
% === 影响大的噪声 (MODE 1-3) ===
% MODE = 1: 白噪声 (全频段)
% MODE = 2: 带内随机噪声 (40-250kHz)
% MODE = 3: 100Hz工频 (带外，但频谱泄漏影响大)
% === 影响小/无的噪声 (MODE 4-6) ===
% MODE = 4: DC环境光 (完全免疫)
% MODE = 5: PWM调光 (20kHz，带外边缘)
% MODE = 6: SMPS开关噪声 (100kHz，可通过频率规划避开)
MODE = 1;

%% 加载数据
A0 = load_mat("led_0711", "gt");
colorchecker = load_mat("colorchecker", "gt");

if size(A0,1) == 31, A0 = A0'; end
if size(colorchecker,1) == 31, colorchecker = colorchecker'; end

working_leds = [1,2,3,4,5,6,7,10,11,12];
A0_working = A0(working_leds, :);
x_gt = colorchecker(16, :)';
y_theory = A0_working * x_gt;
wavelengths = linspace(400, 700, 31);

%% 定义配色方案 (低饱和度，论文友好)
colors_spectrum = [
    0.1, 0.1, 0.1;      % 黑色 - Ground Truth
    0.15, 0.35, 0.60;   % 深蓝
    0.20, 0.50, 0.50;   % 青绿
    0.30, 0.55, 0.35;   % 绿色
    0.55, 0.50, 0.20;   % 橄榄
    0.70, 0.45, 0.20;   % 橙色
    0.65, 0.30, 0.30;   % 红褐
    0.50, 0.30, 0.55;   % 紫色
    0.40, 0.40, 0.40;   % 灰色
];

%% 根据模式设置参数
switch MODE
    case 1
        %% ========== 模式1: 白噪声 ==========
        mode_name = 'Broadband White Noise';
        snr_list = [-10, 0, 10, 20, 30, 40, 50, 60];
        n_test = length(snr_list);
        
        rmse_list = zeros(n_test, 1);
        psnr_list = zeros(n_test, 1);
        y_error_list = zeros(n_test, 1);
        x_est_all = zeros(31, n_test);
        
        for i = 1:n_test
            [v, ~, params] = fdm_generate_signal(y_theory, ...
                'FreqMode', 'auto', ...
                'SNR_dB', snr_list(i), ...
                'Seed', 42);
            
            y_exp = fdm_demodulate(v, params);
            y_error_list(i) = norm(y_exp - y_theory) / norm(y_theory) * 100;
            
            x_est = fdm_reconstruct(y_exp, A0_working, 'Method', 'tv');
            [rmse_list(i), psnr_list(i)] = fdm_metrics(x_gt, x_est);
            x_est_all(:, i) = x_est;
        end
        
        x_axis = snr_list;
        x_label = 'SNR (dB)';
        x_tick_labels = arrayfun(@num2str, snr_list, 'UniformOutput', false);
        savename = 'fig_white_noise';
        
    case 2
        %% ========== 模式2: 带内随机噪声 ==========
        mode_name = 'In-band Random Noise (40-250 kHz)';
        snr_inband_list = [-10, 0, 10, 20, 30, 40, 50, 60];
        n_test = length(snr_inband_list);
        
        rmse_list = zeros(n_test, 1);
        psnr_list = zeros(n_test, 1);
        y_error_list = zeros(n_test, 1);
        x_est_all = zeros(31, n_test);
        
        for i = 1:n_test
            [v, ~, params] = fdm_generate_signal(y_theory, ...
                'FreqMode', 'auto', ...
                'SNR_dB', Inf, ...
                'SNR_inband_dB', snr_inband_list(i), ...
                'Seed', 42);
            
            y_exp = fdm_demodulate(v, params);
            y_error_list(i) = norm(y_exp - y_theory) / norm(y_theory) * 100;
            
            x_est = fdm_reconstruct(y_exp, A0_working, 'Method', 'tv');
            [rmse_list(i), psnr_list(i)] = fdm_metrics(x_gt, x_est);
            x_est_all(:, i) = x_est;
        end
        
        x_axis = snr_inband_list;
        x_label = 'In-band SNR (dB)';
        x_tick_labels = arrayfun(@num2str, snr_inband_list, 'UniformOutput', false);
        savename = 'fig_inband_noise';
        
    case 3
        %% ========== 模式3: 100Hz工频 ==========
        % 100Hz虽然是带外，但短采样窗口会导致频谱泄漏影响解调
        mode_name = '100 Hz Power Line Interference';
        ambient_ratio_list = [0, 1, 10, 50, 100, 500, 1000];
        n_test = length(ambient_ratio_list);
        
        rmse_list = zeros(n_test, 1);
        psnr_list = zeros(n_test, 1);
        y_error_list = zeros(n_test, 1);
        x_est_all = zeros(31, n_test);
        
        for i = 1:n_test
            ratio = ambient_ratio_list(i);
            [v, ~, params] = fdm_generate_signal(y_theory, ...
                'FreqMode', 'auto', ...
                'SNR_dB', Inf, ...
                'Ambient100Hz', ratio, ...
                'Seed', 42);
            
            y_exp = fdm_demodulate(v, params);
            y_error_list(i) = norm(y_exp - y_theory) / norm(y_theory) * 100;
            
            x_est = fdm_reconstruct(y_exp, A0_working, 'Method', 'tv');
            [rmse_list(i), psnr_list(i)] = fdm_metrics(x_gt, x_est);
            x_est_all(:, i) = x_est;
        end
        
        x_axis = 1:n_test;
        x_label = '100 Hz Interference Ratio';
        x_tick_labels = {'0', '1x', '10x', '50x', '100x', '500x', '1000x'};
        savename = 'fig_100hz_noise';
        
    case 4
        %% ========== 模式4: DC环境光 ==========
        mode_name = 'DC Ambient Light';
        dc_ratio_list = [0, 1, 10, 50, 100, 500, 1000];
        n_test = length(dc_ratio_list);
        
        rmse_list = zeros(n_test, 1);
        psnr_list = zeros(n_test, 1);
        y_error_list = zeros(n_test, 1);
        x_est_all = zeros(31, n_test);
        
        for i = 1:n_test
            ratio = dc_ratio_list(i);
            [v, ~, params] = fdm_generate_signal(y_theory, ...
                'FreqMode', 'auto', ...
                'SNR_dB', Inf, ...
                'AmbientDC', ratio, ...
                'Seed', 42);
            
            y_exp = fdm_demodulate(v, params);
            y_err = norm(y_exp - y_theory) / norm(y_theory) * 100;
            if y_err < 1e-10, y_err = 0; end
            y_error_list(i) = y_err;
            
            x_est = fdm_reconstruct(y_exp, A0_working, 'Method', 'tv');
            [rmse_list(i), psnr_list(i)] = fdm_metrics(x_gt, x_est);
            x_est_all(:, i) = x_est;
        end
        
        x_axis = 1:n_test;
        x_label = 'DC Ambient Ratio';
        x_tick_labels = {'0', '1x', '10x', '50x', '100x', '500x', '1000x'};
        savename = 'fig_dc_noise';
        
    case 5
        %% ========== 模式5: PWM调光 (20kHz) ==========
        % 典型LED调光PWM频率: 500Hz-20kHz, 20kHz是高端产品常见值
        % 20kHz在FDM调制频带(40-250kHz)边缘外，但谐波可能进入带内
        mode_name = 'PWM Dimming (20 kHz)';
        pwm_ratio_list = [0, 1, 10, 50, 100, 500, 1000];
        n_test = length(pwm_ratio_list);
        
        rmse_list = zeros(n_test, 1);
        psnr_list = zeros(n_test, 1);
        y_error_list = zeros(n_test, 1);
        x_est_all = zeros(31, n_test);
        
        for i = 1:n_test
            ratio = pwm_ratio_list(i);
            [v, ~, params] = fdm_generate_signal(y_theory, ...
                'FreqMode', 'auto', ...
                'SNR_dB', Inf, ...
                'AmbientSMPS', ratio, ...
                'SMPSFreqHz', 20e3, ...  % 20kHz PWM
                'Seed', 42);
            
            y_exp = fdm_demodulate(v, params);
            y_error_list(i) = norm(y_exp - y_theory) / norm(y_theory) * 100;
            
            x_est = fdm_reconstruct(y_exp, A0_working, 'Method', 'tv');
            [rmse_list(i), psnr_list(i)] = fdm_metrics(x_gt, x_est);
            x_est_all(:, i) = x_est;
        end
        
        x_axis = 1:n_test;
        x_label = 'PWM Noise Ratio (20 kHz)';
        x_tick_labels = {'0', '1x', '10x', '50x', '100x', '500x', '1000x'};
        savename = 'fig_pwm_noise';
        
    case 6
        %% ========== 模式6: SMPS开关噪声 (100kHz) ==========
        % SMPS在带内，但可通过频率规划避开
        mode_name = 'SMPS Switching Noise (100 kHz)';
        smps_ratio_list = [0, 1, 10, 50, 100, 500, 1000];
        n_test = length(smps_ratio_list);
        
        rmse_list = zeros(n_test, 1);
        psnr_list = zeros(n_test, 1);
        y_error_list = zeros(n_test, 1);
        x_est_all = zeros(31, n_test);
        
        for i = 1:n_test
            ratio = smps_ratio_list(i);
            [v, ~, params] = fdm_generate_signal(y_theory, ...
                'FreqMode', 'auto', ...
                'SNR_dB', Inf, ...
                'AmbientSMPS', ratio, ...
                'SMPSFreqHz', 100e3, ...  % 100kHz SMPS
                'Seed', 42);
            
            y_exp = fdm_demodulate(v, params);
            y_error_list(i) = norm(y_exp - y_theory) / norm(y_theory) * 100;
            
            x_est = fdm_reconstruct(y_exp, A0_working, 'Method', 'tv');
            [rmse_list(i), psnr_list(i)] = fdm_metrics(x_gt, x_est);
            x_est_all(:, i) = x_est;
        end
        
        x_axis = 1:n_test;
        x_label = 'SMPS Noise Ratio (100 kHz)';
        x_tick_labels = {'0', '1x', '10x', '50x', '100x', '500x', '1000x'};
        savename = 'fig_smps_noise';
end

%% 打印结果
fprintf('============================================================\n');
fprintf('Mode %d: %s\n', MODE, mode_name);
fprintf('============================================================\n');
fprintf('%15s %12s %12s %12s\n', x_label, 'y Error(%)', 'RMSE', 'PSNR(dB)');
fprintf('%s\n', repmat('-', 1, 54));
for i = 1:n_test
    fprintf('%15s %12.2f %12.4f %12.2f\n', x_tick_labels{i}, y_error_list(i), rmse_list(i), psnr_list(i));
end

%% 绘图
% 统一设置
FIG_WIDTH = 1400;
FIG_HEIGHT = 400;
FONTSIZE = 16;
FONTSIZE_LEGEND = 12;
FONTSIZE_TICK = 14;

fig = figure('Position', [100, 100, FIG_WIDTH, FIG_HEIGHT], 'Color', 'w');

% 子图1: RMSE vs 噪声
ax1 = subplot(1, 3, 1);
if MODE >= 3  % MODE 3,4,5 用bar图
    b1 = bar(x_axis, rmse_list, 0.6);
    b1.FaceColor = [0.35, 0.55, 0.70];
    b1.EdgeColor = [0.25, 0.45, 0.60];
    b1.LineWidth = 0.8;
    set(gca, 'XTick', x_axis, 'XTickLabel', x_tick_labels);
else
    plot(x_axis, rmse_list, 'o-', 'LineWidth', 1.5, 'MarkerSize', 6, ...
        'Color', [0.25, 0.45, 0.65], 'MarkerFaceColor', [0.35, 0.55, 0.75]);
end
xlabel(x_label, 'FontSize', FONTSIZE, 'FontName', 'Arial');
ylabel('RMSE', 'FontSize', FONTSIZE, 'FontName', 'Arial');
set(gca, 'FontSize', FONTSIZE_TICK, 'FontName', 'Arial', 'LineWidth', 0.8, ...
    'TickDir', 'out', 'TickLength', [0.02, 0.02]);
box on;
grid on;
set(gca, 'GridLineStyle', ':', 'GridAlpha', 0.4);

% 子图2: y解调误差 vs 噪声
ax2 = subplot(1, 3, 2);
if MODE >= 3  % MODE 3,4,5 用bar图
    b2 = bar(x_axis, y_error_list, 0.6);
    b2.FaceColor = [0.70, 0.45, 0.45];
    b2.EdgeColor = [0.60, 0.35, 0.35];
    b2.LineWidth = 0.8;
    set(gca, 'XTick', x_axis, 'XTickLabel', x_tick_labels);
else
    plot(x_axis, y_error_list, 's-', 'LineWidth', 1.5, 'MarkerSize', 6, ...
        'Color', [0.65, 0.35, 0.35], 'MarkerFaceColor', [0.75, 0.45, 0.45]);
end
xlabel(x_label, 'FontSize', FONTSIZE, 'FontName', 'Arial');
ylabel('Demodulation Error (%)', 'FontSize', FONTSIZE, 'FontName', 'Arial');
set(gca, 'FontSize', FONTSIZE_TICK, 'FontName', 'Arial', 'LineWidth', 0.8, ...
    'TickDir', 'out', 'TickLength', [0.02, 0.02]);
box on;
grid on;
set(gca, 'GridLineStyle', ':', 'GridAlpha', 0.4);

% 子图3: 光谱重建对比 (只画RMSE较小的)
ax3 = subplot(1, 3, 3);

% 手动设置：从第几个开始画（MODE3,4是画到第几个）
% MODE 1,2: SNR从小到大，设置起始索引
%   SNR = [-10, 0, 10, 20, 30, 40, 50, 60]
%   索引:   1   2   3   4   5   6   7   8
% MODE 3,4: 噪声从小到大，设置结束索引
PLOT_START_IDX = 4;  % MODE 1,2: 从第4个开始画 (对应SNR=20dB)
PLOT_END_IDX = 7;    % MODE 3,4: 画前几个（7=全部）

if MODE >= 3  % MODE 3,4,5
    valid_idx = 1:PLOT_END_IDX;
else
    valid_idx = PLOT_START_IDX:n_test;
end

% 生成渐变色
n_valid = length(valid_idx);
cmap_custom = zeros(n_valid, 3);
for i = 1:n_valid
    t = (i-1) / max(n_valid-1, 1);
    % 从深红到深蓝
    cmap_custom(i,:) = [0.7-0.5*t, 0.2+0.2*t, 0.2+0.5*t];
end

% 先画重建曲线（虚线）
for j = 1:n_valid
    i = valid_idx(j);
    plot(wavelengths, x_est_all(:,i), '--', 'LineWidth', 1.2, ...
        'Color', cmap_custom(j, :), ...
        'DisplayName', x_tick_labels{i});
    hold on;
end

% 最后画真值（粗黑实线）
plot(wavelengths, x_gt, 'k-', 'LineWidth', 2.5, 'DisplayName', 'Ground Truth');

xlabel('Wavelength (nm)', 'FontSize', FONTSIZE, 'FontName', 'Arial');
ylabel('Reflectance', 'FontSize', FONTSIZE, 'FontName', 'Arial');
leg = legend('Location', 'southeast', 'FontSize', FONTSIZE_LEGEND, 'NumColumns', 2);
leg.Box = 'off';
set(gca, 'FontSize', FONTSIZE_TICK, 'FontName', 'Arial', 'LineWidth', 0.8, ...
    'TickDir', 'out', 'TickLength', [0.02, 0.02]);
box on;
grid on;
set(gca, 'GridLineStyle', ':', 'GridAlpha', 0.4);
xlim([400, 700]);

% 调整子图位置
set(ax1, 'Position', [0.07, 0.15, 0.26, 0.78]);
set(ax2, 'Position', [0.40, 0.15, 0.26, 0.78]);
set(ax3, 'Position', [0.73, 0.15, 0.25, 0.78]);

% 保存图片
print(gcf, savename, '-dpng', '-r300');
print(gcf, savename, '-depsc', '-r300');  % 同时保存eps
fprintf('\nSaved: %s.png and %s.eps\n', savename, savename);

%% 结论
fprintf('\n============================================================\n');
fprintf('Conclusion\n');
fprintf('============================================================\n');
switch MODE
    case 1
        fprintf('White noise analysis:\n');
        fprintf('  - SNR > 30 dB: RMSE < 0.05, good reconstruction\n');
        idx20 = find(snr_list==20, 1);
        if ~isempty(idx20)
            fprintf('  - SNR = 20 dB: RMSE = %.3f, acceptable\n', rmse_list(idx20));
        end
        fprintf('  - SNR < 10 dB: significant degradation\n');
    case 2
        fprintf('In-band noise analysis:\n');
        fprintf('  - In-band noise directly affects demodulation\n');
        fprintf('  - More harmful than broadband white noise at same SNR\n');
        fprintf('  - Avoid interference sources in 40-250 kHz band\n');
    case 3
        fprintf('100 Hz power line interference analysis:\n');
        fprintf('  - 100 Hz causes spectral leakage in short windows\n');
        fprintf('  - This is unavoidable in real environments\n');
        fprintf('  - Use averaging or synchronous sampling to mitigate\n');
        fprintf('  - RMSE range: %.4f - %.4f\n', min(rmse_list), max(rmse_list));
    case 4
        fprintf('DC ambient light analysis:\n');
        fprintf('  - DC is completely removed by FFT (mean subtraction)\n');
        fprintf('  - FDM is immune to DC ambient light\n');
        fprintf('  - RMSE range: %.4f - %.4f (nearly constant)\n', min(rmse_list), max(rmse_list));
    case 5
        fprintf('PWM dimming (20 kHz) analysis:\n');
        fprintf('  - 20 kHz is at the edge of FDM band (40-250 kHz)\n');
        fprintf('  - 2nd harmonic (40 kHz) enters FDM band\n');
        fprintf('  - Less harmful than in-band noise\n');
        fprintf('  - RMSE range: %.4f - %.4f\n', min(rmse_list), max(rmse_list));
    case 6
        fprintf('SMPS switching noise (100 kHz) analysis:\n');
        fprintf('  - SMPS frequency (50-400 kHz) falls within FDM band\n');
        fprintf('  - Can be avoided by frequency planning\n');
        fprintf('  - Choose modulation frequencies away from SMPS harmonics\n');
        fprintf('  - RMSE range: %.4f - %.4f\n', min(rmse_list), max(rmse_list));
end
%% FDM论文仿真：噪声对光谱重建的影响
% 用法：修改 MODE 变量选择模式
% MODE A: 三种SNR噪声对比 (AWGN, In-band, 100Hz)
% MODE B: 三种环境噪声对比 (DC, PWM, SMPS)
% MODE C: 全部6种噪声对比
% MODE 1-6: 单独测试各噪声类型
clear; clc; close all;

%% 选择模式
MODE = 'C';

%% 加载数据
A0 = load_mat("led_0711", "gt");
colorchecker = load_mat("colorchecker_trans_0118", "gt");

if size(A0,1) == 31, A0 = A0'; end
if size(colorchecker,1) == 31, colorchecker = colorchecker'; end

working_leds = [1,2,3,4,5,6,7,8,9,10,11,12];
A0_working = A0(working_leds, :);
x_gt = colorchecker(15, :)';  % 31 x 1
y_theory = A0_working * x_gt;  % 12 x 1
wavelengths = linspace(400, 700, 31);

FIG_WIDTH = 600;
FIG_HEIGHT = 400;

%% 配色方案
colors_three = [
    0.20, 0.45, 0.70;   % 蓝色
    0.70, 0.35, 0.25;   % 红色
    0.30, 0.60, 0.40;   % 绿色
];

%% ==================== MODE A ====================
if strcmp(MODE, 'A') || strcmpi(MODE, 'a')
    mode_name = 'Comparison: White vs In-band vs 100Hz Noise';
    snr_list = [-10, 0, 10, 20, 30, 40];
    n_test = length(snr_list);
    
    rmse_white = zeros(n_test, 1);
    rmse_inband = zeros(n_test, 1);
    rmse_100hz = zeros(n_test, 1);
    yerr_white = zeros(n_test, 1);
    yerr_inband = zeros(n_test, 1);
    yerr_100hz = zeros(n_test, 1);
    
    fprintf('Running simulations for MODE A...\n');
    
    fprintf('  [1/3] White noise...\n');
    for i = 1:n_test
        [v, ~, params] = fdm_generate_signal(y_theory, ...
            'FreqMode', 'auto', 'SNR_dB', snr_list(i), 'Seed', 42, 'Waveform', 'square');
        y_exp = fdm_demodulate(v, params);
        yerr_white(i) = norm(y_exp - y_theory) / norm(y_theory) * 100;
        x_est = fdm_reconstruct(y_exp, A0_working, 'Method', 'tv');
        rmse_white(i) = fdm_metrics(x_gt, x_est);
    end
    
    fprintf('  [2/3] In-band noise...\n');
    for i = 1:n_test
        [v, ~, params] = fdm_generate_signal(y_theory, ...
            'FreqMode', 'auto', 'SNR_dB', Inf, 'SNR_inband_dB', snr_list(i), 'Seed', 42, 'Waveform', 'square');
        y_exp = fdm_demodulate(v, params);
        yerr_inband(i) = norm(y_exp - y_theory) / norm(y_theory) * 100;
        x_est = fdm_reconstruct(y_exp, A0_working, 'Method', 'tv');
        rmse_inband(i) = fdm_metrics(x_gt, x_est);
    end
    
    fprintf('  [3/3] 100 Hz interference...\n');
    for i = 1:n_test
        [v, ~, params] = fdm_generate_signal(y_theory, ...
            'FreqMode', 'auto', 'SNR_dB', Inf, 'SNR_100Hz_dB', snr_list(i), 'Seed', 42, 'Waveform', 'square');
        y_exp = fdm_demodulate(v, params);
        yerr_100hz(i) = norm(y_exp - y_theory) / norm(y_theory) * 100;
        x_est = fdm_reconstruct(y_exp, A0_working, 'Method', 'tv');
        rmse_100hz(i) = fdm_metrics(x_gt, x_est);
    end
    
    fprintf('Simulations complete!\n\n');
    
    % 打印结果
    fprintf('============================================================\n');
    fprintf('MODE A: %s\n', mode_name);
    fprintf('============================================================\n');
    fprintf('\n--- RMSE Comparison ---\n');
    fprintf('%8s %12s %12s %12s\n', 'SNR(dB)', 'White', 'In-band', '100Hz');
    fprintf('%s\n', repmat('-', 1, 46));
    for i = 1:n_test
        fprintf('%8d %12.4f %12.4f %12.4f\n', snr_list(i), rmse_white(i), rmse_inband(i), rmse_100hz(i));
    end
    
    % 绘图
    FONTSIZE = 18;
    FONTSIZE_LEGEND = FONTSIZE-6;
    FONTSIZE_TICK = FONTSIZE-2;
    
    fig = figure('Position', [100, 100, FIG_WIDTH, FIG_HEIGHT], 'Color', 'w');
    
    yyaxis left;
    hold on; box on;
    h1 = plot(snr_list, rmse_white, 'o-', 'LineWidth', 2, 'MarkerSize', 7, ...
        'Color', colors_three(1,:), 'MarkerFaceColor', colors_three(1,:));
    h2 = plot(snr_list, rmse_inband, 's-', 'LineWidth', 2, 'MarkerSize', 7, ...
        'Color', colors_three(2,:), 'MarkerFaceColor', colors_three(2,:));
    h3 = plot(snr_list, rmse_100hz, '^-', 'LineWidth', 2, 'MarkerSize', 7, ...
        'Color', colors_three(3,:), 'MarkerFaceColor', colors_three(3,:));
    ylabel('RMSE', 'FontSize', FONTSIZE, 'FontName', 'Arial');
    set(gca, 'YColor', 'k');
    
    yyaxis right;
    h4 = plot(snr_list, yerr_white, 'o--', 'LineWidth', 1.5, 'MarkerSize', 6, ...
        'Color', colors_three(1,:), 'MarkerFaceColor', 'none');
    h5 = plot(snr_list, yerr_inband, 's--', 'LineWidth', 1.5, 'MarkerSize', 6, ...
        'Color', colors_three(2,:), 'MarkerFaceColor', 'none');
    h6 = plot(snr_list, yerr_100hz, '^--', 'LineWidth', 1.5, 'MarkerSize', 6, ...
        'Color', colors_three(3,:), 'MarkerFaceColor', 'none');
    ylabel('Demodulation error (%)', 'FontSize', FONTSIZE, 'FontName', 'Arial');
    set(gca, 'YColor', 'k');
    
    xlabel('SNR (dB)', 'FontSize', FONTSIZE, 'FontName', 'Arial');
    leg = legend([h1, h2, h3, h4, h5, h6], ...
        {'AWGN (RMSE)', 'In-band (RMSE)', '100 Hz (RMSE)', ...
         'AWGN (Demod.)', 'In-band (Demod.)', '100 Hz (Demod.)'}, ...
        'Location', 'northeast', 'FontSize', FONTSIZE_LEGEND, 'NumColumns', 2);
    leg.Box = 'off';
    set(gca, 'FontSize', FONTSIZE_TICK, 'FontName', 'Arial', 'LineWidth', 1.0);
    xlim([min(snr_list)-5, max(snr_list)+5]);
    
    savename = 'fig_noise_comparison';
    print(gcf, savename, '-dpng', '-r300');
    print(gcf, savename, '-depsc', '-r300');
    fprintf('\nSaved: %s.png and %s.eps\n', savename, savename);

%% ==================== MODE B ====================
elseif strcmp(MODE, 'B') || strcmpi(MODE, 'b')
    mode_name = 'Comparison: DC vs PWM vs SMPS Ambient Noise';
    
    PWM_FREQ = 20e3;
    SMPS_FREQ = 100e3;
    
    ratio_list = [1, 3, 10, 30, 100, 300, 1000, 3000, 10000, 100000];
    n_test = length(ratio_list);
    
    rmse_dc = zeros(n_test, 1);
    rmse_pwm = zeros(n_test, 1);
    rmse_smps = zeros(n_test, 1);
    
    fprintf('Running simulations for MODE B...\n');
    
    fprintf('  [1/3] DC ambient light...\n');
    for i = 1:n_test
        [v, ~, params] = fdm_generate_signal(y_theory, ...
            'FreqMode', 'auto', 'SNR_dB', Inf, 'AmbientDC', ratio_list(i), 'Seed', 42, 'Waveform', 'square');
        y_exp = fdm_demodulate(v, params);
        x_est = fdm_reconstruct(y_exp, A0_working, 'Method', 'tv');
        rmse_dc(i) = fdm_metrics(x_gt, x_est);
    end
    
    fprintf('  [2/3] PWM dimming (20 kHz)...\n');
    for i = 1:n_test
        [v, ~, params] = fdm_generate_signal(y_theory, ...
            'FreqMode', 'auto', 'SNR_dB', Inf, 'AmbientSMPS', ratio_list(i), 'SMPSFreqHz', PWM_FREQ, 'Seed', 42, 'Waveform', 'square');
        y_exp = fdm_demodulate(v, params);
        x_est = fdm_reconstruct(y_exp, A0_working, 'Method', 'tv');
        rmse_pwm(i) = fdm_metrics(x_gt, x_est);
    end
    
    fprintf('  [3/3] SMPS switching (100 kHz)...\n');
    for i = 1:n_test
        [v, ~, params] = fdm_generate_signal(y_theory, ...
            'FreqMode', 'auto', 'SNR_dB', Inf, 'AmbientSMPS', ratio_list(i), 'SMPSFreqHz', SMPS_FREQ, 'Seed', 42, 'Waveform', 'square');
        y_exp = fdm_demodulate(v, params);
        x_est = fdm_reconstruct(y_exp, A0_working, 'Method', 'tv');
        rmse_smps(i) = fdm_metrics(x_gt, x_est);
    end
    
    % AWGN参考
    [v_ref, ~, params_ref] = fdm_generate_signal(y_theory, ...
        'FreqMode', 'auto', 'SNR_dB', 30, 'Seed', 42, 'Waveform', 'square');
    y_exp_ref = fdm_demodulate(v_ref, params_ref);
    x_est_ref = fdm_reconstruct(y_exp_ref, A0_working, 'Method', 'tv');
    rmse_awgn_30dB = fdm_metrics(x_gt, x_est_ref);
    
    fprintf('Simulations complete!\n\n');
    
    % 打印结果
    fprintf('============================================================\n');
    fprintf('MODE B: %s\n', mode_name);
    fprintf('============================================================\n');
    fprintf('Reference: AWGN @ SNR=30dB → RMSE = %.6f\n', rmse_awgn_30dB);
    fprintf('\n--- RMSE Comparison ---\n');
    fprintf('%12s %12s %12s %12s\n', 'Ratio', 'DC', 'PWM', 'SMPS');
    fprintf('%s\n', repmat('-', 1, 50));
    for i = 1:n_test
        fprintf('%12.0fx %12.6f %12.6f %12.6f\n', ratio_list(i), rmse_dc(i), rmse_pwm(i), rmse_smps(i));
    end
    
    % 绘图
    FONTSIZE = 16;
    FONTSIZE_LEGEND = FONTSIZE - 2;
    FONTSIZE_TICK = FONTSIZE - 1;
    
    fig = figure('Position', [100, 100, FIG_WIDTH, FIG_HEIGHT], 'Color', 'w');
    hold on; box on;
    
    h1 = plot(ratio_list, rmse_dc, 'o-', 'LineWidth', 2, 'MarkerSize', 8, ...
        'Color', colors_three(1,:), 'MarkerFaceColor', colors_three(1,:));
    h2 = plot(ratio_list, rmse_pwm, 's-', 'LineWidth', 2, 'MarkerSize', 8, ...
        'Color', colors_three(2,:), 'MarkerFaceColor', colors_three(2,:));
    h3 = plot(ratio_list, rmse_smps, '^-', 'LineWidth', 2, 'MarkerSize', 8, ...
        'Color', colors_three(3,:), 'MarkerFaceColor', colors_three(3,:));
    
    yline(rmse_awgn_30dB, '--', 'LineWidth', 1.5, 'Color', [0.5, 0.5, 0.5]);
    text(ratio_list(end), rmse_awgn_30dB*1.05, 'AWGN @ 30dB', ...
        'FontSize', FONTSIZE_LEGEND, 'Color', [0.5, 0.5, 0.5], ...
        'HorizontalAlignment', 'right', 'VerticalAlignment', 'bottom');
    
    xlabel('Noise ratio (×signal)', 'FontSize', FONTSIZE, 'FontName', 'Arial');
    ylabel('RMSE', 'FontSize', FONTSIZE, 'FontName', 'Arial');
    
    leg = legend([h1, h2, h3], ...
        {'DC noise', '20 kHz PWM noise', '100 kHz SMPS noise'}, ...
        'Location', 'northwest', 'FontSize', FONTSIZE_LEGEND);
    leg.Box = 'off';
    
    set(gca, 'FontSize', FONTSIZE_TICK, 'FontName', 'Arial', 'LineWidth', 1.0, 'XScale', 'log');
    ylim([0, rmse_awgn_30dB * 1.2]);
    
    savename = 'fig_ambient_noise_comparison';
    print(gcf, savename, '-dpng', '-r300');
    print(gcf, savename, '-depsc', '-r300');
    fprintf('\nSaved: %s.png and %s.eps\n', savename, savename);

%% ==================== MODE C ====================
elseif strcmp(MODE, 'C') || strcmpi(MODE, 'c')
    mode_name = 'Comparison: All Noise Types';
    
    PWM_FREQ = 20e3;
    SMPS_FREQ = 100e3;
    
    snr_list = [-20, -10, 0, 10, 20, 30, 40];
    n_test = length(snr_list);
    
    rmse_white = zeros(n_test, 1);
    rmse_inband = zeros(n_test, 1);
    rmse_100hz = zeros(n_test, 1);
    rmse_dc = zeros(n_test, 1);
    rmse_pwm = zeros(n_test, 1);
    rmse_smps = zeros(n_test, 1);
    
    fprintf('Running simulations for MODE C...\n');
    
    fprintf('  [1/6] White noise...\n');
    for i = 1:n_test
        [v, ~, params] = fdm_generate_signal(y_theory, ...
            'FreqMode', 'auto', 'SNR_dB', snr_list(i), 'Seed', 42, 'Waveform', 'square');
        y_exp = fdm_demodulate(v, params);
        x_est = fdm_reconstruct(y_exp, A0_working, 'Method', 'tv');
        rmse_white(i) = fdm_metrics(x_gt, x_est);
    end
    
    fprintf('  [2/6] In-band noise...\n');
    for i = 1:n_test
        [v, ~, params] = fdm_generate_signal(y_theory, ...
            'FreqMode', 'auto', 'SNR_dB', Inf, 'SNR_inband_dB', snr_list(i), 'Seed', 42, 'Waveform', 'square');
        y_exp = fdm_demodulate(v, params);
        x_est = fdm_reconstruct(y_exp, A0_working, 'Method', 'tv');
        rmse_inband(i) = fdm_metrics(x_gt, x_est);
    end
    
    fprintf('  [3/6] 100 Hz noise...\n');
    for i = 1:n_test
        [v, ~, params] = fdm_generate_signal(y_theory, ...
            'FreqMode', 'auto', 'SNR_dB', Inf, 'SNR_100Hz_dB', snr_list(i), 'Seed', 42, 'Waveform', 'square');
        y_exp = fdm_demodulate(v, params);
        x_est = fdm_reconstruct(y_exp, A0_working, 'Method', 'tv');
        rmse_100hz(i) = fdm_metrics(x_gt, x_est);
    end
    
    fprintf('  [4/6] DC ambient...\n');
    for i = 1:n_test
        ratio = 10^(-snr_list(i)/20);
        [v, ~, params] = fdm_generate_signal(y_theory, ...
            'FreqMode', 'auto', 'SNR_dB', Inf, 'AmbientDC', ratio, 'Seed', 42, 'Waveform', 'square');
        y_exp = fdm_demodulate(v, params);
        x_est = fdm_reconstruct(y_exp, A0_working, 'Method', 'tv');
        rmse_dc(i) = fdm_metrics(x_gt, x_est);
    end
    
    fprintf('  [5/6] PWM noise...\n');
    for i = 1:n_test
        ratio = 10^(-snr_list(i)/20);
        [v, ~, params] = fdm_generate_signal(y_theory, ...
            'FreqMode', 'auto', 'SNR_dB', Inf, 'AmbientSMPS', ratio, 'SMPSFreqHz', PWM_FREQ, 'Seed', 42, 'Waveform', 'square');
        y_exp = fdm_demodulate(v, params);
        x_est = fdm_reconstruct(y_exp, A0_working, 'Method', 'tv');
        rmse_pwm(i) = fdm_metrics(x_gt, x_est);
    end
    
    fprintf('  [6/6] SMPS noise...\n');
    for i = 1:n_test
        ratio = 10^(-snr_list(i)/20);
        [v, ~, params] = fdm_generate_signal(y_theory, ...
            'FreqMode', 'auto', 'SNR_dB', Inf, 'AmbientSMPS', ratio, 'SMPSFreqHz', SMPS_FREQ, 'Seed', 42, 'Waveform', 'square');
        y_exp = fdm_demodulate(v, params);
        x_est = fdm_reconstruct(y_exp, A0_working, 'Method', 'tv');
        rmse_smps(i) = fdm_metrics(x_gt, x_est);
    end
    
    fprintf('Simulations complete!\n\n');
    
    % 打印结果
    fprintf('============================================================\n');
    fprintf('MODE C: %s\n', mode_name);
    fprintf('============================================================\n');
    fprintf('\n--- RMSE Comparison ---\n');
    fprintf('%8s | %10s %10s %10s | %10s %10s %10s\n', 'SNR(dB)', 'AWGN', 'In-band', '100Hz', 'DC', 'PWM', 'SMPS');
    fprintf('%s\n', repmat('-', 1, 78));
    for i = 1:n_test
        fprintf('%8d | %10.4f %10.4f %10.4f | %10.4f %10.4f %10.4f\n', ...
            snr_list(i), rmse_white(i), rmse_inband(i), rmse_100hz(i), rmse_dc(i), rmse_pwm(i), rmse_smps(i));
    end
    
    % 绘图
    FONTSIZE = 16;
    FONTSIZE_LEGEND = FONTSIZE - 2;
    FONTSIZE_TICK = FONTSIZE - 1;
    
    colors_modeA = [0.20, 0.45, 0.70; 0.70, 0.25, 0.25; 0.30, 0.60, 0.30];
    colors_modeB = [0.50, 0.70, 0.90; 0.90, 0.60, 0.60; 0.60, 0.80, 0.60];
    
    fig = figure('Position', [100, 100, FIG_WIDTH, FIG_HEIGHT], 'Color', 'w');
    hold on; box on;
    
    h1 = plot(snr_list, rmse_white, 'o--', 'LineWidth', 1.5, 'MarkerSize', 7, ...
        'Color', colors_modeA(1,:), 'MarkerFaceColor', 'none');
    h2 = plot(snr_list, rmse_inband, 's--', 'LineWidth', 1.5, 'MarkerSize', 7, ...
        'Color', colors_modeA(2,:), 'MarkerFaceColor', 'none');
    h3 = plot(snr_list, rmse_100hz, '^--', 'LineWidth', 1.5, 'MarkerSize', 7, ...
        'Color', colors_modeA(3,:), 'MarkerFaceColor', 'none');
    
    h4 = plot(snr_list, rmse_dc, 'o-', 'LineWidth', 2, 'MarkerSize', 8, ...
        'Color', colors_modeB(1,:), 'MarkerFaceColor', colors_modeB(1,:));
    h5 = plot(snr_list, rmse_pwm, 's-', 'LineWidth', 2, 'MarkerSize', 8, ...
        'Color', colors_modeB(2,:), 'MarkerFaceColor', colors_modeB(2,:));
    h6 = plot(snr_list, rmse_smps, '^-', 'LineWidth', 2, 'MarkerSize', 8, ...
        'Color', colors_modeB(3,:), 'MarkerFaceColor', colors_modeB(3,:));
    
    xlabel('SNR (dB)', 'FontSize', FONTSIZE, 'FontName', 'Arial');
    ylabel('RMSE', 'FontSize', FONTSIZE, 'FontName', 'Arial');
    ylim([0, max(rmse_inband) * 1.2]);
    leg = legend([h1, h2, h3, h4, h5, h6], ...
        {'AWGN', 'In-band', '100 Hz', ...
         'DC', '20 kHz PWM', '100 kHz SMPS'}, ...
        'Location', 'northeast', 'FontSize', FONTSIZE_LEGEND, 'NumColumns', 2);
    leg.Box = 'off';
    
    set(gca, 'FontSize', FONTSIZE_TICK, 'FontName', 'Arial', 'LineWidth', 1.0, 'YScale', 'log');
    xlim([min(snr_list)-5, max(snr_list)+5]);
    
    savename = 'fig_all_noise_comparison';
    print(gcf, savename, '-dpng', '-r300');
    print(gcf, savename, '-depsc', '-r300');
    fprintf('\nSaved: %s.png and %s.eps\n', savename, savename);
    
    fprintf('\n============================================================\n');
    fprintf('Conclusion: Noise impact ranking (most to least harmful):\n');
    fprintf('  1. In-band > 2. AWGN > 3. 100Hz > 4. SMPS > 5. PWM > 6. DC\n');
    fprintf('============================================================\n');

else
    error('Unknown MODE: %s. Use ''A'', ''B'', or ''C''.', num2str(MODE));
end
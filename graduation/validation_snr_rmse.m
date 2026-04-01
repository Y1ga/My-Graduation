%% FDM论文仿真：噪声对光谱重建的影响
% 用法：修改 MODE 变量选择模式
% MODE A: 三种SNR噪声对比 (AWGN, In-band, 100Hz)
% MODE B: 三种环境噪声对比 (DC, PWM, SMPS)
% MODE C: 全部6种噪声对比
% MODE 1-6: 单独测试各噪声类型
clear; clc; close all;

%% 选择模式
MODE = '1';

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
    
    % 使用与 MODE C 相同的 SNR 范围
    snr_list = [-20, -10, 0, 10, 20, 30, 40];
    n_test = length(snr_list);
    
    rmse_dc = zeros(n_test, 1);
    rmse_pwm = zeros(n_test, 1);
    rmse_smps = zeros(n_test, 1);
    
    fprintf('Running simulations for MODE B...\n');
    
    fprintf('  [1/3] DC ambient light...\n');
    for i = 1:n_test
        ratio = 10^(-snr_list(i)/20);  % SNR转换为ratio
        [v, ~, params] = fdm_generate_signal(y_theory, ...
            'FreqMode', 'auto', 'SNR_dB', Inf, 'AmbientDC', ratio, 'Seed', 42, 'Waveform', 'square');
        y_exp = fdm_demodulate(v, params);
        x_est = fdm_reconstruct(y_exp, A0_working, 'Method', 'tv');
        rmse_dc(i) = fdm_metrics(x_gt, x_est);
    end
    
    fprintf('  [2/3] PWM dimming (20 kHz)...\n');
    for i = 1:n_test
        ratio = 10^(-snr_list(i)/20);  % SNR转换为ratio
        [v, ~, params] = fdm_generate_signal(y_theory, ...
            'FreqMode', 'auto', 'SNR_dB', Inf, 'AmbientSMPS', ratio, 'SMPSFreqHz', PWM_FREQ, 'Seed', 42, 'Waveform', 'square');
        y_exp = fdm_demodulate(v, params);
        x_est = fdm_reconstruct(y_exp, A0_working, 'Method', 'tv');
        rmse_pwm(i) = fdm_metrics(x_gt, x_est);
    end
    
    fprintf('  [3/3] SMPS switching (100 kHz)...\n');
    for i = 1:n_test
        ratio = 10^(-snr_list(i)/20);  % SNR转换为ratio
        [v, ~, params] = fdm_generate_signal(y_theory, ...
            'FreqMode', 'auto', 'SNR_dB', Inf, 'AmbientSMPS', ratio, 'SMPSFreqHz', SMPS_FREQ, 'Seed', 42, 'Waveform', 'square');
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
    fprintf('%8s %12s %12s %12s\n', 'SNR(dB)', 'DC', 'PWM', 'SMPS');
    fprintf('%s\n', repmat('-', 1, 46));
    for i = 1:n_test
        fprintf('%8d %12.6f %12.6f %12.6f\n', snr_list(i), rmse_dc(i), rmse_pwm(i), rmse_smps(i));
    end
    
    % 绘图
    FONTSIZE = 16;
    FONTSIZE_LEGEND = FONTSIZE - 2;
    FONTSIZE_TICK = FONTSIZE - 1;
    
    fig = figure('Position', [100, 100, FIG_WIDTH, FIG_HEIGHT], 'Color', 'w');
    hold on; box on;
    
    h1 = plot(snr_list, rmse_dc, 'o-', 'LineWidth', 2, 'MarkerSize', 8, ...
        'Color', colors_three(1,:), 'MarkerFaceColor', colors_three(1,:));
    h2 = plot(snr_list, rmse_pwm, 's-', 'LineWidth', 2, 'MarkerSize', 8, ...
        'Color', colors_three(2,:), 'MarkerFaceColor', colors_three(2,:));
    h3 = plot(snr_list, rmse_smps, '^-', 'LineWidth', 2, 'MarkerSize', 8, ...
        'Color', colors_three(3,:), 'MarkerFaceColor', colors_three(3,:));
    
    yline(rmse_awgn_30dB, '--', 'LineWidth', 1.5, 'Color', [0.5, 0.5, 0.5]);

    
    xlabel('SNR (dB)', 'FontSize', FONTSIZE, 'FontName', 'Arial');
    ylabel('RMSE', 'FontSize', FONTSIZE, 'FontName', 'Arial');
    
    leg = legend([h1, h2, h3], ...
        {'DC noise', '20 kHz PWM noise', '100 kHz SMPS noise'}, ...
        'Location', 'northeast', 'FontSize', FONTSIZE_LEGEND);
    leg.Box = 'off';
    
    set(gca, 'FontSize', FONTSIZE_TICK, 'FontName', 'Arial', 'LineWidth', 1.0);
    xlim([min(snr_list)-5, max(snr_list)+5]);
    ylim([0, 0.2]);
    
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
%% ==================== MODE 1: AWGN ====================
elseif strcmp(MODE, '1')
    mode_name = 'AWGN Noise Only';
    
    snr_list = [-20, -10, 0, 10, 20, 30, 40];
    n_test = length(snr_list);
    
    rmse_fdm = zeros(n_test, 1);
    rmse_tdm = zeros(n_test, 1);
    yerr_fdm = zeros(n_test, 1);
    yerr_tdm = zeros(n_test, 1);
    
    % TDM参数
    N_LED = length(working_leds);
    Fs = 10e6;
    T_total = 100e-6;
    T_slot = T_total / N_LED;
    N_slot = round(Fs * T_slot);
    N_total = N_LED * N_slot;
    
    % 生成无噪声FDM信号，获取信号功率作为噪声基准
    [v_fdm_clean, ~, params_clean] = fdm_generate_signal(y_theory, ...
        'FreqMode', 'auto', 'SNR_dB', Inf, 'Seed', 42, 'Waveform', 'square');
    P_signal = var(v_fdm_clean);
    
    fprintf('Running simulations for MODE 1 (AWGN)...\n');
    
    for i = 1:n_test
        noise_var = P_signal / (10^(snr_list(i)/10));
        noise_std = sqrt(noise_var);
        
        %% FDM
        [v_fdm, ~, params_fdm] = fdm_generate_signal(y_theory, ...
            'FreqMode', 'auto', 'SNR_dB', snr_list(i), 'Seed', 42, 'Waveform', 'square');
        y_fdm = fdm_demodulate(v_fdm, params_fdm);
        yerr_fdm(i) = norm(y_fdm - y_theory) / norm(y_theory) * 100;
        x_fdm = fdm_reconstruct(y_fdm, A0_working, 'Method', 'tv');
        rmse_fdm(i) = fdm_metrics(x_gt, x_fdm);
        
        %% TDM
        % 生成TDM信号
        t_tdm = (0:N_total-1) / Fs;
        v_tdm_clean = zeros(1, N_total);
        for k = 1:N_LED
            idx_s = (k-1)*N_slot + 1;
            idx_e = k*N_slot;
            v_tdm_clean(idx_s:idx_e) = y_theory(k);
        end
        
        % 加相同功率的AWGN
        rng(42);
        v_tdm = v_tdm_clean + noise_std * randn(1, N_total);
        
        % TDM解调：每个时间槽取平均
        y_tdm = zeros(N_LED, 1);
        for k = 1:N_LED
            idx_s = (k-1)*N_slot + 1;
            idx_e = k*N_slot;
            y_tdm(k) = mean(v_tdm(idx_s:idx_e));
        end
        yerr_tdm(i) = norm(y_tdm - y_theory) / norm(y_theory) * 100;
        x_tdm = fdm_reconstruct(y_tdm, A0_working, 'Method', 'tv');
        rmse_tdm(i) = fdm_metrics(x_gt, x_tdm);
    end
    
    fprintf('Simulations complete!\n\n');
    
    % 打印结果
    fprintf('============================================================\n');
    fprintf('MODE 1: %s\n', mode_name);
    fprintf('============================================================\n');
    fprintf('%8s %12s %12s %12s %12s\n', 'SNR(dB)', 'FDM_RMSE', 'TDM_RMSE', 'FDM_Yerr%', 'TDM_Yerr%');
    fprintf('%s\n', repmat('-', 1, 58));
    for i = 1:n_test
        fprintf('%8d %12.4f %12.4f %12.2f %12.2f\n', ...
            snr_list(i), rmse_fdm(i), rmse_tdm(i), yerr_fdm(i), yerr_tdm(i));
    end
    
    % 绘图
    FONTSIZE = 18;
    FONTSIZE_LEGEND = FONTSIZE - 4;
    FONTSIZE_TICK = FONTSIZE - 2;
    LINE_WIDTH = 2;
    
    color_fdm = [0.20, 0.45, 0.70];
    color_tdm = [0.70, 0.35, 0.25];
    
    fig = figure('Position', [100, 100, FIG_WIDTH, FIG_HEIGHT], 'Color', 'w');
    
    yyaxis left;
    hold on; box on;
    h1 = plot(snr_list, rmse_fdm, 'o-', 'LineWidth', LINE_WIDTH, 'MarkerSize', 7, ...
        'Color', color_fdm, 'MarkerFaceColor', color_fdm);
    h2 = plot(snr_list, rmse_tdm, 's-', 'LineWidth', LINE_WIDTH, 'MarkerSize', 7, ...
        'Color', color_tdm, 'MarkerFaceColor', color_tdm);
    ylabel('RMSE', 'FontSize', FONTSIZE, 'FontName', 'Arial');
    set(gca, 'YColor', 'k');
    
    yyaxis right;
    h3 = plot(snr_list, yerr_fdm, 'o--', 'LineWidth', 1.5, 'MarkerSize', 6, ...
        'Color', color_fdm, 'MarkerFaceColor', 'none');
    h4 = plot(snr_list, yerr_tdm, 's--', 'LineWidth', 1.5, 'MarkerSize', 6, ...
        'Color', color_tdm, 'MarkerFaceColor', 'none');
    ylabel('Demodulation Error (%)', 'FontSize', FONTSIZE, 'FontName', 'Arial');
    set(gca, 'YColor', 'k');
    
    xlabel('SNR (dB)', 'FontSize', FONTSIZE, 'FontName', 'Arial');
    leg = legend([h1, h2, h3, h4], ...
        {'FDM (RMSE)', 'TDM (RMSE)', 'FDM (Demod.)', 'TDM (Demod.)'}, ...
        'Location', 'northeast', 'FontSize', FONTSIZE_LEGEND);
    leg.Box = 'off';
    set(gca, 'FontSize', FONTSIZE_TICK, 'FontName', 'Arial', 'LineWidth', 1.0);
    xlim([min(snr_list)-5, max(snr_list)+5]);
    
    savename = 'fig_awgn_fdm_vs_tdm';
    print(gcf, savename, '-dpng', '-r300');
    print(gcf, savename, '-depsc', '-r300');
    fprintf('\nSaved: %s.png and %s.eps\n', savename, savename);
else
    error('Unknown MODE: %s. Use ''A'', ''B'', or ''C''.', num2str(MODE));
end
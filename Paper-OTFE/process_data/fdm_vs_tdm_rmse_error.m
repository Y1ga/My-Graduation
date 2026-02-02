%% TDM vs OFE 对比仿真
% MODE 1: AWGN噪声
% MODE 2: 带内噪声 (可选 gaussian 或 multitone)
% MODE 3: 综合对比
%   DUAL_AXIS = false: 双子图 (左RMSE，右解调误差)
%   DUAL_AXIS = true:  单图双Y轴 (左RMSE，右解调误差)
clear; clc; close all;

%% 选择模式
MODE = 3;
DUAL_AXIS = true;   % true: 单图双Y轴; false: 双子图
SHOW_GRID = false;  % true: 显示网格; false: 不显示网格

%% 带内噪声模式设置
% 'gaussian':  带限高斯白噪声 (连续功率谱)
% 'multitone': 多音干扰模型 (离散谱线)
INBAND_NOISE_MODE = 'multitone';
INBAND_NUM_TONES = 1;  % 多音干扰的音调数量 M

%% 多音干扰是否避开调制频率
% false: 多音频率随机分布在带内（可能与调制频率重叠）
% true:  多音频率避开调制频率±GuardBand范围
INBAND_AVOID_CARRIER = true;
INBAND_GUARD_BAND = 25e3;  % 保护带宽 Hz (最大约25kHz，否则无可用空间)

%% 加载数据
A0 = load_mat("led_0711", "gt");
colorchecker = load_mat("colorchecker_trans_0118", "gt");

if size(A0,1) == 31, A0 = A0'; end
if size(colorchecker,1) == 31, colorchecker = colorchecker'; end

working_leds = 1:12;
A0_working = A0(working_leds, :);
x_gt = colorchecker(15, :)';
y_theory = A0_working * x_gt;

N_LED = length(working_leds);
y_norm = norm(y_theory);

%% 公共参数
Fs = 10e6;
T_total = 100e-6;

T_fdm = T_total;
N_fdm = round(Fs * T_fdm);
T_slot = T_total / N_LED;
N_slot = round(Fs * T_slot);

% 带内噪声频率范围
f_inband_low = 30e3;
f_inband_high = 410e3;

%% 图形参数 (适配18cm宽度)
FIG_WIDTH_CM = 18;      % 图像宽度 (cm)
FIG_HEIGHT_CM = 14;     % 图像高度 (cm)
FIG_WIDTH_CM_DUAL = 36; % 双子图宽度 (cm)

FONTSIZE = 18;
FONTSIZE_LEGEND = FONTSIZE - 2;
FONTSIZE_TICK = FONTSIZE - 2;
MARKER_SIZE = 10;
LINE_WIDTH = 2;
LINE_WIDTH_AXIS = 0.5;
SHOW_GRID = false;

% 颜色定义
color_fdm_awgn = [0.20, 0.45, 0.70];      % 蓝色
color_tdm_awgn = [0.85, 0.35, 0.25];      % 红色
color_fdm_inband = [0.30, 0.70, 0.50];    % 绿色
color_tdm_inband = [0.80, 0.50, 0.20];    % 橙色

%% ==================== MODE 1: AWGN ====================
if MODE == 1
    mode_name = 'TDM vs OFE: AWGN';
    
    snr_list = -10:5:40;
    n_test = length(snr_list);
    N_trials = 50;
    
    DemodErr_fdm = zeros(n_test, N_trials);
    DemodErr_tdm = zeros(n_test, N_trials);
    RMSE_fdm = zeros(n_test, N_trials);
    RMSE_tdm = zeros(n_test, N_trials);
    
    [v_fdm_clean, ~, params_clean] = fdm_generate_signal(y_theory, ...
        'FreqMode', 'auto', 'T', T_fdm, 'Fs', Fs, ...
        'SNR_dB', Inf, 'Seed', 1, 'Waveform', 'sine');
    P_signal_fdm = var(v_fdm_clean);
    
    ratio_theory = sqrt(N_LED / 2);
    
    fprintf('============================================================\n');
    fprintf('MODE 1: %s\n', mode_name);
    fprintf('DUAL_AXIS = %s, SHOW_GRID = %s\n', mat2str(DUAL_AXIS), mat2str(SHOW_GRID));
    fprintf('理论比值: √(N/2) = %.2f\n', ratio_theory);
    fprintf('============================================================\n\n');
    
    fprintf('Running simulations...\n');
    for idx_snr = 1:n_test
        SNR_dB = snr_list(idx_snr);
        noise_variance = P_signal_fdm / (10^(SNR_dB/10));
        noise_std = sqrt(noise_variance);
        
        for trial = 1:N_trials
            seed = trial;
            
            [v_fdm, t_fdm, params_fdm] = fdm_generate_signal(y_theory, ...
                'FreqMode', 'auto', 'T', T_fdm, 'Fs', Fs, ...
                'SNR_dB', SNR_dB, 'Seed', seed, 'Waveform', 'sine');
            
            y_fdm_recovered = fdm_lockin_demod(v_fdm, t_fdm, params_fdm);
            DemodErr_fdm(idx_snr, trial) = norm(y_fdm_recovered - y_theory) / y_norm * 100;
            x_est_fdm = fdm_reconstruct(y_fdm_recovered, A0_working, 'Method', 'tv');
            RMSE_fdm(idx_snr, trial) = fdm_metrics(x_gt, x_est_fdm);
            
            rng(seed);
            y_tdm_recovered = zeros(N_LED, 1);
            for i = 1:N_LED
                v_slot = y_theory(i) + noise_std * randn(1, N_slot);
                y_tdm_recovered(i) = mean(v_slot);
            end
            DemodErr_tdm(idx_snr, trial) = norm(y_tdm_recovered - y_theory) / y_norm * 100;
            x_est_tdm = fdm_reconstruct(y_tdm_recovered, A0_working, 'Method', 'tv');
            RMSE_tdm(idx_snr, trial) = fdm_metrics(x_gt, x_est_tdm);
        end
        fprintf('  SNR = %3d dB done\n', SNR_dB);
    end
    
    DemodErr_fdm_mean = mean(DemodErr_fdm, 2);
    DemodErr_tdm_mean = mean(DemodErr_tdm, 2);
    RMSE_fdm_mean = mean(RMSE_fdm, 2);
    RMSE_tdm_mean = mean(RMSE_tdm, 2);
    
    fprintf('\n============================================================\n');
    fprintf('%8s | %10s %10s | %10s %10s\n', 'SNR(dB)', 'RMSE_OFE', 'RMSE_TDM', 'Demod_OFE', 'Demod_TDM');
    fprintf('%s\n', repmat('-', 1, 60));
    for i = 1:n_test
        fprintf('%8d | %10.4f %10.4f | %10.2f%% %10.2f%%\n', ...
            snr_list(i), RMSE_fdm_mean(i), RMSE_tdm_mean(i), ...
            DemodErr_fdm_mean(i), DemodErr_tdm_mean(i));
    end
    fprintf('============================================================\n');
    
    %% 绘图
    if DUAL_AXIS
        %% 单图双Y轴模式
        fig = figure('Units', 'centimeters', 'Position', [2, 2, FIG_WIDTH_CM, FIG_HEIGHT_CM], 'Color', 'w');
        set(fig, 'PaperUnits', 'centimeters', 'PaperSize', [FIG_WIDTH_CM, FIG_HEIGHT_CM], ...
            'PaperPosition', [0, 0, FIG_WIDTH_CM, FIG_HEIGHT_CM]);
        
        % 左Y轴: RMSE
        yyaxis left;
        hold on; box on;
        
        h1 = plot(snr_list, RMSE_fdm_mean, 'o-', 'LineWidth', LINE_WIDTH, 'MarkerSize', MARKER_SIZE, ...
            'Color', color_fdm_awgn, 'MarkerFaceColor', color_fdm_awgn);
        h2 = plot(snr_list, RMSE_tdm_mean, 's-', 'LineWidth', LINE_WIDTH, 'MarkerSize', MARKER_SIZE, ...
            'Color', color_tdm_awgn, 'MarkerFaceColor', color_tdm_awgn);
        
        ylabel('RMSE', 'FontSize', FONTSIZE, 'FontName', 'Arial');
        set(gca, 'YColor', 'k', 'YScale', 'log');
        
        % 右Y轴: 解调误差
        yyaxis right;
        
        h3 = plot(snr_list, DemodErr_fdm_mean, 'o-', 'LineWidth', LINE_WIDTH, 'MarkerSize', MARKER_SIZE-1, ...
            'Color', color_fdm_awgn, 'MarkerFaceColor', 'w');
        h4 = plot(snr_list, DemodErr_tdm_mean, 's-', 'LineWidth', LINE_WIDTH, 'MarkerSize', MARKER_SIZE-1, ...
            'Color', color_tdm_awgn, 'MarkerFaceColor', 'w');
        
        ylabel('Demodulation Error (%)', 'FontSize', FONTSIZE, 'FontName', 'Arial');
        set(gca, 'YColor', 'k', 'YScale', 'log');
        
        xlabel('SNR (dB)', 'FontSize', FONTSIZE, 'FontName', 'Arial');
        
        leg = legend([h1, h2, h3, h4], ...
            {'OFE (RMSE)', 'TDM (RMSE)', 'OFE (Demod)', 'TDM (Demod)'}, ...
            'Location', 'northeast', 'FontSize', FONTSIZE_LEGEND, 'NumColumns', 2);
        leg.Box = 'off';
        
        set(gca, 'FontSize', FONTSIZE_TICK, 'FontName', 'Arial', 'LineWidth', LINE_WIDTH_AXIS);
        if SHOW_GRID
            grid on;
            set(gca, 'GridLineStyle', ':', 'GridAlpha', 0.3);
        end
        xlim([min(snr_list)-2, max(snr_list)+2]);
        
        savename = 'fig_tdm_vs_fdm_awgn_dual';
        
    else
        %% 双子图模式
        fig = figure('Units', 'centimeters', 'Position', [2, 2, FIG_WIDTH_CM_DUAL, FIG_HEIGHT_CM], 'Color', 'w');
        set(fig, 'PaperUnits', 'centimeters', 'PaperSize', [FIG_WIDTH_CM_DUAL, FIG_HEIGHT_CM], ...
            'PaperPosition', [0, 0, FIG_WIDTH_CM_DUAL, FIG_HEIGHT_CM]);
        
        % 左图: RMSE
        subplot(1, 2, 1);
        hold on; box on;
        
        h1 = plot(snr_list, RMSE_fdm_mean, 'o-', 'LineWidth', LINE_WIDTH, 'MarkerSize', MARKER_SIZE, ...
            'Color', color_fdm_awgn, 'MarkerFaceColor', color_fdm_awgn);
        h2 = plot(snr_list, RMSE_tdm_mean, 's-', 'LineWidth', LINE_WIDTH, 'MarkerSize', MARKER_SIZE, ...
            'Color', color_tdm_awgn, 'MarkerFaceColor', color_tdm_awgn);
        
        set(gca, 'YScale', 'log');
        xlabel('SNR (dB)', 'FontSize', FONTSIZE);
        ylabel('RMSE', 'FontSize', FONTSIZE);
        
        leg1 = legend([h1, h2], {'OFE', 'TDM'}, 'Location', 'northeast', 'FontSize', FONTSIZE_LEGEND);
        leg1.Box = 'off';
        
        set(gca, 'FontSize', FONTSIZE_TICK, 'LineWidth', LINE_WIDTH_AXIS);
        if SHOW_GRID
            grid on;
            set(gca, 'GridLineStyle', ':', 'GridAlpha', 0.3);
        end
        xlim([min(snr_list)-2, max(snr_list)+2]);
        
        % 右图: 解调误差
        subplot(1, 2, 2);
        hold on; box on;
        
        h3 = plot(snr_list, DemodErr_fdm_mean, 'o-', 'LineWidth', LINE_WIDTH, 'MarkerSize', MARKER_SIZE, ...
            'Color', color_fdm_awgn, 'MarkerFaceColor', color_fdm_awgn);
        h4 = plot(snr_list, DemodErr_tdm_mean, 's-', 'LineWidth', LINE_WIDTH, 'MarkerSize', MARKER_SIZE, ...
            'Color', color_tdm_awgn, 'MarkerFaceColor', color_tdm_awgn);
        
        set(gca, 'YScale', 'log');
        xlabel('SNR (dB)', 'FontSize', FONTSIZE);
        ylabel('Demodulation Error (%)', 'FontSize', FONTSIZE);
        
        leg2 = legend([h3, h4], {'OFE', 'TDM'}, 'Location', 'northeast', 'FontSize', FONTSIZE_LEGEND);
        leg2.Box = 'off';
        
        set(gca, 'FontSize', FONTSIZE_TICK, 'LineWidth', LINE_WIDTH_AXIS);
        if SHOW_GRID
            grid on;
            set(gca, 'GridLineStyle', ':', 'GridAlpha', 0.3);
        end
        xlim([min(snr_list)-2, max(snr_list)+2]);
        
        savename = 'fig_tdm_vs_fdm_awgn';
    end
    
    print(gcf, savename, '-dpng', '-r300');
    print(gcf, savename, '-depsc', '-r300');
    fprintf('\nSaved: %s.png and %s.eps\n', savename, savename);

%% ==================== MODE 2: 带内噪声 ====================
elseif MODE == 2
    if strcmpi(INBAND_NOISE_MODE, 'multitone')
        if INBAND_AVOID_CARRIER
            mode_name = sprintf('TDM vs OFE: Multi-tone (M=%d, Avoid Carrier)', INBAND_NUM_TONES);
        else
            mode_name = sprintf('TDM vs OFE: Multi-tone (M=%d, Overlap)', INBAND_NUM_TONES);
        end
    else
        mode_name = 'TDM vs OFE: Band-limited Gaussian Noise';
    end
    
    snr_list = -10:5:40;
    n_test = length(snr_list);
    N_trials = 50;
    
    DemodErr_fdm = zeros(n_test, N_trials);
    DemodErr_tdm = zeros(n_test, N_trials);
    RMSE_fdm = zeros(n_test, N_trials);
    RMSE_tdm = zeros(n_test, N_trials);
    
    [v_fdm_clean, ~, params_clean] = fdm_generate_signal(y_theory, ...
        'FreqMode', 'auto', 'T', T_fdm, 'Fs', Fs, ...
        'SNR_dB', Inf, 'Seed', 1, 'Waveform', 'sine');
    P_signal_fdm = var(v_fdm_clean);
    freqs_Hz = params_clean.FreqsHz;
    
    fprintf('============================================================\n');
    fprintf('MODE 2: %s\n', mode_name);
    fprintf('DUAL_AXIS = %s, SHOW_GRID = %s\n', mat2str(DUAL_AXIS), mat2str(SHOW_GRID));
    fprintf('OFE调制频率: %.0f - %.0f kHz\n', min(freqs_Hz)/1e3, max(freqs_Hz)/1e3);
    fprintf('带内噪声频带: %.0f - %.0f kHz\n', f_inband_low/1e3, f_inband_high/1e3);
    fprintf('带内噪声模式: %s\n', INBAND_NOISE_MODE);
    if strcmpi(INBAND_NOISE_MODE, 'multitone')
        fprintf('多音数量 M = %d\n', INBAND_NUM_TONES);
        fprintf('避开调制频率: %s\n', mat2str(INBAND_AVOID_CARRIER));
        if INBAND_AVOID_CARRIER
            fprintf('保护带宽: %.0f Hz\n', INBAND_GUARD_BAND);
        end
    end
    fprintf('============================================================\n\n');
    
    fprintf('Running simulations...\n');
    for idx_snr = 1:n_test
        SNR_dB = snr_list(idx_snr);
        noise_variance = P_signal_fdm / (10^(SNR_dB/10));
        noise_std = sqrt(noise_variance);
        
        for trial = 1:N_trials
            seed = trial;
            
            %% OFE + 带内噪声
            [v_fdm, t_fdm, params_fdm] = fdm_generate_signal(y_theory, ...
                'FreqMode', 'auto', 'T', T_fdm, 'Fs', Fs, ...
                'SNR_dB', Inf, 'SNR_inband_dB', SNR_dB, ...
                'InbandNoiseMode', INBAND_NOISE_MODE, ...
                'InbandNumTones', INBAND_NUM_TONES, ...
                'InbandFreqRange', [f_inband_low, f_inband_high], ...
                'InbandAvoidCarrier', INBAND_AVOID_CARRIER, ...
                'InbandGuardBand', INBAND_GUARD_BAND, ...
                'Seed', seed, 'Waveform', 'sine');
            
            y_fdm_recovered = fdm_lockin_demod(v_fdm, t_fdm, params_fdm);
            DemodErr_fdm(idx_snr, trial) = norm(y_fdm_recovered - y_theory) / y_norm * 100;
            x_est_fdm = fdm_reconstruct(y_fdm_recovered, A0_working, 'Method', 'tv');
            RMSE_fdm(idx_snr, trial) = fdm_metrics(x_gt, x_est_fdm);
            
            %% TDM + 带内噪声
            rng(seed);
            N_total = N_LED * N_slot;
            t_tdm = (0:N_total-1) / Fs;
            
            if strcmpi(INBAND_NOISE_MODE, 'multitone')
                M = INBAND_NUM_TONES;
                
                if INBAND_AVOID_CARRIER
                    f_tones = zeros(1, M);
                    for j = 1:M
                        max_attempts = 1000;
                        attempts = 0;
                        while attempts < max_attempts
                            f_candidate = f_inband_low + (f_inband_high - f_inband_low) * rand();
                            if all(abs(f_candidate - freqs_Hz) > INBAND_GUARD_BAND)
                                f_tones(j) = f_candidate;
                                break;
                            end
                            attempts = attempts + 1;
                        end
                        if attempts >= max_attempts
                            f_tones(j) = f_inband_low + (f_inband_high - f_inband_low) * rand();
                        end
                    end
                else
                    f_tones = f_inband_low + (f_inband_high - f_inband_low) * rand(1, M);
                end
                
                phi_tones = 2 * pi * rand(1, M);
                
                noise_inband = zeros(1, N_total);
                for j = 1:M
                    noise_inband = noise_inband + cos(2*pi*f_tones(j)*t_tdm + phi_tones(j));
                end
                noise_inband = noise_inband * sqrt(noise_variance / var(noise_inband));
            else
                noise_raw = noise_std * randn(1, N_total);
                f_low_norm = f_inband_low / (Fs/2);
                f_high_norm = min(f_inband_high / (Fs/2), 0.99);
                [b, a] = butter(4, [f_low_norm, f_high_norm], 'bandpass');
                noise_inband = filter(b, a, noise_raw);
                noise_inband = noise_inband * sqrt(noise_variance / var(noise_inband));
            end
            
            y_tdm_recovered = zeros(N_LED, 1);
            for i = 1:N_LED
                idx_start = (i-1) * N_slot + 1;
                idx_end = i * N_slot;
                v_slot = y_theory(i) + noise_inband(idx_start:idx_end);
                y_tdm_recovered(i) = mean(v_slot);
            end
            DemodErr_tdm(idx_snr, trial) = norm(y_tdm_recovered - y_theory) / y_norm * 100;
            x_est_tdm = fdm_reconstruct(y_tdm_recovered, A0_working, 'Method', 'tv');
            RMSE_tdm(idx_snr, trial) = fdm_metrics(x_gt, x_est_tdm);
        end
        fprintf('  SNR = %3d dB done\n', SNR_dB);
    end
    
    DemodErr_fdm_mean = mean(DemodErr_fdm, 2);
    DemodErr_tdm_mean = mean(DemodErr_tdm, 2);
    RMSE_fdm_mean = mean(RMSE_fdm, 2);
    RMSE_tdm_mean = mean(RMSE_tdm, 2);
    
    fprintf('\n============================================================\n');
    fprintf('%8s | %10s %10s | %10s %10s\n', 'SNR(dB)', 'RMSE_OFE', 'RMSE_TDM', 'Demod_OFE', 'Demod_TDM');
    fprintf('%s\n', repmat('-', 1, 60));
    for i = 1:n_test
        fprintf('%8d | %10.4f %10.4f | %10.2f%% %10.2f%%\n', ...
            snr_list(i), RMSE_fdm_mean(i), RMSE_tdm_mean(i), ...
            DemodErr_fdm_mean(i), DemodErr_tdm_mean(i));
    end
    fprintf('============================================================\n');
    
    %% 绘图
    if DUAL_AXIS
        %% 单图双Y轴模式
        fig = figure('Units', 'centimeters', 'Position', [2, 2, FIG_WIDTH_CM, FIG_HEIGHT_CM], 'Color', 'w');
        set(fig, 'PaperUnits', 'centimeters', 'PaperSize', [FIG_WIDTH_CM, FIG_HEIGHT_CM], ...
            'PaperPosition', [0, 0, FIG_WIDTH_CM, FIG_HEIGHT_CM]);
        
        yyaxis left;
        hold on; box on;
        
        h1 = plot(snr_list, RMSE_fdm_mean, 'o-', 'LineWidth', LINE_WIDTH, 'MarkerSize', MARKER_SIZE, ...
            'Color', color_fdm_inband, 'MarkerFaceColor', color_fdm_inband);
        h2 = plot(snr_list, RMSE_tdm_mean, 's-', 'LineWidth', LINE_WIDTH, 'MarkerSize', MARKER_SIZE, ...
            'Color', color_tdm_inband, 'MarkerFaceColor', color_tdm_inband);
        
        ylabel('RMSE', 'FontSize', FONTSIZE, 'FontName', 'Arial');
        set(gca, 'YColor', 'k', 'YScale', 'log');
        
        yyaxis right;
        
        h3 = plot(snr_list, DemodErr_fdm_mean, 'o-', 'LineWidth', LINE_WIDTH, 'MarkerSize', MARKER_SIZE-1, ...
            'Color', color_fdm_inband, 'MarkerFaceColor', 'w');
        h4 = plot(snr_list, DemodErr_tdm_mean, 's-', 'LineWidth', LINE_WIDTH, 'MarkerSize', MARKER_SIZE-1, ...
            'Color', color_tdm_inband, 'MarkerFaceColor', 'w');
        
        ylabel('Demodulation Error (%)', 'FontSize', FONTSIZE, 'FontName', 'Arial');
        set(gca, 'YColor', 'k', 'YScale', 'log');
        
        xlabel('SNR (dB)', 'FontSize', FONTSIZE, 'FontName', 'Arial');
        
        leg = legend([h1, h2, h3, h4], ...
            {'OFE (RMSE)', 'TDM (RMSE)', 'OFE (Demod)', 'TDM (Demod)'}, ...
            'Location', 'northeast', 'FontSize', FONTSIZE_LEGEND, 'NumColumns', 2);
        leg.Box = 'off';
        
        set(gca, 'FontSize', FONTSIZE_TICK, 'FontName', 'Arial', 'LineWidth', LINE_WIDTH_AXIS);
        if SHOW_GRID
            grid on;
            set(gca, 'GridLineStyle', ':', 'GridAlpha', 0.3);
        end
        xlim([min(snr_list)-2, max(snr_list)+2]);
        
        if INBAND_AVOID_CARRIER
            savename = sprintf('fig_tdm_vs_fdm_%s_avoid_dual', INBAND_NOISE_MODE);
        else
            savename = sprintf('fig_tdm_vs_fdm_%s_overlap_dual', INBAND_NOISE_MODE);
        end
        
    else
        %% 双子图模式
        fig = figure('Units', 'centimeters', 'Position', [2, 2, FIG_WIDTH_CM_DUAL, FIG_HEIGHT_CM], 'Color', 'w');
        set(fig, 'PaperUnits', 'centimeters', 'PaperSize', [FIG_WIDTH_CM_DUAL, FIG_HEIGHT_CM], ...
            'PaperPosition', [0, 0, FIG_WIDTH_CM_DUAL, FIG_HEIGHT_CM]);
        
        % 左图: RMSE
        subplot(1, 2, 1);
        hold on; box on;
        
        h1 = plot(snr_list, RMSE_fdm_mean, 'o-', 'LineWidth', LINE_WIDTH, 'MarkerSize', MARKER_SIZE, ...
            'Color', color_fdm_inband, 'MarkerFaceColor', color_fdm_inband);
        h2 = plot(snr_list, RMSE_tdm_mean, 's-', 'LineWidth', LINE_WIDTH, 'MarkerSize', MARKER_SIZE, ...
            'Color', color_tdm_inband, 'MarkerFaceColor', color_tdm_inband);
        
        set(gca, 'YScale', 'log');
        xlabel('SNR (dB)', 'FontSize', FONTSIZE);
        ylabel('RMSE', 'FontSize', FONTSIZE);
        
        leg1 = legend([h1, h2], {'OFE', 'TDM'}, 'Location', 'northeast', 'FontSize', FONTSIZE_LEGEND);
        leg1.Box = 'off';
        
        set(gca, 'FontSize', FONTSIZE_TICK, 'LineWidth', LINE_WIDTH_AXIS);
        if SHOW_GRID
            grid on;
            set(gca, 'GridLineStyle', ':', 'GridAlpha', 0.3);
        end
        xlim([min(snr_list)-2, max(snr_list)+2]);
        
        % 右图: 解调误差
        subplot(1, 2, 2);
        hold on; box on;
        
        h3 = plot(snr_list, DemodErr_fdm_mean, 'o-', 'LineWidth', LINE_WIDTH, 'MarkerSize', MARKER_SIZE, ...
            'Color', color_fdm_inband, 'MarkerFaceColor', color_fdm_inband);
        h4 = plot(snr_list, DemodErr_tdm_mean, 's-', 'LineWidth', LINE_WIDTH, 'MarkerSize', MARKER_SIZE, ...
            'Color', color_tdm_inband, 'MarkerFaceColor', color_tdm_inband);
        
        set(gca, 'YScale', 'log');
        xlabel('SNR (dB)', 'FontSize', FONTSIZE);
        ylabel('Demodulation Error (%)', 'FontSize', FONTSIZE);
        
        leg2 = legend([h3, h4], {'OFE', 'TDM'}, 'Location', 'northeast', 'FontSize', FONTSIZE_LEGEND);
        leg2.Box = 'off';
        
        set(gca, 'FontSize', FONTSIZE_TICK, 'LineWidth', LINE_WIDTH_AXIS);
        if SHOW_GRID
            grid on;
            set(gca, 'GridLineStyle', ':', 'GridAlpha', 0.3);
        end
        xlim([min(snr_list)-2, max(snr_list)+2]);
        
        if INBAND_AVOID_CARRIER
            savename = sprintf('fig_tdm_vs_fdm_%s_avoid', INBAND_NOISE_MODE);
        else
            savename = sprintf('fig_tdm_vs_fdm_%s_overlap', INBAND_NOISE_MODE);
        end
    end
    
    print(gcf, savename, '-dpng', '-r300');
    print(gcf, savename, '-depsc', '-r300');
    fprintf('\nSaved: %s.png and %s.eps\n', savename, savename);

%% ==================== MODE 3: 多音噪声 (不同频率间隔) ====================
elseif MODE == 3
    mode_name = 'TDM vs OFE: Multi-tone Noise with Different Guard Bands';
    
    snr_list = -10:5:40;
    n_test = length(snr_list);
    N_trials = 50;
    
    % 不同的频率间隔
    guard_band_list = [1e3, 5e3, 10e3];  % 1, 5, 10 kHz
    n_guard = length(guard_band_list);
    
    M = 10;  % 噪声数量
    
    % 获取调制频率
    [v_fdm_clean, ~, params_clean] = fdm_generate_signal(y_theory, ...
        'FreqMode', 'auto', 'T', T_fdm, 'Fs', Fs, ...
        'SNR_dB', Inf, 'Seed', 1, 'Waveform', 'sine');
    P_signal_fdm = var(v_fdm_clean);
    freqs_Hz = params_clean.FreqsHz;
    freqs_sorted = sort(freqs_Hz);
    
    % 预分配
    RMSE_fdm = zeros(n_test, N_trials, n_guard);
    RMSE_tdm = zeros(n_test, N_trials, n_guard);
    
    fprintf('============================================================\n');
    fprintf('MODE 3: %s\n', mode_name);
    fprintf('OFE调制频率: %.0f - %.0f kHz\n', min(freqs_Hz)/1e3, max(freqs_Hz)/1e3);
    fprintf('噪声数量: %d\n', M);
    fprintf('频率间隔测试: 0, 5, 10 kHz\n');
    fprintf('频率分辨率: %.0f kHz (1/T)\n', 1/(T_fdm)/1e3);
    fprintf('\n调制频率 (kHz): ');
    for k = 1:length(freqs_sorted)
        fprintf('%.1f ', freqs_sorted(k)/1e3);
    end
    fprintf('\n');
    fprintf('============================================================\n\n');
    
    %% 为每个guard band生成噪声频率
    f_noise_all = cell(n_guard, 1);
    
    for g = 1:n_guard
        guard_band = guard_band_list(g);
        
        % 噪声频率 = 调制频率 + guard_band
        f_noise_all{g} = freqs_sorted(1:min(M, length(freqs_sorted))) + guard_band;
        
        fprintf('Δf = %.0f kHz 噪声频率 (kHz): ', guard_band/1e3);
        for k = 1:length(f_noise_all{g})
            fprintf('%.1f ', f_noise_all{g}(k)/1e3);
        end
        fprintf('\n');
        
        % 检查与调制频率的最小距离
        fprintf('  与调制频率的最小距离: ');
        for k = 1:length(f_noise_all{g})
            min_dist = min(abs(f_noise_all{g}(k) - freqs_Hz));
            fprintf('%.1f ', min_dist/1e3);
        end
        fprintf('kHz\n\n');
    end
    
    %% 仿真循环
    for g = 1:n_guard
        guard_band = guard_band_list(g);
        f_noise = f_noise_all{g};
        fprintf('Running Guard Band = %.0f kHz...\n', guard_band/1e3);
        
        for idx_snr = 1:n_test
            SNR_dB = snr_list(idx_snr);
            noise_variance = P_signal_fdm / (10^(SNR_dB/10));
            
            for trial = 1:N_trials
                seed = trial;
                rng(seed);
                
                % 随机相位 (OFE和TDM共用)
                phi_noise = 2 * pi * rand(1, M);
                
                %% OFE + 多音噪声
                t_fdm = (0:N_fdm-1) / Fs;
                
                noise_fdm = zeros(1, length(t_fdm));
                for j = 1:M
                    noise_fdm = noise_fdm + cos(2*pi*f_noise(j)*t_fdm + phi_noise(j));
                end
                noise_fdm = noise_fdm * sqrt(noise_variance / var(noise_fdm));
                
                [v_fdm_clean_trial, ~, params_fdm] = fdm_generate_signal(y_theory, ...
                    'FreqMode', 'auto', 'T', T_fdm, 'Fs', Fs, ...
                    'SNR_dB', Inf, 'Seed', seed, 'Waveform', 'sine');
                
                v_fdm = v_fdm_clean_trial + noise_fdm;
                
                y_fdm_recovered = fdm_lockin_demod(v_fdm, t_fdm, params_fdm);
                x_est_fdm = fdm_reconstruct(y_fdm_recovered, A0_working, 'Method', 'tv');
                RMSE_fdm(idx_snr, trial, g) = fdm_metrics(x_gt, x_est_fdm);
                
                %% TDM + 多音噪声
                N_total = N_LED * N_slot;
                t_tdm = (0:N_total-1) / Fs;
                
                noise_tdm = zeros(1, N_total);
                for j = 1:M
                    noise_tdm = noise_tdm + cos(2*pi*f_noise(j)*t_tdm + phi_noise(j));
                end
                noise_tdm = noise_tdm * sqrt(noise_variance / var(noise_tdm));
                
                y_tdm_recovered = zeros(N_LED, 1);
                for i = 1:N_LED
                    idx_start = (i-1) * N_slot + 1;
                    idx_end = i * N_slot;
                    v_slot = y_theory(i) + noise_tdm(idx_start:idx_end);
                    y_tdm_recovered(i) = mean(v_slot);
                end
                x_est_tdm = fdm_reconstruct(y_tdm_recovered, A0_working, 'Method', 'tv');
                RMSE_tdm(idx_snr, trial, g) = fdm_metrics(x_gt, x_est_tdm);
            end
            fprintf('  SNR = %3d dB done\n', SNR_dB);
        end
    end
    
    %% 统计
    RMSE_fdm_mean = squeeze(mean(RMSE_fdm, 2));  % [n_test x n_guard]
    RMSE_tdm_mean = squeeze(mean(RMSE_tdm, 2));
    
    %% 打印结果
    fprintf('\n============================================================\n');
    fprintf('RMSE 结果对比\n');
    fprintf('============================================================\n');
    for g = 1:n_guard
        fprintf('\nΔf = %.0f kHz:\n', guard_band_list(g)/1e3);
        fprintf('%8s | %10s %10s\n', 'SNR(dB)', 'RMSE_OFE', 'RMSE_TDM');
        fprintf('%s\n', repmat('-', 1, 35));
        for i = 1:n_test
            fprintf('%8d | %10.4f %10.4f\n', ...
                snr_list(i), RMSE_fdm_mean(i,g), RMSE_tdm_mean(i,g));
        end
    end
    fprintf('============================================================\n');
    
    %% 绘图 - 6条曲线
    fig = figure('Units', 'centimeters', 'Position', [2, 2, FIG_WIDTH_CM, FIG_HEIGHT_CM], 'Color', 'w');
    set(fig, 'PaperUnits', 'centimeters', 'PaperSize', [FIG_WIDTH_CM, FIG_HEIGHT_CM], ...
        'PaperPosition', [0, 0, FIG_WIDTH_CM, FIG_HEIGHT_CM]);
    hold on; box on;
    
    % 颜色 - 不同Δf用不同颜色
    colors = [
        0.85, 0.35, 0.25;   % 红色 - 0 kHz
        0.20, 0.60, 0.30;   % 绿色 - 5 kHz
        0.20, 0.45, 0.70;   % 蓝色 - 10 kHz
    ];
    
    % OFE: 统一圆圈实线，TDM: 统一三角虚线
    h_fdm = gobjects(n_guard, 1);
    h_tdm = gobjects(n_guard, 1);
    
    for g = 1:n_guard
        % OFE: 圆圈 + 实线 + 实心
        h_fdm(g) = plot(snr_list, RMSE_fdm_mean(:,g), 'o-', ...
            'LineWidth', LINE_WIDTH, 'MarkerSize', MARKER_SIZE, ...
            'Color', colors(g,:), 'MarkerFaceColor', colors(g,:));
        
        % TDM: 三角 + 虚线 + 空心
        h_tdm(g) = plot(snr_list, RMSE_tdm_mean(:,g), '^--', ...
            'LineWidth', LINE_WIDTH, 'MarkerSize', MARKER_SIZE, ...
            'Color', colors(g,:), 'MarkerFaceColor', 'w');
    end
    
    set(gca, 'YScale', 'log');
    xlabel('SNR (dB)', 'FontSize', FONTSIZE, 'FontName', 'Arial');
    ylabel('RMSE', 'FontSize', FONTSIZE, 'FontName', 'Arial');
    
    % 图例 - 分两组：OFE组 和 TDM组
    % OFE: Δf=0, Δf=5, Δf=10
    % TDM: Δf=0, Δf=5, Δf=10
    legend_str = cell(2*n_guard, 1);
    h_all = gobjects(2*n_guard, 1);
    
    for g = 1:n_guard
        h_all(g) = h_fdm(g);
        h_all(n_guard + g) = h_tdm(g);
        legend_str{g} = sprintf('OFE, \\Deltaf=%d kHz', guard_band_list(g)/1e3);
        legend_str{n_guard + g} = sprintf('TDM, \\Deltaf=%d kHz', guard_band_list(g)/1e3);
    end
    
    leg = legend(h_all, legend_str, 'Location', 'northeast', 'FontSize', FONTSIZE_LEGEND, 'NumColumns', 2);
    leg.Box = 'off';
    
    set(gca, 'FontSize', FONTSIZE_TICK, 'FontName', 'Arial', 'LineWidth', LINE_WIDTH_AXIS);
    if SHOW_GRID
        grid on;
        set(gca, 'GridLineStyle', ':', 'GridAlpha', 0.3);
    end
    xlim([min(snr_list)-2, max(snr_list)+2]);
    
    savename = 'fig_tdm_vs_fdm_multitone_guardband';
    print(gcf, savename, '-dpng', '-r300');
    print(gcf, savename, '-depsc', '-r300');
    fprintf('\nSaved: %s.png and %s.eps\n', savename, savename);

%% ==================== MODE 5: 时域信号对比 ====================
elseif MODE == 5
    mode_name = 'TDM vs OFE: Time Domain Signal Comparison';
    
    SNR_dB_display = 20;  % 显示用的SNR
    
    % 显示时间范围 (μs)
    T_START = 0;
    T_END = 20;  % 显示前20μs
    
    %% 生成OFE信号
    % 无噪声
    [v_fdm_clean, t_fdm, params_fdm] = fdm_generate_signal(y_theory, ...
        'FreqMode', 'auto', 'T', T_fdm, 'Fs', Fs, ...
        'SNR_dB', Inf, 'Seed', 1, 'Waveform', 'sine');
    
    % 有噪声
    [v_fdm_noisy, ~, ~] = fdm_generate_signal(y_theory, ...
        'FreqMode', 'auto', 'T', T_fdm, 'Fs', Fs, ...
        'SNR_dB', SNR_dB_display, 'Seed', 1, 'Waveform', 'sine');
    
    %% 生成TDM信号
    t_tdm = (0:N_LED*N_slot-1) / Fs;
    P_signal_fdm = var(v_fdm_clean);
    noise_variance = P_signal_fdm / (10^(SNR_dB_display/10));
    noise_std = sqrt(noise_variance);
    
    % 无噪声TDM
    v_tdm_clean = zeros(1, N_LED*N_slot);
    for i = 1:N_LED
        idx_start = (i-1) * N_slot + 1;
        idx_end = i * N_slot;
        v_tdm_clean(idx_start:idx_end) = y_theory(i);
    end
    
    % 有噪声TDM
    rng(1);
    v_tdm_noisy = v_tdm_clean + noise_std * randn(1, N_LED*N_slot);
    
    %% 打印信息
    fprintf('============================================================\n');
    fprintf('MODE 5: %s\n', mode_name);
    fprintf('============================================================\n');
    fprintf('总时间: %.0f μs\n', T_fdm*1e6);
    fprintf('显示时间: %.0f - %.0f μs\n', T_START, T_END);
    fprintf('采样率: %.0f MHz\n', Fs/1e6);
    fprintf('OFE采样点数: %d\n', N_fdm);
    fprintf('TDM采样点数: %d (每时隙 %d 点)\n', N_LED*N_slot, N_slot);
    fprintf('SNR: %d dB\n', SNR_dB_display);
    fprintf('OFE调制频率: %.0f - %.0f kHz\n', min(params_fdm.FreqsHz)/1e3, max(params_fdm.FreqsHz)/1e3);
    fprintf('============================================================\n');
    
    %% 绘图
    fig = figure('Units', 'centimeters', 'Position', [2, 2, FIG_WIDTH_CM, FIG_HEIGHT_CM], 'Color', 'w');
    set(fig, 'PaperUnits', 'centimeters', 'PaperSize', [FIG_WIDTH_CM, FIG_HEIGHT_CM], ...
        'PaperPosition', [0, 0, FIG_WIDTH_CM, FIG_HEIGHT_CM]);
    hold on; box on;
    
    % 颜色定义
    color_fdm_clean = [0.15, 0.15, 0.15];     % 深黑 - OFE无噪声
    color_tdm_clean = [0.85, 0.20, 0.20];     % 鲜红 - TDM无噪声
    color_fdm_noisy = [0.20, 0.45, 0.85];     % 鲜蓝 - OFE有噪声
    color_tdm_noisy = [0.20, 0.70, 0.30];     % 鲜绿 - TDM有噪声
    
    % 转换时间为微秒
    t_fdm_us = t_fdm * 1e6;
    t_tdm_us = t_tdm * 1e6;
    
    % 显示范围索引
    idx_fdm = (t_fdm_us >= T_START) & (t_fdm_us <= T_END);
    idx_tdm = (t_tdm_us >= T_START) & (t_tdm_us <= T_END);
    
    % 绘制曲线
    % 先画有噪声的在底层
    h4 = plot(t_tdm_us(idx_tdm), v_tdm_noisy(idx_tdm), ':', ...
        'LineWidth', LINE_WIDTH+0.2, 'Color', color_tdm_noisy);
    h3 = plot(t_fdm_us(idx_fdm), v_fdm_noisy(idx_fdm), '-.', ...
        'LineWidth', LINE_WIDTH, 'Color', color_fdm_noisy);
    % 再画无噪声的在上层
    h2 = plot(t_tdm_us(idx_tdm), v_tdm_clean(idx_tdm), '--', ...
        'LineWidth', LINE_WIDTH, 'Color', color_tdm_clean);
    h1 = plot(t_fdm_us(idx_fdm), v_fdm_clean(idx_fdm), '-', ...
        'LineWidth', LINE_WIDTH+0.3, 'Color', color_fdm_clean);
    
    xlabel('Time (μs)', 'FontSize', FONTSIZE, 'FontName', 'Arial');
    ylabel('Voltage (a.u.)', 'FontSize', FONTSIZE, 'FontName', 'Arial');
    
    leg = legend([h1, h2, h3, h4], ...
        {'OFE (Noiseless)', ...
         'TDM (Noiseless)', ...
         sprintf('OFE (AWGN, SNR=%d dB)', SNR_dB_display), ...
         sprintf('TDM (AWGN, SNR=%d dB)', SNR_dB_display)}, ...
        'Location', 'best', 'FontSize', FONTSIZE_LEGEND);
    leg.Box = 'off';
    
    set(gca, 'FontSize', FONTSIZE_TICK, 'FontName', 'Arial', 'LineWidth', LINE_WIDTH_AXIS);
    if SHOW_GRID
        grid on;
        set(gca, 'GridLineStyle', ':', 'GridAlpha', 0.3);
    end
    xlim([T_START, T_END]);
    
    %% 保存
    savename = 'fig_tdm_vs_fdm_timedomain';
    print(gcf, savename, '-dpng', '-r300');
    print(gcf, savename, '-depsc', '-r300');
    fprintf('\nSaved: %s.png and %s.eps\n', savename, savename);
    
%% ==================== MODE 4: 单频100kHz噪声 ====================
elseif MODE == 4
    mode_name = 'TDM vs OFE: Single-tone 100kHz Noise';
    
    snr_list = -10:5:40;
    n_test = length(snr_list);
    N_trials = 50;
    
    % 单频噪声频率
    f_noise = 100e3;  % 100 kHz
    
    % 预分配
    DemodErr_fdm = zeros(n_test, N_trials);
    DemodErr_tdm = zeros(n_test, N_trials);
    RMSE_fdm = zeros(n_test, N_trials);
    RMSE_tdm = zeros(n_test, N_trials);
    
    % 获取参数
    [v_fdm_clean, ~, params_clean] = fdm_generate_signal(y_theory, ...
        'FreqMode', 'auto', 'T', T_fdm, 'Fs', Fs, ...
        'SNR_dB', Inf, 'Seed', 1, 'Waveform', 'sine');
    P_signal_fdm = var(v_fdm_clean);
    freqs_Hz = params_clean.FreqsHz;
    
    fprintf('============================================================\n');
    fprintf('MODE 4: %s\n', mode_name);
    fprintf('OFE调制频率: %.0f - %.0f kHz\n', min(freqs_Hz)/1e3, max(freqs_Hz)/1e3);
    fprintf('单频噪声频率: %.0f kHz\n', f_noise/1e3);
    fprintf('频率分辨率: %.0f kHz (1/T)\n', 1/(T_fdm)/1e3);
    fprintf('\n调制频率 (kHz): ');
    freqs_sorted = sort(freqs_Hz);
    for k = 1:length(freqs_sorted)
        fprintf('%.1f ', freqs_sorted(k)/1e3);
    end
    fprintf('\n');
    
    % 检查100kHz与调制频率的距离
    min_dist = min(abs(f_noise - freqs_Hz));
    fprintf('100kHz与最近调制频率的距离: %.1f kHz\n', min_dist/1e3);
    fprintf('============================================================\n\n');
    
    fprintf('Running simulations...\n');
    for idx_snr = 1:n_test
        SNR_dB = snr_list(idx_snr);
        noise_variance = P_signal_fdm / (10^(SNR_dB/10));
        noise_amp = sqrt(2 * noise_variance);  % 正弦波幅度，使功率=noise_variance
        
        for trial = 1:N_trials
            seed = trial;
            rng(seed);
            
            % 随机相位
            phi_noise = 2 * pi * rand();
            
            %% OFE + 100kHz单频噪声
            t_fdm = (0:N_fdm-1) / Fs;
            noise_100k = noise_amp * cos(2*pi*f_noise*t_fdm + phi_noise);
            
            % 生成无噪声OFE信号
            [v_fdm_clean, ~, params_fdm] = fdm_generate_signal(y_theory, ...
                'FreqMode', 'auto', 'T', T_fdm, 'Fs', Fs, ...
                'SNR_dB', Inf, 'Seed', seed, 'Waveform', 'sine');
            
            v_fdm = v_fdm_clean + noise_100k;
            
            y_fdm_recovered = fdm_lockin_demod(v_fdm, t_fdm, params_fdm);
            DemodErr_fdm(idx_snr, trial) = norm(y_fdm_recovered - y_theory) / y_norm * 100;
            x_est_fdm = fdm_reconstruct(y_fdm_recovered, A0_working, 'Method', 'tv');
            RMSE_fdm(idx_snr, trial) = fdm_metrics(x_gt, x_est_fdm);
            
            %% TDM + 100kHz单频噪声
            N_total = N_LED * N_slot;
            t_tdm = (0:N_total-1) / Fs;
            noise_100k_tdm = noise_amp * cos(2*pi*f_noise*t_tdm + phi_noise);
            
            y_tdm_recovered = zeros(N_LED, 1);
            for i = 1:N_LED
                idx_start = (i-1) * N_slot + 1;
                idx_end = i * N_slot;
                v_slot = y_theory(i) + noise_100k_tdm(idx_start:idx_end);
                y_tdm_recovered(i) = mean(v_slot);
            end
            DemodErr_tdm(idx_snr, trial) = norm(y_tdm_recovered - y_theory) / y_norm * 100;
            x_est_tdm = fdm_reconstruct(y_tdm_recovered, A0_working, 'Method', 'tv');
            RMSE_tdm(idx_snr, trial) = fdm_metrics(x_gt, x_est_tdm);
        end
        fprintf('  SNR = %3d dB done\n', SNR_dB);
    end
    
    %% 统计
    DemodErr_fdm_mean = mean(DemodErr_fdm, 2);
    DemodErr_tdm_mean = mean(DemodErr_tdm, 2);
    RMSE_fdm_mean = mean(RMSE_fdm, 2);
    RMSE_tdm_mean = mean(RMSE_tdm, 2);
    
    %% 打印结果
    fprintf('\n============================================================\n');
    fprintf('MODE 4: 单频100kHz噪声结果\n');
    fprintf('============================================================\n');
    fprintf('%8s | %10s %10s | %10s %10s\n', 'SNR(dB)', 'RMSE_OFE', 'RMSE_TDM', 'Demod_OFE', 'Demod_TDM');
    fprintf('%s\n', repmat('-', 1, 60));
    for i = 1:n_test
        fprintf('%8d | %10.4f %10.4f | %10.2f%% %10.2f%%\n', ...
            snr_list(i), RMSE_fdm_mean(i), RMSE_tdm_mean(i), ...
            DemodErr_fdm_mean(i), DemodErr_tdm_mean(i));
    end
    fprintf('============================================================\n');
    
    %% 绘图
    if DUAL_AXIS
        %% 单图双Y轴模式
        fig = figure('Units', 'centimeters', 'Position', [2, 2, FIG_WIDTH_CM, FIG_HEIGHT_CM], 'Color', 'w');
        set(fig, 'PaperUnits', 'centimeters', 'PaperSize', [FIG_WIDTH_CM, FIG_HEIGHT_CM], ...
            'PaperPosition', [0, 0, FIG_WIDTH_CM, FIG_HEIGHT_CM]);
        
        % 颜色定义
        color_fdm = [0.20, 0.45, 0.70];   % 蓝色
        color_tdm = [0.85, 0.35, 0.25];   % 红色
        
        % 左Y轴: RMSE
        yyaxis left;
        hold on; box on;
        
        h1 = plot(snr_list, RMSE_fdm_mean, 'o-', 'LineWidth', LINE_WIDTH, 'MarkerSize', MARKER_SIZE, ...
            'Color', color_fdm, 'MarkerFaceColor', color_fdm);
        h2 = plot(snr_list, RMSE_tdm_mean, 's-', 'LineWidth', LINE_WIDTH, 'MarkerSize', MARKER_SIZE, ...
            'Color', color_tdm, 'MarkerFaceColor', color_tdm);
        
        ylabel('RMSE', 'FontSize', FONTSIZE, 'FontName', 'Arial');
        set(gca, 'YColor', 'k', 'YScale', 'log');
        
        % 右Y轴: 解调误差
        yyaxis right;
        
        h3 = plot(snr_list, DemodErr_fdm_mean, 'o-', 'LineWidth', LINE_WIDTH, 'MarkerSize', MARKER_SIZE-1, ...
            'Color', color_fdm, 'MarkerFaceColor', 'w');
        h4 = plot(snr_list, DemodErr_tdm_mean, 's-', 'LineWidth', LINE_WIDTH, 'MarkerSize', MARKER_SIZE-1, ...
            'Color', color_tdm, 'MarkerFaceColor', 'w');
        
        ylabel('Demodulation Error (%)', 'FontSize', FONTSIZE, 'FontName', 'Arial');
        set(gca, 'YColor', 'k', 'YScale', 'log');
        
        xlabel('SNR (dB)', 'FontSize', FONTSIZE, 'FontName', 'Arial');
        
        leg = legend([h1, h2, h3, h4], ...
            {'OFE (RMSE)', 'TDM (RMSE)', 'OFE (Demod)', 'TDM (Demod)'}, ...
            'Location', 'northeast', 'FontSize', FONTSIZE_LEGEND, 'NumColumns', 2);
        leg.Box = 'off';
        
        savename = 'fig_tdm_vs_fdm_100khz_dual';
    else
        %% 单图只画RMSE
        fig = figure('Units', 'centimeters', 'Position', [2, 2, FIG_WIDTH_CM, FIG_HEIGHT_CM], 'Color', 'w');
        set(fig, 'PaperUnits', 'centimeters', 'PaperSize', [FIG_WIDTH_CM, FIG_HEIGHT_CM], ...
            'PaperPosition', [0, 0, FIG_WIDTH_CM, FIG_HEIGHT_CM]);
        hold on; box on;
        
        % 颜色定义
        color_fdm = [0.20, 0.45, 0.70];   % 蓝色
        color_tdm = [0.85, 0.35, 0.25];   % 红色
        
        h1 = plot(snr_list, RMSE_fdm_mean, 'o-', 'LineWidth', LINE_WIDTH, 'MarkerSize', MARKER_SIZE, ...
            'Color', color_fdm, 'MarkerFaceColor', color_fdm);
        h2 = plot(snr_list, RMSE_tdm_mean, 's-', 'LineWidth', LINE_WIDTH, 'MarkerSize', MARKER_SIZE, ...
            'Color', color_tdm, 'MarkerFaceColor', color_tdm);
        
        set(gca, 'YScale', 'log');
        xlabel('SNR (dB)', 'FontSize', FONTSIZE, 'FontName', 'Arial');
        ylabel('RMSE', 'FontSize', FONTSIZE, 'FontName', 'Arial');
        
        leg = legend([h1, h2], {'OFE', 'TDM'}, ...
            'Location', 'northeast', 'FontSize', FONTSIZE_LEGEND);
        leg.Box = 'off';
        
        savename = 'fig_tdm_vs_fdm_100khz';
    end
    
    set(gca, 'FontSize', FONTSIZE_TICK, 'FontName', 'Arial', 'LineWidth', LINE_WIDTH_AXIS);
    if SHOW_GRID
        grid on;
        set(gca, 'GridLineStyle', ':', 'GridAlpha', 0.3);
    end
    xlim([min(snr_list)-2, max(snr_list)+2]);
    
    %% 保存
    print(gcf, savename, '-dpng', '-r300');
    print(gcf, savename, '-depsc', '-r300');
    fprintf('\nSaved: %s.png and %s.eps\n', savename, savename);

else
    error('Unknown MODE: %d. Use 1, 2, 3, 4, or 5.', MODE);
end

%% ==================== 辅助函数 ====================
function y_recovered = fdm_lockin_demod(v_fdm, t_fdm, params)
    N_LED = length(params.FreqsHz);
    y_recovered = zeros(N_LED, 1);
    freqs = params.FreqsHz;
    phases = params.Phases;
    T = params.T;
    dt = params.dt;
    
    for i = 1:N_LED
        ref = sin(2*pi*freqs(i)*t_fdm + phases(i));
        y_recovered(i) = (2/T) * sum(v_fdm .* ref) * dt;
    end
end
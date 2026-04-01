function tdm_vs_ofe_sim_v2(MODE)
%% TDM vs OFE 对比仿真 (重构版)
% MODE 1: AWGN噪声
% MODE 2: 带内噪声 (可选 gaussian 或 multitone)
% MODE 3: 多音噪声 (不同频率间隔)
% MODE 4: 单频100kHz噪声
% MODE 5: 时域信号对比
if nargin < 1
    MODE = 2;
end

clc; close all;
%% ==================== 全局配置 ====================

cfg = struct();
cfg.DUAL_AXIS = true;       % true: 上下子图; false: 左右子图
cfg.SHOW_GRID = false;

% 带内噪声设置
cfg.INBAND_NOISE_MODE = 'multitone';
cfg.INBAND_NUM_TONES = 1;
cfg.INBAND_AVOID_CARRIER = true;
cfg.INBAND_GUARD_BAND = 25e3;

% 仿真参数
cfg.snr_list = -10:5:40;
cfg.N_trials = 50;
cfg.Fs = 10e6;
cfg.T_total = 100e-6;
cfg.f_inband_low = 30e3;
cfg.f_inband_high = 410e3;

%% ==================== 图形样式 (集中管理) ====================
sty = struct();

% 尺寸
sty.FIG_WIDTH_CM = 18;
sty.FIG_HEIGHT_CM = 14;
sty.FIG_WIDTH_CM_DUAL = 36;

% 字体
sty.FONTSIZE = 18;
sty.FONTSIZE_LEGEND = 16;
sty.FONTSIZE_TICK = 16;

% 线条
sty.MARKER_SIZE = 10;
sty.LINE_WIDTH = 2;
sty.LINE_WIDTH_AXIS = 0.5;

% 上下子图布局
sty.gap = 0.06;
sty.margin_left = 0.14;
sty.margin_right = 0.04;
sty.margin_bottom = 0.14;
sty.margin_top = 0.06;

% RMSE 颜色 (蓝色系, 上图/左轴)
sty.color_rmse = struct('ofe', [0.12, 0.30, 0.60], 'tdm', [0.40, 0.65, 0.90]);
% Demod Error 颜色 (红色系, 下图/右轴)
sty.color_demod = struct('ofe', [0.75, 0.20, 0.20], 'tdm', [0.95, 0.50, 0.45]);
% 单图模式颜色
sty.color_ofe = [0.20, 0.45, 0.70];
sty.color_tdm = [0.85, 0.35, 0.25];

%% ==================== 加载数据 ====================
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

% 派生参数
T_fdm = cfg.T_total;
N_fdm = round(cfg.Fs * T_fdm);
T_slot = cfg.T_total / N_LED;
N_slot = round(cfg.Fs * T_slot);

% 获取无噪声FDM信号和参数 (所有MODE共用)
[v_fdm_clean, ~, params_clean] = fdm_generate_signal(y_theory, ...
    'FreqMode', 'auto', 'T', T_fdm, 'Fs', cfg.Fs, ...
    'SNR_dB', Inf, 'Seed', 1, 'Waveform', 'sine');
P_signal_fdm = var(v_fdm_clean);
freqs_Hz = params_clean.FreqsHz;

%% ==================== MODE 分发 ====================
switch MODE
    case 1, run_mode1_awgn();
    case 2, run_mode2_inband();
    case 3, run_mode3_guardband();
    case 4, run_mode4_singletone();
    case 5, run_mode5_timedomain();
    otherwise, error('Unknown MODE: %d. Use 1-5.', MODE);
end

%% ==================== MODE 1: AWGN ====================
function run_mode1_awgn()
    fprintf_header('MODE 1: TDM vs OFE: AWGN');
    
    [RMSE_fdm, RMSE_tdm, DemodErr_fdm, DemodErr_tdm] = run_snr_sweep(@noise_awgn);
    
    res = pack_results(RMSE_fdm, RMSE_tdm, DemodErr_fdm, DemodErr_tdm);
    print_results_table(res);
    plot_dual_metric(res, 'fig_tdm_vs_fdm_awgn');
end

%% ==================== MODE 2: 带内噪声 ====================
function run_mode2_inband()
    fprintf_header(sprintf('MODE 2: TDM vs OFE: %s noise', cfg.INBAND_NOISE_MODE));
    
    [RMSE_fdm, RMSE_tdm, DemodErr_fdm, DemodErr_tdm] = run_snr_sweep(@noise_inband);
    
    res = pack_results(RMSE_fdm, RMSE_tdm, DemodErr_fdm, DemodErr_tdm);
    print_results_table(res);
    
    if cfg.INBAND_AVOID_CARRIER
        savename = sprintf('fig_tdm_vs_fdm_%s_avoid', cfg.INBAND_NOISE_MODE);
    else
        savename = sprintf('fig_tdm_vs_fdm_%s_overlap', cfg.INBAND_NOISE_MODE);
    end
    plot_dual_metric(res, savename);
end

%% ==================== MODE 3: 多音噪声 (不同Guard Band) ====================
function run_mode3_guardband()
    fprintf_header('MODE 3: Multi-tone Noise RMSE vs SNR (Different Guard Bands)');
    
    %% 参数
    guard_band_list = [1e3, 5e3, 10e3];
    n_guard = length(guard_band_list);
    M = 10;
    freqs_sorted = sort(freqs_Hz);
    snr_list = cfg.snr_list;
    n_test = length(snr_list);
    
    fprintf('OFE调制频率: %.0f–%.0f kHz\n', min(freqs_Hz)/1e3, max(freqs_Hz)/1e3);
    fprintf('噪声数量: %d, 频率分辨率: %.0f kHz (1/T)\n', M, 1/T_fdm/1e3);
    
    %% 为每个guard band生成噪声频率
    f_noise_all = cell(n_guard, 1);
    for g = 1:n_guard
        f_noise_all{g} = freqs_sorted(1:min(M, length(freqs_sorted))) + guard_band_list(g);
        fprintf('  Δf = %d kHz: noise freqs = %.0f–%.0f kHz\n', ...
            guard_band_list(g)/1e3, min(f_noise_all{g})/1e3, max(f_noise_all{g})/1e3);
    end
    
    %% 仿真
    RMSE_fdm_mean = zeros(n_test, n_guard);
    RMSE_tdm_all = zeros(n_test, cfg.N_trials, n_guard);  % 保留所有trial用于误差带
    
    for g = 1:n_guard
        f_noise = f_noise_all{g};
        fprintf('\nRunning Δf = %d kHz...\n', guard_band_list(g)/1e3);
        
        RMSE_fdm = zeros(n_test, cfg.N_trials);
        
        for idx_snr = 1:n_test
            noise_var = P_signal_fdm / (10^(snr_list(idx_snr)/10));
            
            for trial = 1:cfg.N_trials
                rng(trial);
                phi_noise = 2 * pi * rand(1, M);
                
                % OFE
                t_f = (0:N_fdm-1) / cfg.Fs;
                noise_f = make_multitone(f_noise, phi_noise, t_f, noise_var);
                [v_clean, ~, p] = fdm_generate_signal(y_theory, ...
                    'FreqMode', 'auto', 'T', T_fdm, 'Fs', cfg.Fs, ...
                    'SNR_dB', Inf, 'Seed', trial, 'Waveform', 'sine');
                y_rec = fdm_lockin_demod(v_clean + noise_f, t_f, p);
                RMSE_fdm(idx_snr, trial) = fdm_metrics(x_gt, ...
                    fdm_reconstruct(y_rec, A0_working, 'Method', 'tv'));
                
                % TDM
                N_total = N_LED * N_slot;
                t_t = (0:N_total-1) / cfg.Fs;
                noise_t = make_multitone(f_noise, phi_noise, t_t, noise_var);
                y_rec_t = tdm_demod(y_theory, noise_t, N_LED, N_slot);
                RMSE_tdm_all(idx_snr, trial, g) = fdm_metrics(x_gt, ...
                    fdm_reconstruct(y_rec_t, A0_working, 'Method', 'tv'));
            end
            fprintf('  SNR = %3d dB done\n', snr_list(idx_snr));
        end
        
        RMSE_fdm_mean(:, g) = mean(RMSE_fdm, 2);
    end
    
    %% TDM 合并: 三个Δf的均值 + min/max 误差带
    RMSE_tdm_per_guard = squeeze(mean(RMSE_tdm_all, 2));  % [n_test x n_guard]
    RMSE_tdm_baseline = mean(RMSE_tdm_per_guard, 2);       % 三个Δf的平均
    RMSE_tdm_lo = min(RMSE_tdm_per_guard, [], 2);
    RMSE_tdm_hi = max(RMSE_tdm_per_guard, [], 2);
    
    %% 打印结果
    fprintf('\n%8s | %10s %10s %10s | %10s\n', ...
        'SNR(dB)', 'OFE_1k', 'OFE_5k', 'OFE_10k', 'TDM_base');
    fprintf('%s\n', repmat('-', 1, 58));
    for i = 1:n_test
        fprintf('%8d | %10.4f %10.4f %10.4f | %10.4f\n', ...
            snr_list(i), RMSE_fdm_mean(i,1), RMSE_fdm_mean(i,2), RMSE_fdm_mean(i,3), ...
            RMSE_tdm_baseline(i));
    end
    
    %% 绘图
    % OFE 梯度色 (降低饱和度): 暗红→土橙→藏蓝
    colors_ofe = [
        0.65, 0.22, 0.18;   % 暗红 - Δf=1 kHz
        0.78, 0.52, 0.25;   % 土橙 - Δf=5 kHz
        0.20, 0.38, 0.62;   % 藏蓝 - Δf=10 kHz
    ];
    markers_ofe = {'o', 's', 'd'};
    color_tdm = [0.55, 0.55, 0.55];  % 灰色 TDM baseline
    
    fig = make_figure(sty.FIG_WIDTH_CM, sty.FIG_HEIGHT_CM);
    hold on; box on;
    
    %% TDM 误差带 (灰色半透明区域)
    fill_x = [snr_list, fliplr(snr_list)];
    fill_y = [RMSE_tdm_hi', fliplr(RMSE_tdm_lo')];
    h_fill = fill(fill_x, fill_y, color_tdm, ...
        'FaceAlpha', 0.15, 'EdgeColor', 'none');
    
    %% TDM baseline (粗灰色虚线)
    h_tdm = plot(snr_list, RMSE_tdm_baseline, '--', ...
        'LineWidth', sty.LINE_WIDTH + 0.5, 'Color', color_tdm);
    
    %% OFE 三条曲线
    h_ofe = gobjects(n_guard, 1);
    for g = 1:n_guard
        h_ofe(g) = plot(snr_list, RMSE_fdm_mean(:,g), ...
            [markers_ofe{g} '-'], ...
            'LineWidth', sty.LINE_WIDTH, 'MarkerSize', sty.MARKER_SIZE, ...
            'Color', colors_ofe(g,:), 'MarkerFaceColor', colors_ofe(g,:));
    end
    
    set(gca, 'YScale', 'log');
    xlabel('SNR (dB)', 'FontSize', sty.FONTSIZE, 'FontName', 'Arial');
    ylabel('RMSE', 'FontSize', sty.FONTSIZE, 'FontName', 'Arial');
    apply_axis_style();
    xlim([min(snr_list)-2, max(snr_list)+2]);
    
    %% 图例
    leg = legend([h_tdm, h_ofe(1), h_ofe(2), h_ofe(3)], ...
        {'TDM (Baseline)', ...
         sprintf('OFE, Multitone noise, \\Deltaf_{guard} = %d kHz', guard_band_list(1)/1e3), ...
         sprintf('OFE, Multitone noise, \\Deltaf_{guard} = %d kHz', guard_band_list(2)/1e3), ...
         sprintf('OFE, Multitone noise, \\Deltaf_{guard} = %d kHz', guard_band_list(3)/1e3)}, ...
        'Location', 'northeast', 'FontSize', sty.FONTSIZE_LEGEND);
    leg.Box = 'off';
    
    save_figure('fig_tdm_vs_fdm_multitone_guardband');
end

%% ==================== MODE 4: 单频100kHz噪声 ====================
function run_mode4_singletone()
    fprintf_header('MODE 4: Single-tone 100kHz Noise');
    f_noise_single = 100e3;
    
    [RMSE_fdm, RMSE_tdm, DemodErr_fdm, DemodErr_tdm] = run_snr_sweep( ...
        @(nv, ns, seed) noise_singletone(nv, ns, seed, f_noise_single));
    
    res = pack_results(RMSE_fdm, RMSE_tdm, DemodErr_fdm, DemodErr_tdm);
    print_results_table(res);
    plot_dual_metric(res, 'fig_tdm_vs_fdm_100khz');
end

%% ==================== MODE 5: 时域信号对比 ====================
function run_mode5_timedomain()
    fprintf_header('MODE 5: Time Domain Signal Comparison');
    
    SNR_dB_display = 20;
    T_START = 0; T_END = 20;
    
    % OFE信号
    [~, t_f, ~] = fdm_generate_signal(y_theory, 'FreqMode', 'auto', ...
        'T', T_fdm, 'Fs', cfg.Fs, 'SNR_dB', Inf, 'Seed', 1, 'Waveform', 'sine');
    [v_fdm_noisy, ~, ~] = fdm_generate_signal(y_theory, 'FreqMode', 'auto', ...
        'T', T_fdm, 'Fs', cfg.Fs, 'SNR_dB', SNR_dB_display, 'Seed', 1, 'Waveform', 'sine');
    
    % TDM信号
    N_total = N_LED * N_slot;
    t_t = (0:N_total-1) / cfg.Fs;
    noise_std = sqrt(P_signal_fdm / (10^(SNR_dB_display/10)));
    
    v_tdm_clean = zeros(1, N_total);
    for i = 1:N_LED
        v_tdm_clean((i-1)*N_slot+1 : i*N_slot) = y_theory(i);
    end
    rng(1);
    v_tdm_noisy = v_tdm_clean + noise_std * randn(1, N_total);
    
    % 绘图
    c = struct('fdm_clean', [0.15,0.15,0.15], 'tdm_clean', [0.85,0.20,0.20], ...
               'fdm_noisy', [0.20,0.45,0.85], 'tdm_noisy', [0.20,0.70,0.30]);
    
    fig = make_figure(sty.FIG_WIDTH_CM, sty.FIG_HEIGHT_CM);
    hold on; box on;
    
    t_f_us = t_f*1e6;  t_t_us = t_t*1e6;
    idx_f = (t_f_us >= T_START) & (t_f_us <= T_END);
    idx_t = (t_t_us >= T_START) & (t_t_us <= T_END);
    
    h4 = plot(t_t_us(idx_t), v_tdm_noisy(idx_t), ':', ...
        'LineWidth', sty.LINE_WIDTH+0.2, 'Color', c.tdm_noisy);
    h3 = plot(t_f_us(idx_f), v_fdm_noisy(idx_f), '-.', ...
        'LineWidth', sty.LINE_WIDTH, 'Color', c.fdm_noisy);
    h2 = plot(t_t_us(idx_t), v_tdm_clean(idx_t), '--', ...
        'LineWidth', sty.LINE_WIDTH, 'Color', c.tdm_clean);
    h1 = plot(t_f_us(idx_f), v_fdm_clean(idx_f), '-', ...
        'LineWidth', sty.LINE_WIDTH+0.3, 'Color', c.fdm_clean);
    
    xlabel('Time (μs)', 'FontSize', sty.FONTSIZE, 'FontName', 'Arial');
    ylabel('Amplitude (AC-coupled, a.u.)', 'FontSize', sty.FONTSIZE, 'FontName', 'Arial');
    apply_axis_style();
    xlim([T_START, T_END]);
    
    leg = legend([h1,h2,h3,h4], ...
        {'OFE (Noiseless)', 'TDM (Noiseless)', ...
         sprintf('OFE (AWGN, SNR=%d dB)', SNR_dB_display), ...
         sprintf('TDM (AWGN, SNR=%d dB)', SNR_dB_display)}, ...
        'Location', 'best', 'FontSize', sty.FONTSIZE_LEGEND);
    leg.Box = 'off';
    
    save_figure('fig_tdm_vs_fdm_timedomain');
end

%% ================================================================
%%                       核心仿真引擎
%% ================================================================

function [RMSE_f, RMSE_t, Derr_f, Derr_t] = run_snr_sweep(noise_fn)
    % 通用SNR扫描引擎
    % noise_fn(noise_var, noise_std, seed) 返回:
    %   noise_fdm [1 x N_fdm], noise_tdm [1 x N_total]
    
    snr_list = cfg.snr_list;
    n_test = length(snr_list);
    Nt = cfg.N_trials;
    
    RMSE_f = zeros(n_test, Nt);
    RMSE_t = zeros(n_test, Nt);
    Derr_f = zeros(n_test, Nt);
    Derr_t = zeros(n_test, Nt);
    
    for idx = 1:n_test
        SNR_dB = snr_list(idx);
        nv = P_signal_fdm / (10^(SNR_dB/10));
        ns = sqrt(nv);
        
        for trial = 1:Nt
            % OFE
            [v_f, t_f, p_f] = fdm_generate_signal(y_theory, ...
                'FreqMode', 'auto', 'T', T_fdm, 'Fs', cfg.Fs, ...
                'SNR_dB', Inf, 'Seed', trial, 'Waveform', 'sine');
            
            [noise_f, noise_t] = noise_fn(nv, ns, trial);
            
            y_f = fdm_lockin_demod(v_f + noise_f, t_f, p_f);
            Derr_f(idx, trial) = norm(y_f - y_theory) / y_norm * 100;
            RMSE_f(idx, trial) = fdm_metrics(x_gt, ...
                fdm_reconstruct(y_f, A0_working, 'Method', 'tv'));
            
            % TDM
            y_t = tdm_demod(y_theory, noise_t, N_LED, N_slot);
            Derr_t(idx, trial) = norm(y_t - y_theory) / y_norm * 100;
            RMSE_t(idx, trial) = fdm_metrics(x_gt, ...
                fdm_reconstruct(y_t, A0_working, 'Method', 'tv'));
        end
        fprintf('  SNR = %3d dB done\n', SNR_dB);
    end
end

%% ================================================================
%%                       噪声生成器
%% ================================================================

function [noise_f, noise_t] = noise_awgn(~, ns, seed)
    rng(seed);
    noise_f = ns * randn(1, N_fdm);
    rng(seed);
    noise_t = ns * randn(1, N_LED * N_slot);
end

function [noise_f, noise_t] = noise_inband(nv, ~, seed)
    % 为FDM生成带内噪声 (利用fdm_generate_signal内部实现)
    [v_noisy, t_f, ~] = fdm_generate_signal(y_theory, ...
        'FreqMode', 'auto', 'T', T_fdm, 'Fs', cfg.Fs, ...
        'SNR_dB', Inf, 'SNR_inband_dB', -10*log10(nv/P_signal_fdm), ... % 反算SNR_dB
        'InbandNoiseMode', cfg.INBAND_NOISE_MODE, ...
        'InbandNumTones', cfg.INBAND_NUM_TONES, ...
        'InbandFreqRange', [cfg.f_inband_low, cfg.f_inband_high], ...
        'InbandAvoidCarrier', cfg.INBAND_AVOID_CARRIER, ...
        'InbandGuardBand', cfg.INBAND_GUARD_BAND, ...
        'Seed', seed, 'Waveform', 'sine');
    
    % 提取噪声 = 有噪声信号 - 无噪声信号
    [v_clean, ~, ~] = fdm_generate_signal(y_theory, ...
        'FreqMode', 'auto', 'T', T_fdm, 'Fs', cfg.Fs, ...
        'SNR_dB', Inf, 'Seed', seed, 'Waveform', 'sine');
    noise_f = v_noisy - v_clean;
    
    % TDM: 用相同seed独立生成
    rng(seed);
    N_total = N_LED * N_slot;
    t_t = (0:N_total-1) / cfg.Fs;
    
    if strcmpi(cfg.INBAND_NOISE_MODE, 'multitone')
        M = cfg.INBAND_NUM_TONES;
        if cfg.INBAND_AVOID_CARRIER
            f_tones = avoid_carrier_freqs(M, cfg.f_inband_low, cfg.f_inband_high, ...
                freqs_Hz, cfg.INBAND_GUARD_BAND);
        else
            f_tones = cfg.f_inband_low + (cfg.f_inband_high - cfg.f_inband_low) * rand(1, M);
        end
        phi = 2*pi*rand(1, M);
        noise_t = make_multitone(f_tones, phi, t_t, nv);
    else
        noise_raw = sqrt(nv) * randn(1, N_total);
        f_lo = cfg.f_inband_low / (cfg.Fs/2);
        f_hi = min(cfg.f_inband_high / (cfg.Fs/2), 0.99);
        [b, a] = butter(4, [f_lo, f_hi], 'bandpass');
        noise_t = filter(b, a, noise_raw);
        noise_t = noise_t * sqrt(nv / var(noise_t));
    end
end

function [noise_f, noise_t] = noise_singletone(nv, ~, seed, f0)
    rng(seed);
    phi = 2*pi*rand();
    amp = sqrt(2 * nv);
    
    t_f = (0:N_fdm-1) / cfg.Fs;
    noise_f = amp * cos(2*pi*f0*t_f + phi);
    
    N_total = N_LED * N_slot;
    t_t = (0:N_total-1) / cfg.Fs;
    noise_t = amp * cos(2*pi*f0*t_t + phi);
end

%% ================================================================
%%                       TDM 解调
%% ================================================================

function y_rec = tdm_demod(y_theory, noise, N_LED, N_slot)
    y_rec = zeros(N_LED, 1);
    for i = 1:N_LED
        idx_s = (i-1)*N_slot + 1;
        idx_e = i*N_slot;
        y_rec(i) = mean(y_theory(i) + noise(idx_s:idx_e));
    end
end

%% ================================================================
%%                       绘图系统
%% ================================================================

function plot_dual_metric(res, savename_base)
    % 根据 DUAL_AXIS 选择上下子图或左右子图
    if cfg.DUAL_AXIS
        plot_stacked(res, [savename_base '_dual']);
    else
        plot_sidebyside(res, savename_base);
    end
end

function plot_stacked(res, savename)
    % 上下子图: 上=RMSE(蓝色系,实线), 下=Demod(红色系,虚线)
    fig = make_figure(sty.FIG_WIDTH_CM, sty.FIG_HEIGHT_CM);
    
    pw = 1 - sty.margin_left - sty.margin_right;
    ph = (1 - sty.margin_bottom - sty.margin_top - sty.gap) / 2;
    
    % --- 上图: RMSE ---
    axes('Position', [sty.margin_left, sty.margin_bottom+ph+sty.gap, pw, ph]);
    hold on; box on;
    
    h1 = plot_line(res.snr, res.rmse_ofe, 'o-', sty.color_rmse.ofe, true);
    h2 = plot_line(res.snr, res.rmse_tdm, 's-', sty.color_rmse.tdm, true);
    
    ylabel('RMSE', 'FontSize', sty.FONTSIZE, 'FontName', 'Arial');
    set(gca, 'YScale', 'log', 'XTickLabel', []);
    apply_axis_style();
    xlim([min(res.snr)-2, max(res.snr)+2]);
    add_legend([h1, h2], {'OFE', 'TDM'});
    
    % --- 下图: Demod Error ---
    axes('Position', [sty.margin_left, sty.margin_bottom, pw, ph]);
    hold on; box on;
    
    h3 = plot_line(res.snr, res.demod_ofe, 'o--', sty.color_demod.ofe, false);
    h4 = plot_line(res.snr, res.demod_tdm, 's--', sty.color_demod.tdm, false);
    
    ylabel('Demod. Error (%)', 'FontSize', sty.FONTSIZE, 'FontName', 'Arial');
    xlabel('SNR (dB)', 'FontSize', sty.FONTSIZE, 'FontName', 'Arial');
    set(gca, 'YScale', 'log');
    apply_axis_style();
    xlim([min(res.snr)-2, max(res.snr)+2]);
    add_legend([h3, h4], {'OFE', 'TDM'});
    
    save_figure(savename);
end

function plot_sidebyside(res, savename)
    % 左右子图
    fig = make_figure(sty.FIG_WIDTH_CM_DUAL, sty.FIG_HEIGHT_CM);
    
    subplot(1,2,1); hold on; box on;
    h1 = plot_line(res.snr, res.rmse_ofe, 'o-', sty.color_ofe, true);
    h2 = plot_line(res.snr, res.rmse_tdm, 's-', sty.color_tdm, true);
    set(gca, 'YScale', 'log');
    xlabel('SNR (dB)', 'FontSize', sty.FONTSIZE);
    ylabel('RMSE', 'FontSize', sty.FONTSIZE);
    apply_axis_style();
    xlim([min(res.snr)-2, max(res.snr)+2]);
    add_legend([h1, h2], {'OFE', 'TDM'});
    
    subplot(1,2,2); hold on; box on;
    h3 = plot_line(res.snr, res.demod_ofe, 'o-', sty.color_ofe, true);
    h4 = plot_line(res.snr, res.demod_tdm, 's-', sty.color_tdm, true);
    set(gca, 'YScale', 'log');
    xlabel('SNR (dB)', 'FontSize', sty.FONTSIZE);
    ylabel('Demodulation Error (%)', 'FontSize', sty.FONTSIZE);
    apply_axis_style();
    xlim([min(res.snr)-2, max(res.snr)+2]);
    add_legend([h3, h4], {'OFE', 'TDM'});
    
    save_figure(savename);
end

%% ================================================================
%%                       绘图原子操作
%% ================================================================

function h = plot_line(x, y, linespec, color, filled)
    if filled
        h = plot(x, y, linespec, 'LineWidth', sty.LINE_WIDTH, ...
            'MarkerSize', sty.MARKER_SIZE, 'Color', color, ...
            'MarkerFaceColor', color);
    else
        h = plot(x, y, linespec, 'LineWidth', sty.LINE_WIDTH, ...
            'MarkerSize', sty.MARKER_SIZE, 'Color', color, ...
            'MarkerFaceColor', 'none', 'MarkerEdgeColor', color);
    end
end

function fig = make_figure(w_cm, h_cm)
    fig = figure('Units', 'centimeters', 'Position', [2,2,w_cm,h_cm], 'Color', 'w');
    set(fig, 'PaperUnits', 'centimeters', 'PaperSize', [w_cm, h_cm], ...
        'PaperPosition', [0, 0, w_cm, h_cm]);
end

function apply_axis_style()
    set(gca, 'FontSize', sty.FONTSIZE_TICK, 'FontName', 'Arial', ...
        'LineWidth', sty.LINE_WIDTH_AXIS);
    if cfg.SHOW_GRID
        grid on; set(gca, 'GridLineStyle', ':', 'GridAlpha', 0.3);
    end
end

function add_legend(handles, labels)
    leg = legend(handles, labels, 'Location', 'northeast', ...
        'FontSize', sty.FONTSIZE_LEGEND);
    leg.Box = 'off';
end

function save_figure(savename)
    print(gcf, savename, '-dpng', '-r300');
    print(gcf, savename, '-depsc', '-r300');
    fprintf('Saved: %s.png and %s.eps\n', savename, savename);
end

%% ================================================================
%%                       数据打包与输出
%% ================================================================

function res = pack_results(RMSE_f, RMSE_t, Derr_f, Derr_t)
    res.snr = cfg.snr_list;
    res.rmse_ofe = mean(RMSE_f, 2);
    res.rmse_tdm = mean(RMSE_t, 2);
    res.demod_ofe = mean(Derr_f, 2);
    res.demod_tdm = mean(Derr_t, 2);
end

function print_results_table(res)
    fprintf('\n============================================================\n');
    fprintf('%8s | %10s %10s | %10s %10s\n', ...
        'SNR(dB)', 'RMSE_OFE', 'RMSE_TDM', 'Demod_OFE', 'Demod_TDM');
    fprintf('%s\n', repmat('-', 1, 60));
    for i = 1:length(res.snr)
        fprintf('%8d | %10.4f %10.4f | %10.2f%% %10.2f%%\n', ...
            res.snr(i), res.rmse_ofe(i), res.rmse_tdm(i), ...
            res.demod_ofe(i), res.demod_tdm(i));
    end
    fprintf('============================================================\n');
end

function fprintf_header(title)
    fprintf('============================================================\n');
    fprintf('%s\n', title);
    fprintf('============================================================\n\n');
end

%% ================================================================
%%                       工具函数
%% ================================================================

function noise = make_multitone(freqs, phases, t, target_var)
    M = length(freqs);
    noise = zeros(1, length(t));
    for j = 1:M
        noise = noise + cos(2*pi*freqs(j)*t + phases(j));
    end
    if var(noise) > 0
        noise = noise * sqrt(target_var / var(noise));
    end
end

function f_tones = avoid_carrier_freqs(M, f_lo, f_hi, carrier_freqs, guard)
    f_tones = zeros(1, M);
    for j = 1:M
        for attempt = 1:1000
            fc = f_lo + (f_hi - f_lo) * rand();
            if all(abs(fc - carrier_freqs) > guard)
                f_tones(j) = fc;
                break;
            end
        end
        if f_tones(j) == 0
            f_tones(j) = f_lo + (f_hi - f_lo) * rand();
        end
    end
end

function y_recovered = fdm_lockin_demod(v_fdm, t_fdm, params)
    N_LED = length(params.FreqsHz);
    y_recovered = zeros(N_LED, 1);
    for i = 1:N_LED
        ref = sin(2*pi*params.FreqsHz(i)*t_fdm + params.Phases(i));
        y_recovered(i) = (2/params.T) * sum(v_fdm .* ref) * params.dt;
    end
end

end  % === 主函数 tdm_vs_ofe_sim_v2 结束 ===
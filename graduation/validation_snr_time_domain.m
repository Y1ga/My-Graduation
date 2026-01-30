%% FDM论文仿真：时域信号对比图
% MODE 1: 白噪声 (AWGN)
% MODE 2: 带内随机噪声 (30-410 kHz)
% MODE 3: 100Hz工频干扰
% MODE 4: DC环境光
% MODE 5: PWM调光噪声 (20kHz)
% MODE 6: SMPS开关噪声 (100kHz)
% MODE A: 三种SNR噪声对比 (AWGN, In-band, 100Hz)
% MODE B: 三种环境噪声对比 (DC, PWM, SMPS)
clear; clc; close all;

%% 选择模式
% MODE = 'A': 三种SNR噪声对比 (AWGN, In-band, 100Hz)
% MODE = 'B': 三种环境噪声对比 (DC, PWM, SMPS)
% MODE = 1-6: 单独模式
MODE = 'B';

%% 加载数据
A0 = load_mat("led_0711", "gt");
colorchecker = load_mat("colorchecker_trans_0118", "gt");

if size(A0,1) == 31, A0 = A0'; end
if size(colorchecker,1) == 31, colorchecker = colorchecker'; end

working_leds = [1,2,3,4,5,6,7,8,9,10,11,12];
A0_working = A0(working_leds, :);
x_gt = colorchecker(15, :)';
y_theory = A0_working * x_gt;

%% 统一设置
FIG_WIDTH = 600;
FIG_HEIGHT = 400;
FONTSIZE = 16;
FONTSIZE_LEGEND = FONTSIZE - 4;
FONTSIZE_TICK = FONTSIZE - 2;
LINE_WIDTH = 1.0;

% 时间显示范围 (μs)
T_DISPLAY = 100;  % 显示前100μs

%% 配色 (低饱和度)
color_clean = [0.25, 0.25, 0.25];   % 深灰 - 无噪声

%% 判断是否为MODE A
if strcmp(MODE, 'A') || strcmpi(MODE, 'a')
    %% ========== MODE A: 三种SNR噪声对比 ==========
    mode_name = 'Comparison: AWGN vs In-band vs 100Hz';
    
    % 配色方案开关
    USE_VIVID_COLOR = true;  % true: 鲜艳配色, false: 低饱和度配色
    SHOW_GRID = false;        % true: 显示网格线, false: 不显示网格线
    
    % 各噪声类型的SNR
    SNR_AWGN = 20;      % 白噪声 SNR
    SNR_INBAND = 30;    % 带内噪声 SNR  
    SNR_100HZ = 20;     % 100Hz噪声 SNR
    
    % 局部放大时间范围 (μs)
    T_START = 0;    % 起始时间
    T_END = 10;     % 结束时间 (10μs窗口)
    
    % 生成无噪声信号
    [v_clean, t, params] = fdm_generate_signal(y_theory, ...
        'FreqMode', 'auto', 'SNR_dB', Inf, 'Seed', 42, 'Waveform', 'square');
    
    % 生成三种含噪信号
    [v_awgn, ~, ~] = fdm_generate_signal(y_theory, ...
        'FreqMode', 'auto', 'SNR_dB', SNR_AWGN, 'Seed', 42, 'Waveform', 'square');
    
    [v_inband, ~, ~] = fdm_generate_signal(y_theory, ...
        'FreqMode', 'auto', 'SNR_dB', Inf, 'SNR_inband_dB', SNR_INBAND, ...
        'Seed', 42, 'Waveform', 'square');
    
    [v_100hz, ~, ~] = fdm_generate_signal(y_theory, ...
        'FreqMode', 'auto', 'SNR_dB', Inf, 'SNR_100Hz_dB', SNR_100HZ, ...
        'Seed', 42, 'Waveform', 'square');
    
    % 时间轴转换
    t_us = t * 1e6;
    idx_display = (t_us >= T_START) & (t_us <= T_END);
    
    % 配色方案
    color_clean = [0.15, 0.15, 0.15];     % 深黑 - 纯信号 (两种方案共用)
    
    if USE_VIVID_COLOR
        % 鲜艳配色
        color_awgn = [0.85, 0.20, 0.20];      % 鲜红 - AWGN
        color_inband = [0.20, 0.45, 0.85];    % 鲜蓝 - In-band
        color_100hz = [0.20, 0.70, 0.30];     % 鲜绿 - 100Hz
    else
        % 低饱和度配色
        color_awgn = [0.65, 0.30, 0.30];      % 暗红 - AWGN
        color_inband = [0.30, 0.50, 0.70];    % 灰蓝 - In-band
        color_100hz = [0.45, 0.60, 0.35];     % 灰绿 - 100Hz
    end
    
    %% 绘图 - 单图四曲线
    fig = figure('Position', [100, 100, FIG_WIDTH, FIG_HEIGHT], 'Color', 'w');
    hold on; box on;
    
    if SHOW_GRID
        grid on;
        set(gca, 'GridLineStyle', ':', 'GridAlpha', 0.3);
    end
    
    % 先画三种噪声信号（虚线）
    h_awgn = plot(t_us(idx_display), v_awgn(idx_display), '--', ...
        'LineWidth', 1.3, 'Color', color_awgn);
    h_inband = plot(t_us(idx_display), v_inband(idx_display), '-.', ...
        'LineWidth', 1.3, 'Color', color_inband);
    h_100hz = plot(t_us(idx_display), v_100hz(idx_display), ':', ...
        'LineWidth', 1.5, 'Color', color_100hz);
    
    % 最后画纯信号（实线，在最上层）
    h_clean = plot(t_us(idx_display), v_clean(idx_display), '-', ...
        'LineWidth', 1.8, 'Color', color_clean);
    
    xlabel('Time (μs)', 'FontSize', FONTSIZE, 'FontName', 'Arial');
    ylabel('Amplitude (a.u.)', 'FontSize', FONTSIZE, 'FontName', 'Arial');
    
    legend([h_clean, h_awgn, h_inband, h_100hz], ...
        {'Noiseless', ...
         sprintf('AWGN (SNR = %d dB)', SNR_AWGN), ...
         sprintf('In-band noise (SNR = %d dB)', SNR_INBAND), ...
         sprintf('100 Hz noise (SNR = %d dB)', SNR_100HZ)}, ...
        'Location', 'best', 'FontSize', FONTSIZE_LEGEND, 'Box', 'off');
    
    set(gca, 'FontSize', FONTSIZE_TICK, 'FontName', 'Arial', 'LineWidth', 0.8);
    xlim([T_START, T_END]);
    
    % 保存图片
    if USE_VIVID_COLOR
        savename = 'fig_time_domain_comparison_vivid';
    else
        savename = 'fig_time_domain_comparison';
    end
    print(gcf, savename, '-dpng', '-r300');
    print(gcf, savename, '-depsc', '-r300');
    fprintf('Saved: %s.png and %s.eps\n', savename, savename);
    
    % 打印信息
    fprintf('\n============================================================\n');
    fprintf('MODE A: %s\n', mode_name);
    fprintf('============================================================\n');
    fprintf('Color scheme: %s\n', ternary(USE_VIVID_COLOR, 'Vivid', 'Muted'));
    fprintf('Sampling rate: %.1f MHz\n', params.Fs/1e6);
    fprintf('Sampling time: %.1f us\n', params.T*1e6);
    fprintf('Display time: %.1f - %.1f us (zoomed)\n', T_START, T_END);
    fprintf('Modulation frequencies: %.0f - %.0f kHz\n', min(params.FreqsKHz), max(params.FreqsKHz));
    fprintf('\nNoise parameters:\n');
    fprintf('  AWGN:    SNR = %d dB\n', SNR_AWGN);
    fprintf('  In-band: SNR = %d dB\n', SNR_INBAND);
    fprintf('  100 Hz:  SNR = %d dB\n', SNR_100HZ);
    
    return;  % MODE A 结束后退出
end

%% ========== MODE B: DC/PWM/SMPS对比 ==========
if strcmp(MODE, 'B') || strcmpi(MODE, 'b')
    mode_name = 'Comparison: DC vs PWM vs SMPS';
    
    % 配色方案开关
    USE_VIVID_COLOR = true;  % true: 鲜艳配色, false: 低饱和度配色
    SHOW_GRID = false;        % true: 显示网格线, false: 不显示网格线
    USE_DB_DISPLAY = true;    % true: 图例显示dB, false: 显示倍数
    T_END = 50;              % X轴最大值 (μs): 需要足够长才能看到PWM周期(50μs)
    
    % 各噪声类型的强度（相对信号的倍数）
    % RATIO = 10 对应 SNR = -20*log10(10) = -20 dB
    RATIO_DC = 10;        % DC环境光倍数
    RATIO_PWM = 10;       % PWM调光噪声倍数
    RATIO_SMPS = 10;      % SMPS开关噪声倍数
    
    % 噪声频率参数
    PWM_FREQ = 20e3;      % PWM频率 20kHz (周期50μs)
    SMPS_FREQ = 100e3;    % SMPS频率 100kHz (周期10μs)
    
    % 局部放大时间范围 (μs)
    T_START = 0;    % 起始时间
    % T_END 已在上方开关区定义
    
    % 生成无噪声信号
    [v_clean, t, params] = fdm_generate_signal(y_theory, ...
        'FreqMode', 'auto', 'SNR_dB', Inf, 'Seed', 42, 'Waveform', 'square');
    
    % 生成三种含噪信号
    % DC环境光
    [v_dc, ~, ~] = fdm_generate_signal(y_theory, ...
        'FreqMode', 'auto', 'SNR_dB', Inf, 'AmbientDC', RATIO_DC, ...
        'Seed', 42, 'Waveform', 'square');
    
    % PWM调光噪声 (20kHz)
    [v_pwm, ~, ~] = fdm_generate_signal(y_theory, ...
        'FreqMode', 'auto', 'SNR_dB', Inf, 'AmbientSMPS', RATIO_PWM, ...
        'SMPSFreqHz', PWM_FREQ, 'Seed', 42, 'Waveform', 'square');
    
    % SMPS开关噪声 (100kHz)
    [v_smps, ~, ~] = fdm_generate_signal(y_theory, ...
        'FreqMode', 'auto', 'SNR_dB', Inf, 'AmbientSMPS', RATIO_SMPS, ...
        'SMPSFreqHz', SMPS_FREQ, 'Seed', 42, 'Waveform', 'square');
    
    % 时间轴转换
    t_us = t * 1e6;
    idx_display = (t_us >= T_START) & (t_us <= T_END);
    
    % 配色方案
    color_clean = [0.15, 0.15, 0.15];     % 深黑 - 纯信号 (两种方案共用)
    
    if USE_VIVID_COLOR
        % 鲜艳配色 (与MODE A一致)
        color_dc = [0.85, 0.20, 0.20];        % 鲜红 - DC
        color_pwm = [0.20, 0.45, 0.85];       % 鲜蓝 - PWM
        color_smps = [0.20, 0.70, 0.30];      % 鲜绿 - SMPS
    else
        % 低饱和度配色 (与MODE A一致)
        color_dc = [0.65, 0.30, 0.30];        % 暗红 - DC
        color_pwm = [0.30, 0.50, 0.70];       % 灰蓝 - PWM
        color_smps = [0.45, 0.60, 0.35];      % 灰绿 - SMPS
    end
    
    %% 绘图 - 单图四曲线
    fig = figure('Position', [100, 100, FIG_WIDTH, FIG_HEIGHT], 'Color', 'w');
    hold on; box on;
    
    if SHOW_GRID
        grid on;
        set(gca, 'GridLineStyle', ':', 'GridAlpha', 0.3);
    end
    
    % 先画三种噪声信号（虚线）
    h_dc = plot(t_us(idx_display), v_dc(idx_display), '--', ...
        'LineWidth', 1.3, 'Color', color_dc);
    h_pwm = plot(t_us(idx_display), v_pwm(idx_display), '-.', ...
        'LineWidth', 1.3, 'Color', color_pwm);
    h_smps = plot(t_us(idx_display), v_smps(idx_display), ':', ...
        'LineWidth', 1.5, 'Color', color_smps);
    
    % 最后画纯信号（实线，在最上层）
    h_clean = plot(t_us(idx_display), v_clean(idx_display), '-', ...
        'LineWidth', 1.8, 'Color', color_clean);
    
    xlabel('Time (μs)', 'FontSize', FONTSIZE, 'FontName', 'Arial');
    ylabel('Amplitude (a.u.)', 'FontSize', FONTSIZE, 'FontName', 'Arial');
    
    % 根据开关选择显示格式
    if USE_DB_DISPLAY
        % 倍数转信噪比SNR: SNR_dB = -20*log10(noise_ratio)
        % noise_ratio是噪声/信号，所以SNR是信号/噪声，取负号
        SNR_DC = -20*log10(RATIO_DC);
        SNR_PWM = -20*log10(RATIO_PWM);
        SNR_SMPS = -20*log10(RATIO_SMPS);
        legend([h_clean, h_dc, h_pwm, h_smps], ...
            {'Noiseless', ...
             sprintf('DC noise'), ...
             sprintf('20 kHz PWM noise'), ...
             sprintf('100 kHz SMPS noise')}, ...
            'Location', 'best', 'FontSize', FONTSIZE_LEGEND, 'Box', 'off');
    else
        legend([h_clean, h_dc, h_pwm, h_smps], ...
            {'Noiseless', ...
             sprintf('DC noise (%dx)', RATIO_DC), ...
             sprintf('20 kHz PWM noise (%dx)', RATIO_PWM), ...
             sprintf('100 kHz SMPS noise (%dx)', RATIO_SMPS)}, ...
            'Location', 'best', 'FontSize', FONTSIZE_LEGEND, 'Box', 'off');
    end
    
    set(gca, 'FontSize', FONTSIZE_TICK, 'FontName', 'Arial', 'LineWidth', 0.8);
    xlim([T_START, T_END]);
    
    % 保存图片
    if USE_VIVID_COLOR
        savename = 'fig_time_domain_ambient_comparison_vivid';
    else
        savename = 'fig_time_domain_ambient_comparison';
    end
    print(gcf, savename, '-dpng', '-r300');
    print(gcf, savename, '-depsc', '-r300');
    fprintf('Saved: %s.png and %s.eps\n', savename, savename);
    
    % 打印信息
    fprintf('\n============================================================\n');
    fprintf('MODE B: %s\n', mode_name);
    fprintf('============================================================\n');
    fprintf('Color scheme: %s\n', ternary(USE_VIVID_COLOR, 'Vivid', 'Muted'));
    fprintf('Display format: %s\n', ternary(USE_DB_DISPLAY, 'dB', 'ratio'));
    fprintf('Sampling rate: %.1f MHz\n', params.Fs/1e6);
    fprintf('Sampling time: %.1f us\n', params.T*1e6);
    fprintf('Display time: %.1f - %.1f us\n', T_START, T_END);
    fprintf('Modulation frequencies: %.0f - %.0f kHz\n', min(params.FreqsKHz), max(params.FreqsKHz));
    fprintf('\nAmbient noise parameters:\n');
    if USE_DB_DISPLAY
        fprintf('  DC ambient:     SNR = %.0f dB (noise %.0fx signal)\n', -20*log10(RATIO_DC), RATIO_DC);
        fprintf('  PWM dimming:    SNR = %.0f dB (noise %.0fx signal) @ %.0f kHz\n', -20*log10(RATIO_PWM), RATIO_PWM, PWM_FREQ/1e3);
        fprintf('  SMPS switching: SNR = %.0f dB (noise %.0fx signal) @ %.0f kHz\n', -20*log10(RATIO_SMPS), RATIO_SMPS, SMPS_FREQ/1e3);
    else
        fprintf('  DC ambient:     %dx signal level\n', RATIO_DC);
        fprintf('  PWM dimming:    %dx @ %.0f kHz\n', RATIO_PWM, PWM_FREQ/1e3);
        fprintf('  SMPS switching: %dx @ %.0f kHz\n', RATIO_SMPS, SMPS_FREQ/1e3);
    end
    
    return;  % MODE B 结束后退出
end

%% 辅助函数
function result = ternary(condition, true_val, false_val)
    if condition
        result = true_val;
    else
        result = false_val;
    end
end

%% 根据模式设置参数并生成信号 (MODE 1-6)
% 先生成无噪声信号
[v_clean, t, params] = fdm_generate_signal(y_theory, ...
    'FreqMode', 'auto', 'SNR_dB', Inf, 'Seed', 42, 'Waveform', 'square');

switch MODE
    case 1
        %% ========== MODE 1: 白噪声 ==========
        mode_name = 'AWGN';
        snr_list = [40, 30, 20, 10];  % 不同SNR级别
        n_levels = length(snr_list);
        
        v_noisy_all = cell(n_levels, 1);
        noise_all = cell(n_levels, 1);
        legend_str = cell(n_levels, 1);
        
        for i = 1:n_levels
            [v_noisy_all{i}, ~, ~] = fdm_generate_signal(y_theory, ...
                'FreqMode', 'auto', 'SNR_dB', snr_list(i), 'Seed', 42, 'Waveform', 'square');
            noise_all{i} = v_noisy_all{i} - v_clean;
            legend_str{i} = sprintf('SNR = %d dB', snr_list(i));
        end
        
        x_label_param = 'SNR (dB)';
        savename = 'fig_time_domain_awgn';
        
    case 2
        %% ========== MODE 2: 带内随机噪声 ==========
        mode_name = 'In-band noise (30-410 kHz)';
        snr_list = [40, 30, 20, 10];
        n_levels = length(snr_list);
        
        v_noisy_all = cell(n_levels, 1);
        noise_all = cell(n_levels, 1);
        legend_str = cell(n_levels, 1);
        
        for i = 1:n_levels
            [v_noisy_all{i}, ~, ~] = fdm_generate_signal(y_theory, ...
                'FreqMode', 'auto', 'SNR_dB', Inf, 'SNR_inband_dB', snr_list(i), ...
                'Seed', 42, 'Waveform', 'square');
            noise_all{i} = v_noisy_all{i} - v_clean;
            legend_str{i} = sprintf('SNR = %d dB', snr_list(i));
        end
        
        x_label_param = 'In-band SNR (dB)';
        savename = 'fig_time_domain_inband';
        
    case 3
        %% ========== MODE 3: 100Hz工频干扰 ==========
        mode_name = '100 Hz noise';
        snr_list = [40, 30, 20, 10];
        n_levels = length(snr_list);
        
        v_noisy_all = cell(n_levels, 1);
        noise_all = cell(n_levels, 1);
        legend_str = cell(n_levels, 1);
        
        for i = 1:n_levels
            [v_noisy_all{i}, ~, ~] = fdm_generate_signal(y_theory, ...
                'FreqMode', 'auto', 'SNR_dB', Inf, 'SNR_100Hz_dB', snr_list(i), ...
                'Seed', 42, 'Waveform', 'square');
            noise_all{i} = v_noisy_all{i} - v_clean;
            legend_str{i} = sprintf('SNR = %d dB', snr_list(i));
        end
        
        x_label_param = '100 Hz SNR (dB)';
        savename = 'fig_time_domain_100hz';
        
    case 4
        %% ========== MODE 4: DC环境光 ==========
        mode_name = 'DC ambient light';
        ratio_list = [1, 10, 100, 1000];
        n_levels = length(ratio_list);
        
        v_noisy_all = cell(n_levels, 1);
        noise_all = cell(n_levels, 1);
        legend_str = cell(n_levels, 1);
        
        for i = 1:n_levels
            [v_noisy_all{i}, ~, ~] = fdm_generate_signal(y_theory, ...
                'FreqMode', 'auto', 'SNR_dB', Inf, 'AmbientDC', ratio_list(i), ...
                'Seed', 42, 'Waveform', 'square');
            noise_all{i} = v_noisy_all{i} - v_clean;
            legend_str{i} = sprintf('%dx', ratio_list(i));
        end
        
        x_label_param = 'DC ratio';
        savename = 'fig_time_domain_dc';
        
    case 5
        %% ========== MODE 5: PWM调光噪声 (20kHz) ==========
        mode_name = 'PWM dimming (20 kHz)';
        ratio_list = [1, 10, 100, 1000];
        n_levels = length(ratio_list);
        PWM_FREQ = 20e3;
        
        v_noisy_all = cell(n_levels, 1);
        noise_all = cell(n_levels, 1);
        legend_str = cell(n_levels, 1);
        
        for i = 1:n_levels
            [v_noisy_all{i}, ~, ~] = fdm_generate_signal(y_theory, ...
                'FreqMode', 'auto', 'SNR_dB', Inf, 'AmbientSMPS', ratio_list(i), ...
                'SMPSFreqHz', PWM_FREQ, 'Seed', 42, 'Waveform', 'square');
            noise_all{i} = v_noisy_all{i} - v_clean;
            legend_str{i} = sprintf('%dx', ratio_list(i));
        end
        
        x_label_param = 'PWM ratio';
        savename = 'fig_time_domain_pwm';
        
    case 6
        %% ========== MODE 6: SMPS开关噪声 (100kHz) ==========
        mode_name = 'SMPS switching (100 kHz)';
        ratio_list = [1, 10, 100, 1000];
        n_levels = length(ratio_list);
        SMPS_FREQ = 100e3;
        
        v_noisy_all = cell(n_levels, 1);
        noise_all = cell(n_levels, 1);
        legend_str = cell(n_levels, 1);
        
        for i = 1:n_levels
            [v_noisy_all{i}, ~, ~] = fdm_generate_signal(y_theory, ...
                'FreqMode', 'auto', 'SNR_dB', Inf, 'AmbientSMPS', ratio_list(i), ...
                'SMPSFreqHz', SMPS_FREQ, 'Seed', 42, 'Waveform', 'square');
            noise_all{i} = v_noisy_all{i} - v_clean;
            legend_str{i} = sprintf('%dx', ratio_list(i));
        end
        
        x_label_param = 'SMPS ratio';
        savename = 'fig_time_domain_smps';
        
    otherwise
        error('Unknown MODE: %d. Use 1-6.', MODE);
end

%% 时间轴转换
t_us = t * 1e6;
idx_display = t_us <= T_DISPLAY;

%% 生成渐变色 (低饱和度)
cmap = zeros(n_levels, 3);
for i = 1:n_levels
    t_color = (i-1) / max(n_levels-1, 1);
    % 从灰蓝到灰红渐变 (低饱和度)
    cmap(i,:) = [0.35+0.30*t_color, 0.45-0.15*t_color, 0.55-0.25*t_color];
end

%% 绘图
fig = figure('Position', [100, 100, FIG_WIDTH, FIG_HEIGHT], 'Color', 'w');

% === 子图1: 纯噪声对比 ===
ax1 = subplot(1, 2, 1);
hold on; box on; grid on;

h_noise = gobjects(n_levels, 1);
for i = 1:n_levels
    h_noise(i) = plot(t_us(idx_display), noise_all{i}(idx_display), '-', ...
        'LineWidth', LINE_WIDTH, 'Color', cmap(i,:));
end

xlabel('Time (\mus)', 'FontSize', FONTSIZE, 'FontName', 'Arial');
ylabel('Amplitude (a.u.)', 'FontSize', FONTSIZE, 'FontName', 'Arial');
legend(h_noise, legend_str, 'Location', 'best', 'FontSize', FONTSIZE_LEGEND, 'Box', 'off');
set(gca, 'FontSize', FONTSIZE_TICK, 'FontName', 'Arial', 'LineWidth', 0.8);
set(gca, 'GridLineStyle', ':', 'GridAlpha', 0.4);
xlim([0, T_DISPLAY]);

% === 子图2: 信号+噪声对比 ===
ax2 = subplot(1, 2, 2);
hold on; box on; grid on;

% 先画无噪声信号
h_clean = plot(t_us(idx_display), v_clean(idx_display), '-', ...
    'LineWidth', LINE_WIDTH+0.5, 'Color', color_clean);

% 画最差情况的含噪信号
h_noisy = plot(t_us(idx_display), v_noisy_all{end}(idx_display), '-', ...
    'LineWidth', LINE_WIDTH, 'Color', cmap(end,:));

xlabel('Time (\mus)', 'FontSize', FONTSIZE, 'FontName', 'Arial');
ylabel('Amplitude (a.u.)', 'FontSize', FONTSIZE, 'FontName', 'Arial');
legend([h_clean, h_noisy], {'Clean signal', ['Noisy (' legend_str{end} ')']}, ...
    'Location', 'best', 'FontSize', FONTSIZE_LEGEND, 'Box', 'off');
set(gca, 'FontSize', FONTSIZE_TICK, 'FontName', 'Arial', 'LineWidth', 0.8);
set(gca, 'GridLineStyle', ':', 'GridAlpha', 0.4);
xlim([0, T_DISPLAY]);

% 调整子图位置
set(ax1, 'Position', [0.08, 0.15, 0.40, 0.78]);
set(ax2, 'Position', [0.56, 0.15, 0.40, 0.78]);

%% 保存图片
print(gcf, savename, '-dpng', '-r300');
print(gcf, savename, '-depsc', '-r300');
fprintf('Saved: %s.png and %s.eps\n', savename, savename);

%% 打印信息
fprintf('\n============================================================\n');
fprintf('MODE %d: %s\n', MODE, mode_name);
fprintf('============================================================\n');
fprintf('Sampling rate: %.1f MHz\n', params.Fs/1e6);
fprintf('Sampling time: %.1f us\n', params.T*1e6);
fprintf('Display time: %.1f us\n', T_DISPLAY);
fprintf('Modulation frequencies: %.0f - %.0f kHz\n', min(params.FreqsKHz), max(params.FreqsKHz));
fprintf('\nNoise levels tested:\n');
for i = 1:n_levels
    fprintf('  %d. %s\n', i, legend_str{i});
end
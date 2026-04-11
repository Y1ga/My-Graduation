clear; 
clc;
%% 加载基础数据
A0 = load_mat("led_pd_0118", "gt")';
colorchecker = load_mat("colorchecker_trans_0118", "gt");
idx = 15;
x = colorchecker(:, idx);

%% 画时域图
path = "W:\Github\My-Repository\My-Graduation\Paper-OTFE\process_data\data\PD-01-18/I/新建文件";
duration = 100e-5;
% 简洁调用：截取前20%，降采样10倍
file_signal_idx = 2;
fs = 1e9;
duty_cycle = 10;
downsampling_rate = 100;
signal_path = path+num2str(file_signal_idx)+".wfm";
noise_path = path+num2str(file_noise_idx)+".wfm";
[~, v_noise] = read_rigol_wfm_sampled(noise_path, fs, duration, duty_cycle, downsampling_rate);
[t, v_signal] = read_rigol_wfm_sampled(signal_path, fs, duration, duty_cycle, downsampling_rate);
[y_signal, ~, freq_detected] = read_rigol_wfm(signal_path, fs, duration);
t = t * 1e6;
plot(t, v_signal,'Color', [0.85, 0.45, 0.40]);
xlabel('Time (μs)');
ylabel('Voltage (a.u.)');
legend('SNR: 23.11dB');
h_gt = gcf;
FONT_SIZE = 16;
h = set_fig(h_gt, 'Arial', FONT_SIZE, 1.5, [16, 12], show_legend);
ylim([0, max(v_noise)]);
hold off;
%%

file_noise_idx = 28;
noise_path = path+num2str(file_noise_idx)+".wfm";
[~, v_noise] = read_rigol_wfm_sampled(noise_path, fs, duration, duty_cycle, downsampling_rate);
[y_noise, ~] = read_rigol_wfm(noise_path, fs, duration);
plot(t, v_noise,'Color', [0.30, 0.50, 0.70]);
xlabel('Time (μs)');
ylabel('Voltage (a.u.)');
legend('SNR: -11.77dB');
FONT_SIZE = 16;
show_legend = true;
h_gt = gcf;
ylim([0, max(v_noise)]);
h = set_fig(h_gt, 'Arial', FONT_SIZE, 1.5, [18, 15], show_legend);
%% 画频域图
do_plot = true;
freq_max = 500;
% fft_signal = plot_rigol_fft(signal_path, fs, duration, freq_max, do_plot, true);
fft_noise = plot_rigol_fft(noise_path, fs, duration, freq_max, do_plot, false);
h_gt = gcf;
FONT_SIZE = 16;
% xlabel('Noise-to-Signal Ratio', 'FontSize', 11);
% ylabel('PSNR (dB)', 'FontSize', 11);
show_legend = false;
h = set_fig(h_gt, 'Arial', FONT_SIZE, 1.5, [18, 15], show_legend);
%% 画信噪比-RMSE曲线
model_dir_path = "W:\Github\My-Repository\LiteSpectralNet\runs\";
model_path = "20260121_154837_spectral_12in_31out_train90k_noise0\";
file_name = "spectral_predictions.mat";
data = load(model_dir_path + model_path + file_name);
Y_gt = data.Y_gt;
Y_pred = data.Y_pred;
rmse = RMSE(Y_gt, Y_pred, 2);
psnr = PSNR(rmse);
n_files = size(Y_gt, 1);
noise_psnr_raw_data = load_mat("noise_psnr_data", "gt");
noise = noise_psnr_raw_data(:, 1);
noise_psnr = zeros(n_files, 2);
noise_psnr(:, 1) = noise;
noise_psnr(:, 2) = psnr;
[noise_psnr_sorted, sorted_idx] = sortrows(noise_psnr, 1);
selected_list = [1, 2, 8, 19, 23, 29, 32,38, 43, 44, 46];

Y_pred_sorted = Y_pred(sorted_idx, :);
x_pred_selected = Y_pred_sorted(selected_list, :);

noise = noise_psnr_sorted(selected_list, 1);
psnr = noise_psnr_sorted(selected_list, 2);
x_pred_double_selected = x_pred_selected(1:6, :);
noise_double_selected = noise(1:6, :);

%%
figure(2);
% plot(noise, psnr);
noise_selected2 = noise(3:11, :);
psnr_selected2 = psnr(3:11, :);
ax = gca;
plot(ax, noise_selected2, psnr_selected2, '--s', ... % Line with circle markers
     'Color', [0 0.4470 0.7410], ... % A nice blue color
     'LineWidth', 2, ... % Line thickness
     'MarkerSize', 6, ... % Marker size
     'MarkerFaceColor', [0 0.4470 0.7410], ... % Filled markers
     'MarkerEdgeColor', [0 0.4470 0.7410]); % Marker edge color

h_gt = gcf;
FONT_SIZE = 16;
xlabel('Noise-to-Signal Ratio', 'FontSize', 11);
ylabel('PSNR (dB)', 'FontSize', 11);
h = set_fig(h_gt, 'Arial', FONT_SIZE, 1.5, [18, 14]);
%% 
% 光谱重建对比图
wav = linspace(400, 700, 31);
x_gt = Y_gt(1, :);
hold on;
% 定义低饱和度颜色（柔和色调）
colors = [
    0.4, 0.6, 0.8;   % 浅蓝
    0.8, 0.5, 0.5;   % 浅红
    0.5, 0.7, 0.5;   % 浅绿
    0.7, 0.5, 0.7;   % 浅紫
    0.8, 0.7, 0.4;   % 浅黄
    0.5, 0.7, 0.7;   % 浅青
];

% 根据noise_double_selected生成图例名称
pred_names = cell(length(noise_double_selected), 1);
for i = 1:length(noise_double_selected)
    pred_names{i} = sprintf('Noise-to-Signal Ratio: %.1f', noise_double_selected(i) );
    % 或者如果噪声值本身就是百分比形式：
    % pred_names{i} = sprintf('噪声 %.1f%%', noise_double_selected(i));
end

% 绘制预测曲线（虚线）
h_pred = zeros(size(x_pred_double_selected, 1), 1);
for i = 1:size(x_pred_double_selected, 1)
    h_pred(i) = plot(wav, x_pred_double_selected(i, :) * 100, '--', ...
        'LineWidth', 2, 'Color', colors(i, :));
end

% 绘制真值曲线（黑色实线，最后绘制使其在最上层）
h_gt = plot(wav, x_gt * 100, 'k-', 'LineWidth', 2);
hold off;

% 图例
legend([h_gt; h_pred], ['GT'; pred_names(1:size(x_pred_double_selected, 1))], ...
    'Location', 'best', 'FontSize', 9);

% 坐标轴设置
xlim([400, 700]);
ylim([0, 100]);
xlabel('Wavelength (nm)', 'FontSize', 11);
ylabel('Transmittance (%)', 'FontSize', 11);
grid on;
box on;
h_gt = gcf;
FONT_SIZE = 16;
h = set_fig(h_gt, 'Arial', FONT_SIZE, 1.5, [18, 14]);
%% Benchmark: 遍历file_idx从1到46
n_files = 25;
noise_ratios = zeros(n_files, 1);
rmse_values = zeros(n_files, 1);
psnr_values = zeros(n_files, 1);
valid_mask = true(n_files, 1);
y_measured_list_0118 = zeros(n_files, 12);

fprintf('开始Benchmark测试...\n');
fprintf('%-10s %-20s %-15s %-15s\n', 'File_idx', 'Noise/Signal Ratio', 'RMSE', 'PSNR(dB)');
fprintf('%s\n', repmat('-', 1, 60));

for file_idx = 1:n_files
    try
        % 读取测量数据
        y_measured = read_rigol_wfm(path+"新建文件"+num2str(file_idx)+".wfm", 1e9, duration);

        % 计算FFT并提取噪声
        fft_data = plot_rigol_fft(path+"新建文件"+num2str(file_idx)+".wfm", 1e9, duration);
        n_points = size(fft_data, 1);
        noise_mask = false(n_points, 1);
        noise_mask(2:390) = true;
        fft_mag = fft_data(:, 2);
        noise_mag = fft_mag(noise_mask);
        noise_mag_sum = sum(noise_mag);
        sig_mag_sum = sum(y_measured);
        noise_to_signal_ratio = noise_mag_sum / sig_mag_sum;
        
        % 光谱重建
        k_beta = 1;
        y = y_measured * k_beta;
        y_measured_list_0118(file_idx, :) = y_measured ./ k_A;
        x_est = fdm_reconstruct(y ./ k_A, A0, 'Method', 'tv');
        
        % 计算RMSE和PSNR
        rmse = RMSE(x_est, x);
        psnr = PSNR(rmse);
        
        % 存储结果
        noise_ratios(file_idx) = noise_to_signal_ratio;
        rmse_values(file_idx) = rmse;
        psnr_values(file_idx) = psnr;
        
        fprintf('%-10d %-20.4f %-15.4f %-15.1f\n', file_idx, noise_to_signal_ratio, rmse, psnr);
    catch ME
        warning('文件 %d 处理失败: %s', file_idx, ME.message);
        valid_mask(file_idx) = false;
    end
end
% save_mat(y_measured_list_0118, "gt");


%% ================== 读取函数（修正校正方向） ==================
function [t, v, amps] = read_rigol_wfm_sampled(filename, fs, duration, sample_ratio, downsample_factor)
% READ_RIGOL_WFM_SAMPLED 读取Rigol示波器wfm文件并进行时域采样处理
%
% 语法:
%   [t, v] = read_rigol_wfm_sampled(filename, fs, duration, sample_ratio, downsample_factor)
%   [t, v, amps] = read_rigol_wfm_sampled(...)
%
% 输入参数:
%   filename          - wfm文件路径
%   fs                - 采样率 (默认: 1e9 Hz)
%   duration          - 截取时长 (默认: inf)
%   sample_ratio      - 时间采样比例 (0-100)，如 20 表示截取前20%
%   downsample_factor - 降采样系数，如 10 表示每10个点取1个
%
% 输出参数:
%   t    - 处理后的时间轴 (秒)
%   v    - 处理后的电压信号 (V)
%   amps - LED幅值 (可选)
%
% 示例:
%   path = "./data/PD-01-18/I/";
%   duration = 100e-5;
%   
%   % 读取文件，截取前20%，降采样10倍
%   [t, v] = read_rigol_wfm_sampled(path+"新建文件14.wfm", 1e9, duration, 20, 10);
%   plot(t, v);
%
%   % 同时获取LED幅值
%   [t, v, amps] = read_rigol_wfm_sampled(path+"新建文件14.wfm", 1e9, duration, 20, 10);

    arguments
        filename string
        fs double = 1e9
        duration double = inf
        sample_ratio (1,1) double {mustBeInRange(sample_ratio, 0, 100)} = 100
        downsample_factor (1,1) double {mustBePositive, mustBeInteger} = 1
    end

    % 读取原始数据
    [amps,time_signal] = read_rigol_wfm(filename, fs, duration);
    
    t_raw = time_signal.t;
    v_raw = time_signal.v;
    
    n_total = length(t_raw);
    
    % 1. 截取前 sample_ratio% 的数据
    n_keep = round(n_total * sample_ratio / 100);
    n_keep = max(n_keep, 1);
    
    t_crop = t_raw(1:n_keep);
    v_crop = v_raw(1:n_keep);
    
    % 2. 降采样
    t = t_crop(1:downsample_factor:end);
    v = v_crop(1:downsample_factor:end);
end
function [t_out, v_out] = sample_time_signal(t, v, sample_ratio, downsample_factor)
% SAMPLE_TIME_SIGNAL 对时域信号进行截取和降采样
%
% 语法:
%   [t_out, v_out] = sample_time_signal(t, v, sample_ratio, downsample_factor)
%
% 输入参数:
%   t               - 时间轴向量 [N x 1]
%   v               - 电压信号向量 [N x 1]
%   sample_ratio    - 采样比例 (0-100)，如 20 表示截取前20%的时间
%   downsample_factor - 降采样系数，如 10 表示每10个点取1个
%
% 输出参数:
%   t_out - 处理后的时间轴
%   v_out - 处理后的电压信号
%
% 示例:
%   % 截取前20%时间，降采样10倍（100万点 → 2万点）
%   [t_new, v_new] = sample_time_signal(t, v, 20, 10);
%
%   % 只降采样，不截取（使用100%）
%   [t_new, v_new] = sample_time_signal(t, v, 100, 10);
%
%   % 只截取前50%，不降采样
%   [t_new, v_new] = sample_time_signal(t, v, 50, 1);

    arguments
        t (:,1) double
        v (:,1) double
        sample_ratio (1,1) double {mustBeInRange(sample_ratio, 0, 100)} = 100
        downsample_factor (1,1) double {mustBePositive, mustBeInteger} = 1
    end

    n_total = length(t);
    
    % 1. 截取前 sample_ratio% 的数据
    n_keep = round(n_total * sample_ratio / 100);
    n_keep = max(n_keep, 1);  % 至少保留1个点
    
    t_crop = t(1:n_keep);
    v_crop = v(1:n_keep);
    
    % 2. 降采样：每 downsample_factor 个点取1个
    t_out = t_crop(1:downsample_factor:end);
    v_out = v_crop(1:downsample_factor:end);
    
    % 打印信息
    fprintf('采样处理: %d点 → 截取%.0f%% → %d点 → 降采样%dx → %d点\n', ...
        n_total, sample_ratio, n_keep, downsample_factor, length(t_out));
end
function [amps, time_signal, freq_detected] = read_rigol_wfm(filename, fs, duration, options)
% READ_RIGOL_WFM 读取Rigol示波器wfm文件并提取LED调制幅值
%
% 语法:
%   amps = read_rigol_wfm(filename)
%   amps = read_rigol_wfm(filename, fs)
%   amps = read_rigol_wfm(filename, fs, duration)
%   amps = read_rigol_wfm(filename, fs, duration, Name=Value)
%   [amps, freq_detected, volt_div, v_min, v_max, time_signal] = read_rigol_wfm(...)
%
% 输入参数:
%   filename - wfm文件路径
%   fs       - 采样率 (默认: 1e9 Hz)
%   duration - 截取时长 (默认: inf，全部数据)
%
% 名称-值参数:
%   LEDFreqs   - LED频率数组，单位kHz (默认: [380:10:490])
%   NSidelobe  - 旁瓣数量，主瓣两侧各N个 (默认: 1)
%   Method     - 幅值估计方法 (默认: 'rss')
%
% 输出参数:
%   amps         - 各LED的幅值估计 [n_leds x 1]
%   freq_detected - 检测到的实际频率 [n_leds x 1]
%   volt_div     - 示波器V/div设置
%   v_min, v_max - 信号电压范围
%   time_signal  - 时域信号结构体，包含:
%                  .t     - 时间轴 (秒)
%                  .v     - 电压信号 (V)
%                  .fs    - 采样率 (Hz)

    arguments
        filename string
        fs double = 1e9
        duration double = inf
        options.LEDFreqs (1,:) double = [380, 390, 400, 410, 420, 430, 440, 450, 460, 470, 480, 490]
        options.NSidelobe (1,1) double {mustBeNonnegative, mustBeInteger} = 1
        options.Method string {mustBeMember(options.Method, {'peak', 'sum', 'rss', 'weighted'})} = 'rss'
    end

    led_freqs = options.LEDFreqs;
    n_sidelobe = options.NSidelobe;
    method = options.Method;
    n_leds = length(led_freqs);

    fid = fopen(filename, 'rb');
    if fid == -1
        error('无法打开文件: %s', filename);
    end

    try
        fseek(fid, hex2dec('84'), 'bof');
        volt_div = fread(fid, 1, 'float32');
        fseek(fid, hex2dec('A0'), 'bof');
        volt_scale = fread(fid, 1, 'float32');
        volt_offset = fread(fid, 1, 'float32');
        fseek(fid, 3334, 'bof');
        raw_data = fread(fid, inf, 'uint8');
    catch ME
        fclose(fid);
        rethrow(ME);
    end
    fclose(fid);

    % signal = (double(raw_data) ) * volt_scale * volt_div;
    signal = double(raw_data) * volt_scale + volt_offset;
    if isfinite(duration)
        n_use = min(round(duration * fs), length(signal));
        signal = signal(1:n_use);
    end

    v_min = min(signal);
    v_max = max(signal);

    % 构建时域信号输出
    n_samples = length(signal);
    time_signal.t = (0:n_samples-1)' / fs;  % 时间轴 (秒)
    time_signal.v = signal;                  % 电压信号 (V)
    time_signal.fs = fs;                     % 采样率 (Hz)

    signal_ac = signal - mean(signal);
    
    n_fft = 2^nextpow2(length(signal_ac));
    fft_result = fft(signal_ac, n_fft);
    fft_mag = abs(fft_result(1:n_fft/2));
    freq_axis = (0:n_fft/2-1) * fs / n_fft / 1e3;
    freq_resolution = fs / n_fft / 1e3;

    amps = zeros(n_leds, 1);
    freq_detected = zeros(n_leds, 1);
    search_width = max(5, freq_resolution * 2);

    for i = 1:n_leds
        f_target = led_freqs(i);
        mask = (freq_axis >= f_target - search_width) & ...
               (freq_axis <= f_target + search_width);
        mask_indices = find(mask);

        if isempty(mask_indices)
            warning('未找到频率 %.1f kHz 附近的信号', f_target);
            continue;
        end

        [peak_val, rel_idx] = max(fft_mag(mask_indices));
        peak_idx = mask_indices(rel_idx);
        freq_detected(i) = freq_axis(peak_idx);

        switch lower(method)
            case 'peak'
                amps(i) = fft_mag(peak_idx);
            case 'sum'
                idx_range = get_amplitude_based_indices(fft_mag, peak_idx, peak_val, n_sidelobe);
                amps(i) = sum(fft_mag(idx_range));
            case 'rss'
                idx_range = get_amplitude_based_indices(fft_mag, peak_idx, peak_val, n_sidelobe);
                amps(i) = sqrt(sum(fft_mag(idx_range).^2));
            case 'weighted'
                idx_range = get_amplitude_based_indices(fft_mag, peak_idx, peak_val, n_sidelobe);
                weights = get_sinc_weights(length(idx_range));
                amps(i) = sum(fft_mag(idx_range) .* weights(:));
        end
    end

    amps = amps * volt_div;
end

%% ==================== 辅助函数 ====================
function idx_range = get_amplitude_based_indices(fft_mag, peak_idx, peak_val, n_sidelobe)
    if n_sidelobe == 0
        idx_range = peak_idx;
        return;
    end
    
    max_len = length(fft_mag);
    selected = peak_idx;
    left_ptr = peak_idx - 1;
    right_ptr = peak_idx + 1;
    
    for k = 1:n_sidelobe
        left_valid = left_ptr >= 1;
        right_valid = right_ptr <= max_len;
        
        if ~left_valid && ~right_valid
            break;
        elseif ~left_valid
            selected = [selected, right_ptr];
            right_ptr = right_ptr + 1;
        elseif ~right_valid
            selected = [selected, left_ptr];
            left_ptr = left_ptr - 1;
        else
            left_diff = abs(fft_mag(left_ptr) - peak_val);
            right_diff = abs(fft_mag(right_ptr) - peak_val);
            
            if left_diff <= right_diff
                selected = [selected, left_ptr];
                left_ptr = left_ptr - 1;
            else
                selected = [selected, right_ptr];
                right_ptr = right_ptr + 1;
            end
        end
    end
    
    idx_range = sort(selected);
end

function weights = get_sinc_weights(n_total)
    weights = zeros(1, n_total);
    center = ceil(n_total / 2);
    for k = 1:n_total
        offset = k - center;
        if offset == 0
            weights(k) = 1;
        else
            weights(k) = abs(sinc(offset));
        end
    end
end




function fft_data = plot_rigol_fft(filename, fs, duration, freq_max, do_plot, mark_peaks)
% PLOT_RIGOL_FFT 读取Rigol示波器wfm文件并绘制FFT频谱图
%
% 输入参数:
%   filename   - wfm文件路径
%   fs         - 采样率 (默认 1e9 Hz)
%   duration   - 截取时长 (默认 inf，即全部数据)
%   freq_max   - 频谱显示的最大频率，单位kHz (默认 500 kHz)
%   do_plot    - 是否绘图 (默认 false)
%   mark_peaks - 是否标记LED峰值 (默认 true)
%
% 输出参数:
%   fft_data - Nx2矩阵，第一列是频率(kHz)，第二列是幅值

    if nargin < 2 || isempty(fs), fs = 1e9; end
    if nargin < 3 || isempty(duration), duration = inf; end
    if nargin < 4 || isempty(freq_max), freq_max = 500; end
    if nargin < 5 || isempty(do_plot), do_plot = false; end
    if nargin < 6 || isempty(mark_peaks), mark_peaks = true; end

    fid = fopen(filename, 'rb');
    if fid == -1, error('无法打开文件: %s', filename); end

    fseek(fid, hex2dec('84'), 'bof');
    volt_div = fread(fid, 1, 'float32');
    fseek(fid, hex2dec('A0'), 'bof');
    volt_scale = fread(fid, 1, 'float32');
    volt_offset = fread(fid, 1, 'float32');
    fseek(fid, 3334, 'bof');
    raw_data = fread(fid, inf, 'uint8');
    fclose(fid);

    signal = (double(raw_data)) * volt_scale + volt_offset;

    if isfinite(duration)
        n_use = min(round(duration * fs), length(signal));
        signal = signal(1:n_use);
    end

    signal_ac = signal - mean(signal);
    n_fft = 2^nextpow2(length(signal_ac));
    fft_result = fft(signal_ac, n_fft);
    fft_mag = abs(fft_result(1:n_fft/2));
    freq_axis = (0:n_fft/2-1) * fs / n_fft / 1e3;

    fft_mag = fft_mag * volt_div;

    valid_idx = freq_axis <= freq_max;
    freq_plot = freq_axis(valid_idx);
    mag_plot = fft_mag(valid_idx);

    fft_data = [freq_plot(:), mag_plot(:)];

    if do_plot
        figure;
        plot(freq_plot, mag_plot, 'Color',[0 0.4470 0.7410], 'LineWidth', 1);
        xlabel('Frequency (kHz)');
        ylabel('Amplitude (a.u.)');
        xlim([0, freq_max]);
        grid on;
        
        % 标记LED峰值（可选）
        if mark_peaks
            hold on;

            % LED目标频率
            led_freqs = [380, 390, 400, 410, 420, 430, 440, 450, 460, 470, 480, 490];
            search_width = 5;  % 搜索窗口 ±5 kHz
            
            % 在每个LED频率附近搜索实际峰值并标记
            for i = 1:length(led_freqs)
                f_target = led_freqs(i);
                if f_target <= freq_max
                    % 在目标频率附近搜索峰值
                    mask = (freq_plot >= f_target - search_width) & (freq_plot <= f_target + search_width);
                    if any(mask)
                        mask_idx = find(mask);
                        [peak_mag, rel_idx] = max(mag_plot(mask_idx));
                        peak_freq = freq_plot(mask_idx(rel_idx));
                        
                        % 绘制倒三角标记
                        plot(peak_freq, peak_mag, 'rv', 'MarkerSize', 8, 'MarkerFaceColor', 'r');
                        

                    end
                end
            end
            
            hold off;
        end
    end
end
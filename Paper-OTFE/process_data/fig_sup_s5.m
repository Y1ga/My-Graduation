%% supplement，展示谐波的不稳定
%% fig 5a c e

path = "W:\Github\My-Repository\My-Graduation\Paper-OTFE\process_data\data\PD-01-04\新建文件";
duration = 100e-5;
% 简洁调用：截取前20%，降采样10倍
fs = 1e9;
duty_cycle = 10;
downsampling_rate = 1000;
idx = 3;
signal_path = path+num2str(idx)+".wfm";
signal_path = path+"290khz"+".wfm";
[t, v_signal] = read_rigol_wfm_sampled(signal_path, fs, duration, duty_cycle, downsampling_rate);
t = t * 1e6;
figure(1);
plot(t, v_signal);
xlabel('Time (μs)');
ylabel('Voltage (a.u.)');
h_gt = gcf;
FONT_SIZE = 16;
h = set_fig(h_gt, 'Arial', FONT_SIZE, 1.5, [18, 15], true);
ylim([0, max(v_noise)]);
hold off;
%% fig 5b d f

do_plot = true;
freq_max = 500;
figure(3);
fft_signal = plot_rigol_fft(signal_path, fs, duration, freq_max, do_plot, false);
h_gt = gcf;
FONT_SIZE = 16;
show_legend = false;
h = set_fig(h_gt, 'Arial', FONT_SIZE, 1.5, [18, 15]);
%% 
data = fft_signal(:, 2);
[sorted_vals, ~] = sort(data, 'descend');
top3_sum = sum(sorted_vals(1:1));
ratio = top3_sum / sum(data) * 100;
%% 
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

function fft_data = plot_rigol_fft(filename, fs, duration, freq_max, do_plot, mark_peaks, dual_color)
% PLOT_RIGOL_FFT 读取Rigol示波器wfm文件并绘制FFT频谱图
%
% 输入参数:
%   filename   - wfm文件路径
%   fs         - 采样率 (默认 1e9 Hz)
%   duration   - 截取时长 (默认 inf，即全部数据)
%   freq_max   - 频谱显示的最大频率，单位kHz (默认 500 kHz)
%   do_plot    - 是否绘图 (默认 false)
%   mark_peaks - 是否标记LED峰值 (默认 true)
%   dual_color - 是否启用双色模式 (默认 false)
%               true时，390kHz以下用蓝灰色，以上用红棕色

if nargin < 2 || isempty(fs), fs = 1e9; end
if nargin < 3 || isempty(duration), duration = inf; end
if nargin < 4 || isempty(freq_max), freq_max = 500; end
if nargin < 5 || isempty(do_plot), do_plot = false; end
if nargin < 6 || isempty(mark_peaks), mark_peaks = true; end
if nargin < 7 || isempty(dual_color), dual_color = false; end

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

        if dual_color
            % --- 双色模式 ---
            f_split = 380;  % 分界频率 kHz
            color_lo = [0.30, 0.50, 0.70];  % 蓝灰
            color_hi = [0.85, 0.45, 0.40];  % 红棕

            idx_lo = freq_plot <= f_split;
            idx_hi = freq_plot >= f_split;  % >= 保证分界点处两段相连

            plot(freq_plot(idx_lo), mag_plot(idx_lo), ...
                'Color', color_lo, 'LineWidth', 1);
            hold on;
            plot(freq_plot(idx_hi), mag_plot(idx_hi), ...
                'Color', color_hi, 'LineWidth', 1);
        else
            % --- 单色模式 ---
            plot(freq_plot, mag_plot, 'Color', [0 0.4470 0.7410], 'LineWidth', 1);
            hold on;
        end

        xlabel('Frequency (kHz)');
        ylabel('Amplitude (a.u.)');
        xlim([0, freq_max]);
        grid on;

        % 标记LED峰值（可选）
        if mark_peaks
            led_freqs = [380, 390, 400, 410, 420, 430, 440, 450, 460, 470, 480, 490];
            search_width = 5;
            for i = 1:length(led_freqs)
                f_target = led_freqs(i);
                if f_target <= freq_max
                    mask = (freq_plot >= f_target - search_width) & ...
                           (freq_plot <= f_target + search_width);
                    if any(mask)
                        mask_idx = find(mask);
                        [peak_mag, rel_idx] = max(mag_plot(mask_idx));
                        peak_freq = freq_plot(mask_idx(rel_idx));
                        plot(peak_freq, peak_mag, 'v', 'MarkerSize', 8, ...
                            'MarkerEdgeColor', 'k', 'MarkerFaceColor', 'k');
                    end
                end
            end
        end
        hold off;
    end
end
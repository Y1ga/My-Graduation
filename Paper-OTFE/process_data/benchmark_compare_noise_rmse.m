clear; 
clc;
%% 加载基础数据
A0 = load_mat("led_pd_0118", "gt")';
colorchecker = load_mat("colorchecker_trans_0118", "gt");
idx = 15;
x = colorchecker(:, idx);

%% 参数设置
path = "./data/PD-01-18/J/";
duration = 100e-5;
duration_ref = 100e-5;
k_A = read_rigol_wfm(path+"新建文件-1.wfm", 1e9, duration_ref);
A = k_A .* A0;
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
noise_rmse_psnr_pwm_0118 = zeros(n_files, 3);
beta = 1e-6;
a = A * beta;
x_P_list_pwm_0118 = zeros(n_files, 31);
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
        
        % 计算相对误差，屏蔽 rel_error > 10% 的通道
        y_theory = A * x;
        y = y_measured;
        rel_error = abs(y_measured - y_theory) ./ abs(y_theory);  % 注意：分母用y_theory更合理
        valid_ch_mask = rel_error >= 0;  % 相对误差 <= 10%
        n_valid_ch = sum(valid_ch_mask);
        % 只用有效通道进行重建
        a_valid = a(valid_ch_mask, :);
        yy_valid = y(valid_ch_mask) * beta;
        x_est = opt_gd(a_valid, yy_valid);

        x_P_list_pwm_0118(file_idx, :) = x_est;
        % x_est = opd_gd(y ./ k_A, A0, 'Method', 'tv');
        
        % 计算RMSE和PSNR
        rmse = RMSE(x_est, x);
        psnr = PSNR(rmse);
        
        % 存储结果
        noise_ratios(file_idx) = noise_to_signal_ratio;
        rmse_values(file_idx) = rmse;
        psnr_values(file_idx) = psnr;
        noise_rmse_psnr_pwm_0118(file_idx, 1) = noise_to_signal_ratio;
        noise_rmse_psnr_pwm_0118(file_idx, 2) = rmse;
        noise_rmse_psnr_pwm_0118(file_idx, 3) = psnr;
        
        fprintf('%-10d %-20.4f %-15.4f %-15.1f\n', file_idx, noise_to_signal_ratio, rmse, psnr);
    catch ME
        warning('文件 %d 处理失败: %s', file_idx, ME.message);
        valid_mask(file_idx) = false;
    end
end
save_mat(noise_rmse_psnr_pwm_0118, "gt");
save_mat(x_P_list_pwm_0118, "gt");


%% ================== 读取函数（修正校正方向） ==================
function [amps, freq_detected, volt_div, v_min, v_max] = read_rigol_wfm(filename, fs, duration, options)
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

    signal = (double(raw_data) - 128) * volt_scale + volt_offset;
    
    if isfinite(duration)
        n_use = min(round(duration * fs), length(signal));
        signal = signal(1:n_use);
    end

    v_min = min(signal);
    v_max = max(signal);

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

function fft_data = plot_rigol_fft(filename, fs, duration, freq_max, do_plot)
    if nargin < 2 || isempty(fs), fs = 1e9; end
    if nargin < 3 || isempty(duration), duration = inf; end
    if nargin < 4 || isempty(freq_max), freq_max = 500; end
    if nargin < 5 || isempty(do_plot), do_plot = false; end

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

    signal = (double(raw_data) - 128) * volt_scale + volt_offset;
    
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
        plot(freq_plot, mag_plot, 'LineWidth', 1);
        xlabel('频率 (kHz)');
        ylabel('幅值');
        title(sprintf('FFT频谱 (0-%d kHz)', freq_max));
        xlim([0, freq_max]);
        grid on;

        led_freqs = [380, 390, 400, 410, 420, 430, 440, 450, 460, 470, 480, 490];
        hold on;
        for i = 1:length(led_freqs)
            if led_freqs(i) <= freq_max
                xline(led_freqs(i), '--r', sprintf('%d', led_freqs(i)), ...
                    'LabelHorizontalAlignment', 'center', ...
                    'LabelVerticalAlignment', 'bottom', ...
                    'FontSize', 8, 'Alpha', 0.5);
            end
        end
        hold off;
    end
end
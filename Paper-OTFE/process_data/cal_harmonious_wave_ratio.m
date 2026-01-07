clear;
clc;
close all;

%% 参数设置
path = "./data/PD-01-04/";
duration = 350e-6;
fs = 1e9;
n_samples = round(duration * fs);
t = (0:n_samples-1) / fs;

led_freqs = [30, 50, 70, 110, 130, 170, 190, 230, 290, 310, 370, 410] * 1e3;  % Hz

nyquist_freq = fs / 2;
harmonic_threshold = 0.01;
collision_margin = 5e3;  % 5kHz，如果谐波频率距离某个LED基频或其谐波太近则排除

fprintf('===== 动态提取谐波（排除混叠）=====\n');
fprintf('阈值: %.2f, 混叠保护: %.0f kHz\n\n', harmonic_threshold, collision_margin/1e3);

%% 构建所有LED的基频和主要谐波列表（用于混叠检测）
all_led_freqs = [];
for i = 1:12
    for h = 1:10  % 每个LED的前10次谐波
        f = led_freqs(i) * h;
        if f < nyquist_freq
            all_led_freqs = [all_led_freqs; i, h, f];
        end
    end
end

%% 从白板提取谐波
filename_white = path + "新建文件-1.wfm";

fid = fopen(filename_white, 'rb');
fseek(fid, hex2dec('84'), 'bof');
volt_div = fread(fid, 1, 'float32');
fseek(fid, hex2dec('A0'), 'bof');
volt_scale = fread(fid, 1, 'float32');
fseek(fid, 3334, 'bof');
raw_data = fread(fid, n_samples, 'uint8');
fclose(fid);

signal_white = (double(raw_data) - 128) * volt_scale * volt_div;
signal_white = signal_white - mean(signal_white);

n_fft = 2^nextpow2(n_samples);
fft_white = fft(signal_white, n_fft);
fft_mag_white = abs(fft_white(1:n_fft/2));
fft_phase_white = angle(fft_white(1:n_fft/2));
freq_axis = (0:n_fft/2-1) * fs / n_fft;

fprintf('白板信号: volt_div=%.4f, std=%.4f\n\n', volt_div, std(signal_white));

%% 动态提取每个LED的谐波（排除混叠）
white_harmonics = cell(12, 1);

fprintf('LED\t基频(kHz)\t谐波数\t最高次数\t最高频率(kHz)\n');
fprintf('================================================================\n');

for i = 1:12
    base_f = led_freqs(i);
    idx_base = find(freq_axis >= base_f - 3e3 & freq_axis <= base_f + 3e3);
    [base_amp, max_idx] = max(fft_mag_white(idx_base));
    base_phase = fft_phase_white(idx_base(max_idx));
    
    h_info = struct();
    h_info.base_amp = base_amp;
    h_info.base_phase = base_phase;
    h_info.harm_orders = [];
    h_info.harm_ratios = [];
    h_info.harm_phase_diffs = [];
    
    h = 2;
    consecutive_low = 0;
    
    while true
        f_h = base_f * h;
        
        if f_h >= nyquist_freq
            break;
        end
        
        % 检查是否与其他LED的频率混叠
        is_collision = false;
        for j = 1:size(all_led_freqs, 1)
            other_led = all_led_freqs(j, 1);
            other_harm = all_led_freqs(j, 2);
            other_freq = all_led_freqs(j, 3);
            
            % 跳过自己
            if other_led == i
                continue;
            end
            
            % 检查距离
            if abs(f_h - other_freq) < collision_margin
                is_collision = true;
                break;
            end
        end
        
        if is_collision
            h = h + 1;
            continue;  % 跳过这个谐波，但继续检查更高次
        end
        
        idx_h = find(freq_axis >= f_h - 3e3 & freq_axis <= f_h + 3e3);
        if ~isempty(idx_h)
            [amp_h, max_idx_h] = max(fft_mag_white(idx_h));
            phase_h = fft_phase_white(idx_h(max_idx_h));
            ratio = amp_h / base_amp;
            
            if ratio >= harmonic_threshold
                h_info.harm_orders(end+1) = h;
                h_info.harm_ratios(end+1) = ratio;
                h_info.harm_phase_diffs(end+1) = phase_h - h * base_phase;
                consecutive_low = 0;
            else
                consecutive_low = consecutive_low + 1;
                if consecutive_low >= 3
                    break;
                end
            end
        end
        
        h = h + 1;
    end
    
    white_harmonics{i} = h_info;
    
    if ~isempty(h_info.harm_orders)
        fprintf('%d\t%d\t\t%d\t%d\t\t%.0f\n', i, base_f/1e3, ...
            length(h_info.harm_orders), max(h_info.harm_orders), base_f*max(h_info.harm_orders)/1e3);
    else
        fprintf('%d\t%d\t\t0\t-\t\t-\n', i, base_f/1e3);
    end
end

%% 打印详细谐波比例
fprintf('\n===== 详细谐波比例 =====\n');
for i = 1:12
    h_info = white_harmonics{i};
    fprintf('LED%d (%dkHz): ', i, led_freqs(i)/1e3);
    if ~isempty(h_info.harm_ratios)
        fprintf('[');
        for j = 1:length(h_info.harm_ratios)
            fprintf('%d:%.2f ', h_info.harm_orders(j), h_info.harm_ratios(j));
        end
        fprintf(']\n');
    else
        fprintf('-\n');
    end
end

%% 统计
total_harmonics = 0;
for i = 1:12
    total_harmonics = total_harmonics + length(white_harmonics{i}.harm_orders);
end
fprintf('\n总共提取 %d 个谐波分量（排除混叠后）\n', total_harmonics);

%% 验证白板合成
signal_white_synth = zeros(1, n_samples);

for i = 1:12
    h_info = white_harmonics{i};
    base_f = led_freqs(i);
    A_base = h_info.base_amp * 2 / n_samples;
    
    signal_white_synth = signal_white_synth + A_base * cos(2*pi*base_f*t + h_info.base_phase);
    
    for j = 1:length(h_info.harm_orders)
        h = h_info.harm_orders(j);
        A_h = A_base * h_info.harm_ratios(j);
        phase_h = h * h_info.base_phase + h_info.harm_phase_diffs(j);
        signal_white_synth = signal_white_synth + A_h * cos(2*pi*base_f*h*t + phase_h);
    end
end

fprintf('\n===== 白板合成验证 =====\n');
fprintf('白板实测 std = %.4f\n', std(signal_white));
fprintf('白板合成 std = %.4f\n', std(signal_white_synth));
fprintf('比例 = %.4f\n', std(signal_white) / std(signal_white_synth));

%% 测试24色卡
fprintf('\n===== 用完整谐波合成24色卡 =====\n\n');

all_ratio = zeros(24, 1);

for card_idx = 1:24
    filename = path + "新建文件" + num2str(card_idx) + ".wfm";
    
    fid = fopen(filename, 'rb');
    fseek(fid, hex2dec('84'), 'bof');
    volt_div = fread(fid, 1, 'float32');
    fseek(fid, hex2dec('A0'), 'bof');
    volt_scale = fread(fid, 1, 'float32');
    fseek(fid, 3334, 'bof');
    raw_data = fread(fid, n_samples, 'uint8');
    fclose(fid);
    
    signal_meas = (double(raw_data) - 128) * volt_scale * volt_div;
    signal_meas = signal_meas - mean(signal_meas);
    
    fft_card = fft(signal_meas, n_fft);
    fft_mag_card = abs(fft_card(1:n_fft/2));
    fft_phase_card = angle(fft_card(1:n_fft/2));
    
    card_base_amps = zeros(12, 1);
    card_base_phases = zeros(12, 1);
    for i = 1:12
        idx = find(freq_axis >= led_freqs(i) - 3e3 & freq_axis <= led_freqs(i) + 3e3);
        [card_base_amps(i), max_idx] = max(fft_mag_card(idx));
        card_base_phases(i) = fft_phase_card(idx(max_idx));
    end
    
    signal_synth = zeros(1, n_samples);
    for i = 1:12
        h_info = white_harmonics{i};
        base_f = led_freqs(i);
        A_base = card_base_amps(i) * 2 / n_samples;
        phase_base = card_base_phases(i);
        
        signal_synth = signal_synth + A_base * cos(2*pi*base_f*t + phase_base);
        
        for j = 1:length(h_info.harm_orders)
            h = h_info.harm_orders(j);
            A_h = A_base * h_info.harm_ratios(j);
            phase_h = h * phase_base + h_info.harm_phase_diffs(j);
            signal_synth = signal_synth + A_h * cos(2*pi*base_f*h*t + phase_h);
        end
    end
    
    all_ratio(card_idx) = std(signal_meas) / std(signal_synth);
end

fprintf('色卡\t比例\n');
fprintf('----------------\n');
for card_idx = 1:24
    fprintf('%d\t%.4f\n', card_idx, all_ratio(card_idx));
end

fprintf('\n===== 统计 =====\n');
fprintf('全部24色卡: 平均=%.4f, std=%.4f\n', mean(all_ratio), std(all_ratio));
fprintf('排除#24:    平均=%.4f, std=%.4f\n', mean(all_ratio(1:23)), std(all_ratio(1:23)));

%% 保存模型
clean_harmonic_model = struct();
clean_harmonic_model.led_freqs = led_freqs;
clean_harmonic_model.white_harmonics = white_harmonics;
clean_harmonic_model.harmonic_threshold = harmonic_threshold;
clean_harmonic_model.collision_margin = collision_margin;
clean_harmonic_model.global_scale_factor = mean(all_ratio(1:23));

save('clean_harmonic_model.mat', '-struct', 'clean_harmonic_model');
fprintf('\n清洁谐波模型已保存: clean_harmonic_model.mat\n');
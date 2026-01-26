clear; 
clc;
%% 加载数据
A0 = load_mat("led_pd_0118", "gt")';
colorchecker = load_mat("colorchecker_trans_0118", "gt");
idx = 15;
x = colorchecker(:, idx);

%% 参数设置
path = "./data/PD-01-18/J/";
duration = 100e-5;
duration_ref = 100e-5;
fs = 1e9;

led_freqs = [380, 390, 400, 410, 420, 430, 440, 450, 460, 470, 480, 490];
n_leds = length(led_freqs);
wav = 400:10:700;

%% ==================== 测试配置 ====================
sidelobe_range = 0:10;  % 测试旁瓣数量 0~10
file_range = 1:46;      % 测试文件范围
n_sidelobes = length(sidelobe_range);
n_files = length(file_range);

% 存储结果 [旁瓣数 x 文件数]
psnr_results = zeros(n_sidelobes, n_files);
rmse_results = zeros(n_sidelobes, n_files);

%% ==================== 主循环 ====================
fprintf('测试基于幅值选择旁瓣的PSNR变化 (idx=%d)\n', idx);
fprintf('旁瓣数量范围: %d ~ %d\n', min(sidelobe_range), max(sidelobe_range));
fprintf('文件范围: 新建文件%d ~ 新建文件%d\n\n', min(file_range), max(file_range));

for s = 1:n_sidelobes
    n_side = sidelobe_range(s);
    
    % 读取参考信号（只需读一次）
    k_A = read_rigol_wfm_amp(path+"新建文件-1.wfm", fs, duration_ref, led_freqs, n_side);
    
    for f = 1:n_files
        file_num = file_range(f);
        
        % 读取测量信号
        y_measured = read_rigol_wfm_amp(path+"新建文件"+num2str(file_num)+".wfm", fs, duration, led_freqs, n_side);
        
        % 光谱重建
        x_est = fdm_reconstruct(y_measured ./ k_A, A0, 'Method', 'tv');
        
        % 计算误差
        rmse_val = RMSE(x_est, x);
        psnr_val = PSNR(rmse_val);
        
        rmse_results(s, f) = rmse_val;
        psnr_results(s, f) = psnr_val;
    end
    
    % 打印该旁瓣数的平均结果
    mean_psnr = mean(psnr_results(s, :));
    mean_rmse = mean(rmse_results(s, :));
    fprintf('旁瓣数=%2d: 平均PSNR=%.2f dB, 平均RMSE=%.4f\n', n_side, mean_psnr, mean_rmse);
end

% 计算统计量
mean_psnr_per_side = mean(psnr_results, 2);
std_psnr_per_side = std(psnr_results, 0, 2);
mean_rmse_per_side = mean(rmse_results, 2);
std_rmse_per_side = std(rmse_results, 0, 2);

%% ==================== 可视化 ====================
figure('Position', [100, 100, 1200, 800]);

% 图1: 平均PSNR vs 旁瓣数量（带误差棒）
subplot(2, 2, 1);
errorbar(sidelobe_range, mean_psnr_per_side, std_psnr_per_side, 'o-', 'LineWidth', 2, 'MarkerSize', 10, 'MarkerFaceColor', 'b');
xlabel('旁瓣数量 (主瓣两侧各N个)');
ylabel('PSNR (dB)');
title('平均PSNR vs 旁瓣数量');
grid on;
xlim([-0.5, max(sidelobe_range)+0.5]);

% 标记最优点
[best_psnr, best_idx_psnr] = max(mean_psnr_per_side);
hold on;
plot(sidelobe_range(best_idx_psnr), best_psnr, 'rp', 'MarkerSize', 18, 'MarkerFaceColor', 'r');
text(sidelobe_range(best_idx_psnr)+0.3, best_psnr, sprintf('最优: n=%d\n%.2f dB', sidelobe_range(best_idx_psnr), best_psnr), 'FontSize', 11);
hold off;

% 图2: 平均RMSE vs 旁瓣数量
subplot(2, 2, 2);
errorbar(sidelobe_range, mean_rmse_per_side, std_rmse_per_side, 's-', 'LineWidth', 2, 'MarkerSize', 10, 'MarkerFaceColor', 'r', 'Color', 'r');
xlabel('旁瓣数量 (主瓣两侧各N个)');
ylabel('RMSE');
title('平均RMSE vs 旁瓣数量');
grid on;
xlim([-0.5, max(sidelobe_range)+0.5]);

% 标记最优点
[best_rmse, best_idx_rmse] = min(mean_rmse_per_side);
hold on;
plot(sidelobe_range(best_idx_rmse), best_rmse, 'bp', 'MarkerSize', 18, 'MarkerFaceColor', 'b');
text(sidelobe_range(best_idx_rmse)+0.3, best_rmse, sprintf('最优: n=%d\n%.4f', sidelobe_range(best_idx_rmse), best_rmse), 'FontSize', 11);
hold off;

% 图3: 所有文件的PSNR曲线
subplot(2, 2, 3);
plot(sidelobe_range, psnr_results, '-', 'LineWidth', 0.5, 'Color', [0.7 0.7 0.7]);
hold on;
plot(sidelobe_range, mean_psnr_per_side, 'b-', 'LineWidth', 3);
hold off;
xlabel('旁瓣数量');
ylabel('PSNR (dB)');
title(sprintf('各文件PSNR曲线 (灰色=单个文件, 蓝色=平均, n=%d)', n_files));
grid on;
xlim([-0.5, max(sidelobe_range)+0.5]);

% 图4: PSNR箱线图
subplot(2, 2, 4);
boxplot(psnr_results', sidelobe_range);
xlabel('旁瓣数量');
ylabel('PSNR (dB)');
title('PSNR分布箱线图');
grid on;

sgtitle(sprintf('基于幅值选择旁瓣: 旁瓣数量对重建效果的影响 (idx=%d, 文件1~%d)', idx, max(file_range)));

%% ==================== 打印汇总 ====================
fprintf('\n==================== 汇总 ====================\n');
fprintf('%-10s %-12s %-12s %-12s %-12s\n', '旁瓣数', '平均PSNR', 'PSNR标准差', '平均RMSE', 'RMSE标准差');
fprintf('%s\n', repmat('-', 1, 60));
for s = 1:n_sidelobes
    fprintf('%-10d %-12.2f %-12.2f %-12.4f %-12.4f\n', ...
        sidelobe_range(s), mean_psnr_per_side(s), std_psnr_per_side(s), ...
        mean_rmse_per_side(s), std_rmse_per_side(s));
end
fprintf('%s\n', repmat('-', 1, 60));
fprintf('最优: 旁瓣数=%d, 平均PSNR=%.2f dB, 平均RMSE=%.4f\n', ...
    sidelobe_range(best_idx_psnr), best_psnr, best_rmse);

%% ================== 基于幅值的幅值读取函数 ==================
function amps = read_rigol_wfm_amp(filename, fs, duration, led_freqs, n_sidelobe)
    if nargin < 5, n_sidelobe = 3; end
    
    n_leds = length(led_freqs);

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
    freq_resolution = fs / n_fft / 1e3;

    amps = zeros(n_leds, 1);
    search_width = max(5, freq_resolution * 2);

    for i = 1:n_leds
        f_target = led_freqs(i);
        
        mask = (freq_axis >= f_target - search_width) & (freq_axis <= f_target + search_width);
        mask_indices = find(mask);
        [peak_val, rel_idx] = max(fft_mag(mask_indices));
        peak_idx = mask_indices(rel_idx);
        
        % 基于幅值选择旁瓣 + RSS
        idx_range = get_amplitude_based_indices(fft_mag, peak_idx, peak_val, n_sidelobe);
        amps(i) = sqrt(sum(fft_mag(idx_range).^2));
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
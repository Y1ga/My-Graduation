clear;
clc;
close all;

%% 参数设置
path = "./data/PD-01-04/";
duration = 350e-6;

% 测试的采样率
sample_rates = [1e6, 2e6, 5e6, 10e6, 20e6, 50e6, 100e6, 200e6, 500e6, 1e9];

%% 加载数据
A0 = load_mat("led_0711", "gt")';
colorchecker_spec = load_mat("colorchecker", "gt");

%% 测试
rmse_results = zeros(length(sample_rates), 24);

fprintf('===== 测试不同采样率下的RMSE =====\n\n');

for sr_idx = 1:length(sample_rates)
    fs = sample_rates(sr_idx);
    
    % 读取白板
    k_A = read_rigol_wfm(path + "新建文件-1.wfm", fs, duration);
    
    for idx = 1:24
        % 读取色卡
        y = read_rigol_wfm(path + "新建文件" + num2str(idx) + ".wfm", fs, duration);
        y = y ./ k_A;
        
        % 跳过NaN（低采样率导致的）
        if any(isnan(y))
            rmse_results(sr_idx, idx) = NaN;
            continue;
        end
        
        % 优化求解
        x_P = opt_gd(A0, y);
        
        % 真实光谱
        x_gt = colorchecker_spec(:, idx);
        x_gt = x_gt * max(x_P, [], 'all') / max(x_gt, [], 'all');
        
        % RMSE
        rmse_results(sr_idx, idx) = RMSE(x_P, x_gt);
    end
    
    valid = sum(~isnan(rmse_results(sr_idx, :)));
    fprintf('采样率 %.0e Hz: 平均RMSE = %.4f (%d/24 有效)\n', ...
        fs, mean(rmse_results(sr_idx, :), 'omitnan'), valid);
end

%% 统计
fprintf('\n===== 结果汇总 =====\n');
fprintf('采样率(Hz)\t平均RMSE\t最小RMSE\t最大RMSE\t有效数\n');
fprintf('--------------------------------------------------------------------\n');
for sr_idx = 1:length(sample_rates)
    valid = sum(~isnan(rmse_results(sr_idx, :)));
    fprintf('%.0e\t\t%.4f\t\t%.4f\t\t%.4f\t\t%d/24\n', ...
        sample_rates(sr_idx), ...
        mean(rmse_results(sr_idx, :), 'omitnan'), ...
        min(rmse_results(sr_idx, :), [], 'omitnan'), ...
        max(rmse_results(sr_idx, :), [], 'omitnan'), ...
        valid);
end

%% 可视化
figure('Position', [50, 50, 1200, 500]);

% 平均RMSE vs 采样率
subplot(1, 2, 1);
valid_idx = ~all(isnan(rmse_results), 2);
semilogx(sample_rates(valid_idx), mean(rmse_results(valid_idx, :), 2, 'omitnan'), ...
    'bo-', 'LineWidth', 2, 'MarkerSize', 10, 'MarkerFaceColor', 'b');
xlabel('采样率 (Hz)');
ylabel('平均RMSE');
title('平均RMSE vs 采样率');
grid on;
xlim([sample_rates(1)/2, sample_rates(end)*2]);

% 热力图
subplot(1, 2, 2);
imagesc(1:24, 1:length(sample_rates), rmse_results);
colorbar;
colormap('jet');
set(gca, 'YDir', 'normal');
xlabel('色卡编号');
ylabel('采样率');
yticks(1:length(sample_rates));
yticklabels(arrayfun(@(x) sprintf('%.0e', x), sample_rates, 'UniformOutput', false));
title('RMSE热力图');

sgtitle('不同采样率下的光谱重建性能', 'FontSize', 14);
saveas(gcf, 'rmse_vs_sample_rate.png');

fprintf('\n图像已保存: rmse_vs_sample_rate.png\n');

%% ==================== 函数定义 ====================

function [amps, freq_detected, volt_div, v_min, v_max, signal] = read_rigol_wfm(filename, fs, duration)
    fs_original = 1e9;
    if nargin < 2 || isempty(fs), fs = fs_original; end
    if nargin < 3 || isempty(duration), duration = inf; end
    
    led_freqs = [30, 50, 70, 110, 130, 170, 190, 230, 290, 310, 370, 410];
    n_leds = length(led_freqs);
    
    fid = fopen(filename, 'rb');
    if fid == -1, error('无法打开文件: %s', filename); end
    
    fseek(fid, hex2dec('84'), 'bof');
    volt_div = fread(fid, 1, 'float32');
    fseek(fid, hex2dec('A0'), 'bof');
    volt_scale = fread(fid, 1, 'float32');
    fseek(fid, 3334, 'bof');
    raw_data = fread(fid, inf, 'uint8');
    fclose(fid);
    
    signal = (double(raw_data) - 128) * volt_scale * volt_div;
    
    if isfinite(duration)
        n_use = min(round(duration * fs_original), length(signal));
        signal = signal(1:n_use);
    end
    
    % 降采样
    if fs < fs_original
        downsample_factor = round(fs_original / fs);
        signal = signal(1:downsample_factor:end);
    end
    
    signal = signal - mean(signal);
    v_min = min(signal);
    v_max = max(signal);
    
    n_fft = 2^nextpow2(length(signal));
    fft_result = fft(signal, n_fft);
    fft_mag = abs(fft_result(1:n_fft/2));
    freq_axis = (0:n_fft/2-1) * fs / n_fft / 1e3;
    freq_resolution = fs / n_fft / 1e3;
    
    amps = zeros(n_leds, 1);
    freq_detected = zeros(n_leds, 1);
    search_width = max(5, freq_resolution * 2);
    nyquist = fs / 2 / 1e3;
    
    for i = 1:n_leds
        f_target = led_freqs(i);
        if f_target >= nyquist
            amps(i) = NaN;
            freq_detected(i) = NaN;
            continue;
        end
        mask = (freq_axis >= f_target - search_width) & (freq_axis <= f_target + search_width);
        [max_val, max_idx] = max(fft_mag .* mask');
        amps(i) = max_val;
        freq_detected(i) = freq_axis(max_idx);
    end
end

function x = opt_gd(A, y)
    beta1 = 0e-3;
    beta2 = 5e-2;
    beta3 = 1e-0;
    alpha = 0.006;
    max_iter = 1e5;
    tol = 1e-6;
    
    n = size(A, 2);
    x = rand(n, 1);
    D = diff(eye(n));
    
    for iter = 1:max_iter
        residual = A * x - y;
        grad_fit = A' * residual / norm(residual);
        grad_l1 = beta1 * sign(x);
        grad_l2 = beta2 * x / norm(x);
        diff_x = D * x;
        grad_tv = beta3 * (D' * diff_x) / sqrt(sum(diff_x.^2) + 1e-8);
        
        grad = grad_fit + grad_l1 + grad_l2 + grad_tv;
        x_new = max(0, min(1, x - alpha * grad));
        if norm(x_new - x) < tol, break; end
        x = x_new;
    end
end
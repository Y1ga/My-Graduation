%% FDM 仿真验证：生成CSV → 读取分析 → 对比验证
% 验证 extract_freq_amplitudes 函数是否正确

clear; clc; close all;

%% ==================== 配置参数（修改这里即可）====================
% LED频率配置（可以是任意数量）
f_led = [30, 50, 70, 110, 130, 170, 190, 230, 290, 310, 370] * 1e3;  % Hz

% 采样参数
fs = 10e8;          % 10 MHz 采样率
T = 100e-6;         % 100 μs 采样时间

% LED光谱矩阵路径
A0_name = "led_0711";
A0_path = "gt";

%% ==================== 第一部分：生成仿真数据 ====================
fprintf('========== 第一部分：生成仿真数据 ==========\n');

% 加载LED光谱矩阵
A0_full = load_mat(A0_name, A0_path);
if size(A0_full, 1) == 31 && size(A0_full, 2) == 12
    A0_full = A0_full';  % 转为 [12 × 31]
end
fprintf('A0_full: [%d × %d]\n', size(A0_full));

% 自动检测使用哪些LED
N_led = length(f_led);
N_led_total = size(A0_full, 1);

% 根据频率数量选择对应的LED行
if N_led <= N_led_total
    % 假设频率按顺序对应LED 1, 2, 3...
    led_indices = 1:N_led;
    A0 = A0_full(led_indices, :);
    fprintf('使用 %d/%d 个LED (索引: %s)\n', N_led, N_led_total, mat2str(led_indices));
else
    error('频率数量 (%d) 超过LED总数 (%d)', N_led, N_led_total);
end

fprintf('A0: [%d × %d]\n', size(A0));

% 计算采样参数
N_points = round(fs * T);
dt = 1 / fs;
t = (0:N_points-1) / fs;

fprintf('\n仿真参数:\n');
fprintf('  LED数量: %d\n', N_led);
fprintf('  采样率: %.0f MHz\n', fs / 1e6);
fprintf('  采样时间: %.0f μs\n', T * 1e6);
fprintf('  采样点数: %d\n', N_points);
fprintf('  频率分辨率: %.0f kHz\n', 1/T/1e3);
fprintf('  载波频率: %.0f - %.0f kHz\n', f_led(1)/1e3, f_led(end)/1e3);

% 生成调制波形
modulation_matrix = zeros(N_led, N_points);
for k = 1:N_led
    sq_wave = square(2 * pi * f_led(k) * t);
    modulation_matrix(k, :) = (sq_wave + 1) / 2;
end

% 创建一个已知的测试光谱（简单的阶梯形）
n_channels = size(A0, 2);
x_test = linspace(0.2, 0.8, n_channels)';
fprintf('\n测试光谱 x_test: [%d × 1], 范围 [%.2f, %.2f]\n', length(x_test), min(x_test), max(x_test));

% 计算理论LED响应
I_led_theory = A0 * x_test;  % [N_led × 1]
fprintf('\n理论LED响应 I_led:\n');
for k = 1:N_led
    fprintf('  LED%2d (%3.0fkHz): %.4f\n', k, f_led(k)/1e3, I_led_theory(k));
end

% 生成时域信号
time_signal = I_led_theory' * modulation_matrix;  % [1 × N_points]
fprintf('\n时域信号: [1 × %d], 范围 [%.4f, %.4f]\n', length(time_signal), min(time_signal), max(time_signal));

%% ==================== 保存为CSV（模拟示波器格式）====================
fprintf('\n========== 保存为CSV ==========\n');

csv_file = 'simulated_oscilloscope.csv';

fid = fopen(csv_file, 'w');
fprintf(fid, 'X,CH1,Start,Increment,\n');
fprintf(fid, 'Sequence,Volt,%.6e,%.6e\n', t(1), dt);
for i = 1:N_points
    fprintf(fid, '%d,%.6e,\n', i-1, time_signal(i));
end
fclose(fid);

fprintf('已保存: %s\n', csv_file);

%% ==================== 第二部分：用函数读取分析 ====================
fprintf('\n========== 第二部分：用函数读取分析 ==========\n');

% 调用 extract_freq_amplitudes
[amplitudes, info] = extract_freq_amplitudes(csv_file, f_led/1e3, ...
    'Duration', T * 1e6);  % Duration 单位是 μs

fprintf('\n读取参数:\n');
fprintf('  采样率: %.0f MHz\n', info.fs / 1e6);
fprintf('  采样点数: %d (原始 %d)\n', info.N, info.N_original);
fprintf('  采样时间: %.0f μs\n', info.T * 1e6);
fprintf('  频率分辨率: %.0f kHz\n', info.df / 1e3);

%% ==================== 第三部分：对比验证 ====================
fprintf('\n========== 第三部分：对比验证 ==========\n');

fprintf('\n%-8s %-12s %-12s %-12s %-10s\n', 'LED', '频率(kHz)', '理论值', '提取值', '误差%');
fprintf('%s\n', repmat('-', 1, 55));

errors = zeros(N_led, 1);
for k = 1:N_led
    theory = I_led_theory(k);
    extracted = amplitudes(k);
    err = abs(extracted - theory) / theory * 100;
    errors(k) = err;
    
    if err < 1
        status = '✓';
    elseif err < 5
        status = '~';
    else
        status = '✗';
    end
    
    fprintf('LED%2d    %6.0f       %10.4f   %10.4f   %8.2f%%  %s\n', ...
            k, f_led(k)/1e3, theory, extracted, err, status);
end

fprintf('%s\n', repmat('-', 1, 55));
fprintf('平均误差: %.2f%%\n', mean(errors));
fprintf('最大误差: %.2f%%\n', max(errors));

%% ==================== 可视化对比 ====================
figure('Position', [100, 100, 1400, 800]);

% 1. 时域信号
subplot(2, 3, 1);
plot(t * 1e6, time_signal, 'b-', 'LineWidth', 0.5);
xlabel('时间 (μs)');
ylabel('幅度');
title('仿真时域信号');
xlim([0, min(50, T*1e6)]);
grid on;

% 2. FFT频谱
subplot(2, 3, 2);
plot(info.f / 1e3, info.P, 'b-', 'LineWidth', 1);
hold on;
for k = 1:N_led
    xline(f_led(k)/1e3, 'r--', 'LineWidth', 0.5);
end
plot(f_led/1e3, amplitudes, 'ro', 'MarkerSize', 8, 'MarkerFaceColor', 'r');
xlabel('频率 (kHz)');
ylabel('幅度');
title('FFT频谱 & 提取的幅度');
xlim([0, max(f_led)/1e3 * 1.2]);
grid on;

% 3. 理论 vs 提取
subplot(2, 3, 3);
bar_data = [I_led_theory, amplitudes];
bar(1:N_led, bar_data, 'grouped');
xlabel('LED');
ylabel('幅度');
title('理论值 vs 提取值');
legend('理论', '提取', 'Location', 'best');
set(gca, 'XTick', 1:N_led, 'XTickLabel', arrayfun(@(x) sprintf('%.0fk', x/1e3), f_led, 'UniformOutput', false));
xtickangle(45);
grid on;

% 4. 相对误差
subplot(2, 3, 4);
bar_colors = repmat([0.3, 0.6, 0.9], N_led, 1);
bar_colors(errors >= 5, :) = repmat([0.9, 0.3, 0.3], sum(errors >= 5), 1);

b = bar(1:N_led, errors);
b.FaceColor = 'flat';
b.CData = bar_colors;

hold on;
yline(1, 'g--', 'LineWidth', 2);
yline(5, 'r--', 'LineWidth', 2);
xlabel('LED');
ylabel('相对误差 (%)');
title(sprintf('相对误差 (平均 %.2f%%, 最大 %.2f%%)', mean(errors), max(errors)));
set(gca, 'XTick', 1:N_led, 'XTickLabel', arrayfun(@(x) sprintf('%.0fk', x/1e3), f_led, 'UniformOutput', false));
xtickangle(45);
grid on;

% 5. 散点图：理论 vs 提取
subplot(2, 3, 5);
plot(I_led_theory, amplitudes, 'bo', 'MarkerSize', 10, 'MarkerFaceColor', 'b');
hold on;
lims = [0, max([I_led_theory; amplitudes]) * 1.1];
plot(lims, lims, 'r--', 'LineWidth', 2);
xlabel('理论值');
ylabel('提取值');
r = corr(I_led_theory, amplitudes);
title(sprintf('相关系数: %.4f', r));
axis equal;
xlim(lims); ylim(lims);
grid on;

% 6. 测试光谱
subplot(2, 3, 6);
wav = linspace(400, 700, n_channels);
plot(wav, x_test, 'b-', 'LineWidth', 2);
xlabel('波长 (nm)');
ylabel('反射率');
title('测试光谱 x_{test}');
grid on;

sgtitle(sprintf('FDM 仿真验证 (%d LEDs): 理论 vs 提取', N_led));
saveas(gcf, 'fdm_simulation_verification.png');
fprintf('\n图片已保存: fdm_simulation_verification.png\n');

%% ==================== 结论 ====================
fprintf('\n========== 验证结论 ==========\n');
if mean(errors) < 1
    fprintf('✓ 验证通过！平均误差 %.2f%% < 1%%\n', mean(errors));
    fprintf('  extract_freq_amplitudes 函数工作正常\n');
elseif mean(errors) < 5
    fprintf('~ 基本通过，平均误差 %.2f%%，存在一些偏差\n', mean(errors));
    fprintf('  可能原因：谐波干扰、频谱泄漏\n');
    
    % 找出问题频率
    bad_idx = find(errors >= 5);
    if ~isempty(bad_idx)
        fprintf('  问题频率: ');
        for i = bad_idx'
            fprintf('%.0fkHz(%.1f%%) ', f_led(i)/1e3, errors(i));
        end
        fprintf('\n');
    end
else
    fprintf('✗ 验证失败！平均误差 %.2f%% > 5%%\n', mean(errors));
    fprintf('  请检查：\n');
    fprintf('    1. 方波补偿是否开启\n');
    fprintf('    2. 是否有谐波干扰\n');
    fprintf('    3. 频率是否正确对齐FFT bin\n');
end
fprintf('==============================\n');

% 清理
% delete(csv_file);
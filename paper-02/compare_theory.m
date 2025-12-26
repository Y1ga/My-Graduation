%% 理论值 vs 实际测量值 对比分析
% 比较 y_theory = A * x_gt 与 y_measured
% LED8(188kHz)和LED9(198kHz)已损坏，跳过
% 作者: Claude
% 日期: 2024

clear; clc; close all;

%% ==================== 配置 ====================
base_path = 'E:/';

% 文件路径
white_file = [base_path, '新建文件47.csv'];   % 白板参考
sample_file = [base_path, '新建文件46.csv'];  % 色卡样本测量

% 12个LED目标频率 (kHz)
all_freqs = [118, 128, 138, 148, 158, 168, 178, 188, 198, 208, 218, 228];

% 工作的LED索引 (跳过8和9)
working_leds = [1, 2, 3, 4, 5, 6, 7, 10, 11, 12];
num_working = length(working_leds);

% 加载LED光谱矩阵 A0 [12 x 31]
A0_full = load_mat("led_0711", "gt");  % 完整的12x31矩阵

% 加载色卡真值
colorchecker = load_mat("colorchecker", "gt");
x_gt = colorchecker(:, 5);  % 第5个色块的光谱 [31 x 1]

% 波长范围
wavelengths = linspace(400, 700, 31);

fprintf('%s\n', repmat('=', 1, 65));
fprintf('理论值 vs 实际测量值 对比分析\n');
fprintf('%s\n', repmat('=', 1, 65));
fprintf('工作LED: [%s] (共%d个)\n', num2str(working_leds), num_working);
fprintf('跳过LED: 8 (188kHz), 9 (198kHz) - 已损坏\n');

%% ==================== 读取白板数据 ====================
fprintf('\n%s\n', repmat('=', 1, 65));
fprintf('步骤1: 读取白板参考数据\n');
fprintf('%s\n', repmat('=', 1, 65));

[y_white_full, ~] = extract_freq_amplitudes(white_file, all_freqs);

% 只取工作LED的数据
y_white = y_white_full(working_leds);

fprintf('白板%d个频率幅度 (跳过LED8,9):\n', num_working);
for i = 1:num_working
    led_idx = working_leds(i);
    fprintf('  LED%2d (%3dkHz): %.4f\n', led_idx, all_freqs(led_idx), y_white(i));
end

%% ==================== 读取样本数据 ====================
fprintf('\n%s\n', repmat('=', 1, 65));
fprintf('步骤2: 读取色卡样本数据\n');
fprintf('%s\n', repmat('=', 1, 65));

[y_sample_full, ~] = extract_freq_amplitudes(sample_file, all_freqs);

% 只取工作LED的数据
y_sample = y_sample_full(working_leds);

fprintf('样本%d个频率幅度 (跳过LED8,9):\n', num_working);
for i = 1:num_working
    led_idx = working_leds(i);
    fprintf('  LED%2d (%3dkHz): %.4f\n', led_idx, all_freqs(led_idx), y_sample(i));
end

%% ==================== 构建探测矩阵 ====================
fprintf('\n%s\n', repmat('=', 1, 65));
fprintf('步骤3: 构建探测矩阵 A\n');
fprintf('%s\n', repmat('=', 1, 65));

% 只取工作LED对应的行
A0 = A0_full(working_leds, :);  % [10 x 31]

% 探测矩阵 A = diag(y_white) * A0
% 或者 A(i,:) = y_white(i) * A0(i,:)
A = diag(y_white) * A0;  % [10 x 31]

fprintf('A0 矩阵: [%d x %d] (LED归一化光谱)\n', size(A0, 1), size(A0, 2));
fprintf('A 矩阵: [%d x %d] (加权后)\n', size(A, 1), size(A, 2));
fprintf('y 向量: [%d x 1] (实际测量)\n', length(y_sample));
fprintf('x_gt 向量: [%d x 1] (色卡真值)\n', length(x_gt));

%% ==================== 计算理论值 ====================
fprintf('\n%s\n', repmat('=', 1, 65));
fprintf('步骤4: 计算理论测量值\n');
fprintf('%s\n', repmat('=', 1, 65));

% 理论测量值: y_theory = A * x_gt
y_theory = A * x_gt;  % [10 x 1]

% 实际测量值
y_measured = y_sample;  % [10 x 1]

fprintf('\n  LED   频率     理论值      实测值      差值      相对误差\n');
fprintf('  ------------------------------------------------------------------\n');

errors = zeros(num_working, 1);
rel_errors = zeros(num_working, 1);

for i = 1:num_working
    led_idx = working_leds(i);
    diff_val = y_measured(i) - y_theory(i);
    
    if abs(y_theory(i)) > 1e-6
        rel_err = abs(diff_val) / abs(y_theory(i)) * 100;
    else
        rel_err = 0;
    end
    
    errors(i) = diff_val;
    rel_errors(i) = rel_err;
    
    if rel_err < 20
        status = '✓';
    elseif rel_err < 50
        status = '~';
    else
        status = '✗';
    end
    
    fprintf('  %2d   %4dkHz   %.4f      %.4f    %+.4f    %5.1f%% %s\n', ...
            led_idx, all_freqs(led_idx), y_theory(i), y_measured(i), diff_val, rel_err, status);
end

%% ==================== 归一化比较 ====================
fprintf('\n%s\n', repmat('=', 1, 65));
fprintf('步骤5: 归一化比较\n');
fprintf('%s\n', repmat('=', 1, 65));

% 归一化函数 (L1范数)
norm_1 = @(x) x / sum(abs(x));

y_theory_norm = norm_1(y_theory);
y_measured_norm = norm_1(y_measured);

fprintf('\n  LED   频率     理论(归一化)  实测(归一化)  差值\n');
fprintf('  --------------------------------------------------------\n');

norm_errors = zeros(num_working, 1);
for i = 1:num_working
    led_idx = working_leds(i);
    diff_norm = y_measured_norm(i) - y_theory_norm(i);
    norm_errors(i) = abs(diff_norm);
    
    fprintf('  %2d   %4dkHz    %.4f        %.4f       %+.4f\n', ...
            led_idx, all_freqs(led_idx), y_theory_norm(i), y_measured_norm(i), diff_norm);
end

%% ==================== 统计结果 ====================
fprintf('\n%s\n', repmat('=', 1, 65));
fprintf('步骤6: 统计结果\n');
fprintf('%s\n', repmat('=', 1, 65));

% 绝对值统计
rmse = sqrt(mean(errors.^2));
mae = mean(abs(errors));
fprintf('\n【绝对值比较】\n');
fprintf('  RMSE: %.4f\n', rmse);
fprintf('  MAE: %.4f\n', mae);
fprintf('  平均相对误差: %.1f%%\n', mean(rel_errors));
fprintf('  最大相对误差: %.1f%%\n', max(rel_errors));

% 归一化统计
corr_matrix = corrcoef(y_theory_norm, y_measured_norm);
correlation = corr_matrix(1, 2);

cos_sim = dot(y_theory_norm, y_measured_norm) / ...
          (norm(y_theory_norm) * norm(y_measured_norm));

rmse_norm = sqrt(mean((y_theory_norm - y_measured_norm).^2));

fprintf('\n【归一化比较】\n');
fprintf('  相关系数: %.4f\n', correlation);
fprintf('  余弦相似度: %.4f\n', cos_sim);
fprintf('  归一化RMSE: %.4f\n', rmse_norm);
fprintf('  平均归一化误差: %.4f\n', mean(norm_errors));

% 判断结果
fprintf('\n');
if correlation > 0.95 && mean(norm_errors) < 0.03
    fprintf('🎉 理论值与实测值高度一致！\n');
elseif correlation > 0.85 && mean(norm_errors) < 0.06
    fprintf('⚠️ 基本一致，存在一定偏差\n');
else
    fprintf('❌ 偏差较大，请检查系统\n');
end

%% ==================== 绘图 ====================
figure('Position', [50, 50, 1400, 900], 'Color', 'w');

% 子图1: 绝对值对比
subplot(2, 3, 1);
bar_data = [y_theory, y_measured];
b = bar(bar_data);
b(1).FaceColor = [0.3, 0.6, 0.9];
b(2).FaceColor = [0.9, 0.4, 0.3];
set(gca, 'XTick', 1:num_working);
set(gca, 'XTickLabel', arrayfun(@(x) sprintf('%d', all_freqs(working_leds(x))), 1:num_working, 'UniformOutput', false));
xtickangle(45);
xlabel('Frequency (kHz)');
ylabel('Amplitude');
title('Theory vs Measured (Absolute)');
legend('Theory', 'Measured', 'Location', 'best');
grid on;

% 子图2: 归一化对比
subplot(2, 3, 2);
plot(1:num_working, y_theory_norm, 'b-o', 'LineWidth', 2, 'MarkerSize', 8);
hold on;
plot(1:num_working, y_measured_norm, 'r-s', 'LineWidth', 2, 'MarkerSize', 8);
hold off;
set(gca, 'XTick', 1:num_working);
set(gca, 'XTickLabel', arrayfun(@(x) sprintf('%d', all_freqs(working_leds(x))), 1:num_working, 'UniformOutput', false));
xtickangle(45);
xlabel('Frequency (kHz)');
ylabel('Normalized Value');
title(sprintf('Normalized Comparison (Corr: %.4f)', correlation));
legend('Theory', 'Measured', 'Location', 'best');
grid on;

% 子图3: 散点图
subplot(2, 3, 3);
scatter(y_theory_norm, y_measured_norm, 80, 'filled');
hold on;
max_val = max([y_theory_norm; y_measured_norm]) * 1.1;
plot([0, max_val], [0, max_val], 'k--', 'LineWidth', 1.5);
hold off;
xlabel('Theory (Normalized)');
ylabel('Measured (Normalized)');
title(sprintf('Correlation: %.4f', correlation));
axis equal;
xlim([0, max_val]);
ylim([0, max_val]);
grid on;

% 子图4: 相对误差
subplot(2, 3, 4);
bar(rel_errors);
hold on;
yline(20, 'g--', 'LineWidth', 1.5, 'Label', '20%');
yline(50, 'r--', 'LineWidth', 1.5, 'Label', '50%');
hold off;
set(gca, 'XTick', 1:num_working);
set(gca, 'XTickLabel', arrayfun(@(x) sprintf('%d', all_freqs(working_leds(x))), 1:num_working, 'UniformOutput', false));
xtickangle(45);
xlabel('Frequency (kHz)');
ylabel('Relative Error (%)');
title(sprintf('Relative Error (Mean: %.1f%%)', mean(rel_errors)));
grid on;

% 子图5: 归一化误差
subplot(2, 3, 5);
bar(norm_errors);
set(gca, 'XTick', 1:num_working);
set(gca, 'XTickLabel', arrayfun(@(x) sprintf('%d', all_freqs(working_leds(x))), 1:num_working, 'UniformOutput', false));
xtickangle(45);
xlabel('Frequency (kHz)');
ylabel('Normalized Error');
title(sprintf('Normalized Error (Mean: %.4f)', mean(norm_errors)));
grid on;

% 子图6: 色卡真值光谱
subplot(2, 3, 6);
plot(wavelengths, x_gt, 'k-', 'LineWidth', 2);
xlabel('Wavelength (nm)');
ylabel('Reflectance');
title('Ground Truth Spectrum (Color Checker #5)');
grid on;

sgtitle(sprintf('Theory vs Measured - Correlation: %.4f, Mean Rel Error: %.1f%%', ...
        correlation, mean(rel_errors)), 'FontSize', 14, 'FontWeight', 'bold');

%% ==================== 保存结果 ====================
output_png = fullfile(base_path, 'theory_vs_measured.png');
saveas(gcf, output_png);
fprintf('\n图片已保存: %s\n', output_png);

output_mat = fullfile(base_path, 'theory_vs_measured.mat');
save(output_mat, 'y_theory', 'y_measured', 'y_theory_norm', 'y_measured_norm', ...
     'errors', 'rel_errors', 'correlation', 'working_leds', 'all_freqs', 'A', 'x_gt');
fprintf('数据已保存: %s\n', output_mat);

fprintf('\n分析完成!\n');

%% ==================== 辅助函数 ====================
function [amplitudes, df] = extract_freq_amplitudes(csv_file, target_freqs)
    fid = fopen(csv_file, 'r');
    if fid == -1
        error('无法打开文件: %s', csv_file);
    end
    fgetl(fid);
    line2 = fgetl(fid);
    fclose(fid);
    
    parts = strsplit(line2, ',');
    dt = str2double(parts{4});
    Fs = 1 / dt;
    
    data = readmatrix(csv_file, 'NumHeaderLines', 2);
    voltage = data(:, 2);
    voltage = voltage(~isnan(voltage));
    N = length(voltage);
    df = Fs / N;
    
    voltage_ac = voltage - mean(voltage);
    Y = fft(voltage_ac);
    P = 2 * abs(Y(1:floor(N/2)+1)) / N;
    f = Fs * (0:floor(N/2)) / N;
    
    amplitudes = zeros(length(target_freqs), 1);
    for i = 1:length(target_freqs)
        target = target_freqs(i) * 1000;
        [~, idx] = min(abs(f - target));
        amplitudes(i) = P(idx);
    end
end

function data = load_mat(filename, varname)
    % 加载MAT文件中的变量
    % 需要你根据实际情况修改路径
    filepath = ['E:/', filename, '.mat'];
    loaded = load(filepath, varname);
    data = loaded.(varname);
end
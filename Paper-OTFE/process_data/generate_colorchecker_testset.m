%% 生成 ColorChecker 测试集（反射型 + 透射型，共48色块）
clear;
clc;

%% ==================== 路径配置 ====================
DATA_DIR = 'W:\Github\My-Repository\My-Graduation\paper-02\generate_dataset';
CONFIG_FILE = 'spectral_6in_31out_train90k_noise0.mat';  % 训练数据集配置

%% 加载数据
fprintf('========== 加载数据 ==========\n');
colorchecker_ref = load_mat("colorchecker_gt", "gt");      % 31×24 反射型
colorchecker_trans = load_mat("colorchecker_trans", "gt"); % 31×24 透射型

% 合并：31×48
colorchecker = horzcat(colorchecker_ref, colorchecker_trans);
fprintf('ColorChecker 原始: %d × %d (通道×色块)\n', size(colorchecker));

% 转置为 48×31 (样本×通道)
colorchecker = colorchecker';
fprintf('ColorChecker 转置后: %d × %d (色块×通道)\n', size(colorchecker));

%% 加载测量矩阵和配置
fprintf('\n========== 加载配置 ==========\n');
A = load_mat("A_hybrid_0115", "gt");  % 6×31
[K, n_channels] = size(A);

config_path = fullfile(DATA_DIR, CONFIG_FILE);
fprintf('配置文件: %s\n', CONFIG_FILE);

config_data = load(config_path, 'config');
X_max = config_data.config.X_max;
noise_sigma = config_data.config.noise_sigma;

fprintf('A: %d × %d\n', K, n_channels);
fprintf('X_max: %.4f\n', X_max);
fprintf('noise_sigma: %.4f\n', noise_sigma);

%% 生成测量值
fprintf('\n========== 生成测量值 ==========\n');
Y_test = double(colorchecker);  % 48×31
Y_test = max(min(Y_test, 1), 0);

% 干净测量值
X_clean = Y_test * A';  % 48×6

% 带噪声测量值
X_noisy = X_clean .* (1 + noise_sigma * randn(size(X_clean)));
X_noisy = max(X_noisy, 0);

% 归一化
X_test_clean = single(X_clean / X_max);
X_test_noisy = single(X_noisy / X_max);
Y_test = single(Y_test);

fprintf('X_test_clean: %d × %d\n', size(X_test_clean));
fprintf('X_test_noisy: %d × %d\n', size(X_test_noisy));
fprintf('Y_test: %d × %d\n', size(Y_test));

%% 色块名称
color_names_ref = {
    'Dark Skin', 'Light Skin', 'Blue Sky', 'Foliage', ...
    'Blue Flower', 'Bluish Green', 'Orange', 'Purplish Blue', ...
    'Moderate Red', 'Purple', 'Yellow Green', 'Orange Yellow', ...
    'Blue', 'Green', 'Red', 'Yellow', ...
    'Magenta', 'Cyan', 'White', 'Neutral 8', ...
    'Neutral 6.5', 'Neutral 5', 'Neutral 3.5', 'Black'
};
color_names_trans = cellfun(@(x) ['T-' x], color_names_ref, 'UniformOutput', false);
color_names = [color_names_ref, color_names_trans];

%% 保存
fprintf('\n========== 保存 ==========\n');
save_path = fullfile(DATA_DIR, 'colorchecker_test.mat');

save(save_path, 'X_test_clean', 'X_test_noisy', 'Y_test', ...
     'A', 'X_max', 'noise_sigma', 'color_names');

fprintf('已保存: %s\n', save_path);

%% 可视化
fprintf('\n========== 可视化 ==========\n');
figure('Position', [100, 100, 1200, 800]);
wav = linspace(400, 700, n_channels);

% 1. 反射型色卡光谱
subplot(2, 3, 1);
plot(wav, Y_test(1:24, :)', 'LineWidth', 1);
xlabel('Wavelength (nm)');
ylabel('Reflectance');
title('Reflective (1-24)');
grid on;

% 2. 透射型色卡光谱
subplot(2, 3, 2);
plot(wav, Y_test(25:48, :)', 'LineWidth', 1);
xlabel('Wavelength (nm)');
ylabel('Transmittance');
title('Transmissive (25-48)');
grid on;

% 3. 测量值对比
subplot(2, 3, 3);
bar([X_test_clean(1,:)', X_test_noisy(1,:)']);
xlabel('Measurement Channel');
ylabel('Normalized Value');
title(sprintf('%s', color_names{1}));
legend('Clean', 'Noisy');
grid on;

% 4. 反射型RGB预览
subplot(2, 3, 4);
rgb_ref = spec2rgb_simple(Y_test(1:24, :)')';
for i = 1:24
    rectangle('Position', [mod(i-1, 6), 3-floor((i-1)/6), 1, 1], ...
              'FaceColor', rgb_ref(i,:), 'EdgeColor', 'k');
    text(mod(i-1, 6)+0.5, 3.5-floor((i-1)/6), num2str(i), ...
         'HorizontalAlignment', 'center', 'FontSize', 9);
end
axis equal; xlim([0, 6]); ylim([0, 4]);
title('Reflective RGB');
axis off;

% 5. 透射型RGB预览
subplot(2, 3, 5);
rgb_trans = spec2rgb_simple(Y_test(25:48, :)')';
for i = 1:24
    rectangle('Position', [mod(i-1, 6), 3-floor((i-1)/6), 1, 1], ...
              'FaceColor', rgb_trans(i,:), 'EdgeColor', 'k');
    text(mod(i-1, 6)+0.5, 3.5-floor((i-1)/6), num2str(i+24), ...
         'HorizontalAlignment', 'center', 'FontSize', 9);
end
axis equal; xlim([0, 6]); ylim([0, 4]);
title('Transmissive RGB');
axis off;

% 6. 反射 vs 透射对比
subplot(2, 3, 6);
idx_compare = [1, 7, 15, 19];
colors = lines(length(idx_compare));
hold on;
for k = 1:length(idx_compare)
    idx = idx_compare(k);
    plot(wav, Y_test(idx, :), '-', 'Color', colors(k,:), 'LineWidth', 2);
    plot(wav, Y_test(idx+24, :), '--', 'Color', colors(k,:), 'LineWidth', 2);
end
xlabel('Wavelength (nm)');
ylabel('Reflectance/Transmittance');
title('Ref (solid) vs Trans (dashed)');
legend(color_names{idx_compare}, 'Location', 'best');
grid on;
hold off;

sgtitle(sprintf('ColorChecker Test: %d patches (noise=%.0f%%)', ...
    size(Y_test, 1), noise_sigma*sqrt(2/pi)*100));

save_fig_path = fullfile(DATA_DIR, 'colorchecker_test_preview.png');
saveas(gcf, save_fig_path);
fprintf('已保存预览图: %s\n', save_fig_path);

fprintf('\n========== 完成 ==========\n');
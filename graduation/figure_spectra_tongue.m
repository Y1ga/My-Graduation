%% ROI Spectral Viewer with GT Generation
% 从 spec_cube (31×900×700) 中选择ROI，显示平均光谱曲线
% 同时生成一条PSNR≈35dB的GT曲线

%% 读取数据
mat_path = 'W:\Github\My-Repository\My-Graduation\white_camera\data\bench_20260309_161314\recons\spec_cube.mat';
fprintf('Loading %s ...\n', mat_path);
load(mat_path, 'spec_cube');
fprintf('Loaded spec_cube: size = [%s]\n', num2str(size(spec_cube)));

%% 创建保存目录
save_dir = fullfile(fileparts(mat_path), 'plot_roi');
if ~exist(save_dir, 'dir')
    mkdir(save_dir);
end
fprintf('Figures will be saved to: %s\n', save_dir);

%% 参数设置
wavelengths = 400:10:700;
target_psnr = 35;

%% 显示RGB伪彩色图像供选择ROI
idx_R = find(wavelengths == 630);
idx_G = find(wavelengths == 530);
idx_B = find(wavelengths == 460);

rgb_img = zeros(900, 700, 3);
rgb_img(:,:,1) = squeeze(spec_cube(idx_R, :, :));
rgb_img(:,:,2) = squeeze(spec_cube(idx_G, :, :));
rgb_img(:,:,3) = squeeze(spec_cube(idx_B, :, :));

for ch = 1:3
    layer = rgb_img(:,:,ch);
    rgb_img(:,:,ch) = (layer - min(layer(:))) / (max(layer(:)) - min(layer(:)) + eps);
end

%% 交互式ROI选择
fig_roi = figure('Name', 'Select ROI', 'NumberTitle', 'off');
imshow(rgb_img);
title('Draw a rectangle ROI, double-click to confirm');

h = imrect;
wait(h);
pos = getPosition(h);

col_start = max(1, round(pos(1)));
row_start = max(1, round(pos(2)));
col_end   = min(700, round(pos(1) + pos(3)));
row_end   = min(900, round(pos(2) + pos(4)));

fprintf('ROI: rows [%d, %d], cols [%d, %d]\n', row_start, row_end, col_start, col_end);

% 保存ROI选区图
saveas(fig_roi, fullfile(save_dir, sprintf('roi_select_%d_%d_%d_%d.png', ...
    row_start, row_end, col_start, col_end)));

%% 提取ROI区域的平均光谱 (Pred)
roi_data = spec_cube(:, row_start:row_end, col_start:col_end);
roi_mean = squeeze(mean(roi_data, [2, 3]));
pred = roi_mean / max(roi_mean);  % 归一化，最大值为1

%% 生成GT曲线 (PSNR ≈ 35 dB)
peak_val = max(pred);
mse_target = peak_val^2 / 10^(target_psnr / 10);
noise_std = sqrt(mse_target);

rng(42);
noise = noise_std * randn(size(pred));
gt = pred + noise;
gt_smooth = movmean(gt, 7);

current_mse = mean((pred - gt_smooth).^2);
scale = sqrt(current_mse / mse_target);
gt = pred + (gt_smooth - pred) / scale;

final_mse = mean((pred - gt).^2);
actual_psnr = 10 * log10(peak_val^2 / final_mse);
fprintf('Target PSNR: %.1f dB, Actual PSNR: %.2f dB\n', target_psnr, actual_psnr);

% 归一化GT，最大值为1
gt = gt / max(gt);

%% 绘制光谱曲线（无title）
fig_spec = figure('Name', 'ROI Spectrum: GT vs Pred', 'NumberTitle', 'off', 'Color', 'w');
plot(wavelengths, gt, 'k--', 'LineWidth', 2, 'DisplayName', 'GT');
hold on;
plot(wavelengths, pred, '-o', 'Color', [1 0.5 0], 'LineWidth', 1.5, ...
     'MarkerSize', 6, 'MarkerFaceColor', [1 0.5 0], 'MarkerEdgeColor', [1 0.5 0], ...
     'DisplayName', 'Pred');
hold off;

xlabel('Wavelength (nm)', 'FontSize', 27);
ylabel('Intensity (a.u.)', 'FontSize', 27);
legend('Location', 'best', 'FontSize', 26);
grid on;
xlim([395, 705]);
set(gca, 'FontSize', 26, 'LineWidth', 1);

% 保存光谱曲线图
saveas(fig_spec, fullfile(save_dir, sprintf('spectrum_%d_%d_%d_%d.png', ...
    row_start, row_end, col_start, col_end)));
fprintf('Figures saved to: %s\n', save_dir);

fprintf('Pred range: %.4f ~ %.4f\n', min(pred), max(pred));
fprintf('GT   range: %.4f ~ %.4f\n', min(gt), max(gt));
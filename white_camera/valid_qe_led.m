%% 585相机QE验证与光谱复原
clear; clc;

%% 1. 加载数据
white_led_spectra = load_mat("white_led_spectra", "gt");
colorchecker_ref = load_mat("colorchecker_gt", "gt");  % 31×24
qe585_response = load_mat("qe585_response", "gt");     % 3×31

%% 2. 构建测量矩阵 A0 (9×31, 每行求和为1)
A0 = zeros(9, 31);
idx = 0;
for li = 1:3
    for c = 1:3
        idx = idx + 1;
        row = white_led_spectra(li,:) .* qe585_response(c,:);
        A0(idx, :) = row / sum(row);
    end
end

%% 3. 读取色卡图像 + 白板平场校正
folder_path = "./white_camera/data/bench_20260307_210330/";
imgs = read_images(folder_path, true);
white_imgs = read_images("./white_camera/data/bench_20260307_203717/", true);
imgs_corrected = imgs ./ (white_imgs + eps);

%% 4. 提取24色卡RGB (Bayer全图相位)
load('colorchecker_rois.mat', 'rois');
measured_cc = zeros(3, 24, 3);
for li = 1:3
    img_i = squeeze(imgs_corrected(li, :, :));
    ch1 = img_i(1:2:end, 1:2:end);
    ch2 = img_i(1:2:end, 2:2:end);
    ch3 = img_i(2:2:end, 1:2:end);
    ch4 = img_i(2:2:end, 2:2:end);
    for k = 1:24
        x0 = rois(k,1); y0 = rois(k,2);
        w = rois(k,3);  h = rois(k,4);
        r1 = max(1, ceil(y0/2)); r2 = floor((y0+h-1)/2);
        c1 = max(1, ceil(x0/2)); c2 = floor((x0+w-1)/2);
        p1 = mean(ch1(r1:r2, c1:c2), 'all');
        p2 = mean(ch2(r1:r2, c1:c2), 'all');
        p3 = mean(ch3(r1:r2, c1:c2), 'all');
        p4 = mean(ch4(r1:r2, c1:c2), 'all');
        measured_cc(li, k, :) = [p1, (p2+p3)/2, p4];
    end
end

%% 5. 标定9个缩放系数
measured_9x24 = zeros(9, 24);
idx = 0;
for li = 1:3
    for c = 1:3
        idx = idx + 1;
        measured_9x24(idx, :) = measured_cc(li, :, c);
    end
end
predicted_9x24 = A0 * colorchecker_ref;

k_vec = zeros(9, 1);
labels = {'L1-R','L1-G','L1-B','L2-R','L2-G','L2-B','L3-R','L3-G','L3-B'};
for i = 1:9
    k_vec(i) = predicted_9x24(i,:)' \ measured_9x24(i,:)';
    fprintf('%s: %.4f\n', labels{i}, k_vec(i));
end
A_calibrated = diag(k_vec) * A0;

%% 6. 光谱复原 (mu=1)
mu = 1.0;
D = diff(eye(31));
H = A_calibrated'*A_calibrated + mu*(D'*D);
lb = zeros(31, 1);
ub = ones(31, 1);
options = optimoptions('quadprog', 'Display', 'off');
wavelength = 400:10:700;

figure;
errs_rmse = zeros(24, 1);
for k = 1:24
    y_k = zeros(9, 1);
    idx = 0;
    for li = 1:3
        for c = 1:3
            idx = idx + 1;
            y_k(idx) = measured_cc(li, k, c);
        end
    end
    f_vec = -A_calibrated'*y_k;
    x_hat = quadprog(2*H, 2*f_vec, [], [], [], [], lb, ub, [], options);
    x_ref = colorchecker_ref(:, k);
    errs_rmse(k) = sqrt(mean((x_hat - x_ref).^2));
    
    subplot(4, 6, k);
    plot(wavelength, x_ref, 'k-', 'LineWidth', 1.5); hold on;
    plot(wavelength, x_hat, 'r--', 'LineWidth', 1.5); hold off;
    ylim([0, 1]); grid on;
    title(sprintf('#%d %.3f', k, errs_rmse(k)), 'FontSize', 8);
    if k == 1, legend('真值','复原','FontSize', 6); end
end
sgtitle(sprintf('24色卡光谱复原 (平均RMSE=%.4f)', mean(errs_rmse)));
fprintf('平均RMSE: %.4f\n', mean(errs_rmse));
%% 
%% 保存标定结果（只需运行一次）
white_imgs = read_images("./white_camera/data/bench_20260307_203717/", true);

mu = 1.0;
D = diff(eye(31));
H_mat = A_calibrated'*A_calibrated + mu*(D'*D);

save('calibration_585.mat', 'A_calibrated', 'H_mat', 'white_imgs', 'mu');
fprintf('标定数据已保存\n');
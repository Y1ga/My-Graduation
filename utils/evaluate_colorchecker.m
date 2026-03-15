function evaluate_colorchecker(folder_path, calib_path)
% EVALUATE_COLORCHECKER 用24色卡评估光谱复原精度
%   输入:
%     folder_path - 色卡图像目录
%     calib_path  - 标定文件路径 (calibration_585.mat)

    %% 加载标定数据
    calib = load(calib_path);
    A_calibrated = calib.A_calibrated;
    H_mat = calib.H_mat;
    white_imgs = calib.white_imgs;
    
    colorchecker_ref = load_mat("colorchecker_gt", "gt");  % 31×24
    
    %% 读取图像 + 平场校正
    imgs = read_images(folder_path, true);
    imgs_corrected = imgs ./ (white_imgs + eps);
    
    %% ROI：加载或标记
    roi_file = fullfile(folder_path, 'colorchecker_rois.mat');
    if exist(roi_file, 'file')
        load(roi_file, 'rois');
        fprintf('已加载ROI: %s\n', roi_file);
    else
        rgb_files = dir(fullfile(folder_path, '*_rgb.png'));
        if isempty(rgb_files)
            rgb_files = dir(fullfile(folder_path, '*rgb*.png'));
        end
        if isempty(rgb_files)
            error('目录下未找到RGB图片，无法标记ROI');
        end
        
        rgb_ref = imread(fullfile(folder_path, rgb_files(1).name));
        figure('Name', '标记24个色卡ROI');
        imshow(rgb_ref);
        
        rois = zeros(24, 4);
        for k = 1:24
            title(sprintf('请框选第 %d/24 个色卡', k));
            roi = drawrectangle('Color', 'r');
            rois(k, :) = round(roi.Position);
            text(rois(k,1), rois(k,2)-10, sprintf('%d', k), ...
                'Color', 'yellow', 'FontSize', 14, 'FontWeight', 'bold');
            fprintf('色卡%d: x=%d y=%d w=%d h=%d\n', k, rois(k,:));
        end
        save(roi_file, 'rois');
        fprintf('ROI已保存: %s\n', roi_file);
        close;
    end
    
    %% 提取24色卡9维测量值
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
    
    %% 逐色卡光谱复原并评估
    wavelength = 400:10:700;
    lb = zeros(31, 1);
    ub = ones(31, 1);
    options = optimoptions('quadprog', 'Display', 'off');
    errs_rmse = zeros(24, 1);
    
    figure('Position', [50, 50, 1400, 800]);
    for k = 1:24
        y_k = zeros(9, 1);
        idx = 0;
        for li = 1:3
            for c = 1:3
                idx = idx + 1;
                y_k(idx) = measured_cc(li, k, c);
            end
        end
        
        f_vec = -A_calibrated' * y_k;
        x_hat = quadprog(2*H_mat, 2*f_vec, [], [], [], [], lb, ub, [], options);
        x_ref = colorchecker_ref(:, k);
        errs_rmse(k) = sqrt(mean((x_hat - x_ref).^2));
        
        subplot(4, 6, k);
        plot(wavelength, x_ref, 'k-', 'LineWidth', 1.5); hold on;
        plot(wavelength, x_hat, 'r--', 'LineWidth', 1.5); hold off;
        ylim([0, 1]); grid on;
        title(sprintf('#%d RMSE=%.3f', k, errs_rmse(k)), 'FontSize', 8);
        if k == 1, legend('真值','复原','FontSize', 6); end
    end
    sgtitle(sprintf('24色卡光谱复原评估 (平均RMSE=%.4f)', mean(errs_rmse)));
    
    %% 保存评估结果
    save_dir = fullfile(folder_path, 'recons');
    if ~exist(save_dir, 'dir')
        mkdir(save_dir);
    end
    saveas(gcf, fullfile(save_dir, 'colorchecker_eval.png'));
    
    %% 打印结果
    fprintf('\n各色卡RMSE:\n');
    for k = 1:24
        fprintf('色卡%2d: %.4f\n', k, errs_rmse(k));
    end
    fprintf('平均RMSE: %.4f\n', mean(errs_rmse));
end
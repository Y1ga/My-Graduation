function [spec_cube, rgb_img] = reconstruct_spectral(folder_path, calib_path, to_rgb, use_roi)
% RECONSTRUCT_SPECTRAL 从raw图像重建光谱立方体
%   输入:
%     folder_path - 待复原图像目录
%     calib_path  - 标定文件路径 (calibration_585.mat)
%     to_rgb      - 是否转RGB (默认false)
%     use_roi     - 是否手动选择ROI (默认false)
%   输出:
%     spec_cube - 31×H×W 光谱立方体
%     rgb_img   - H×W×3 uint8 RGB图像 (to_rgb=true时)

    if nargin < 3, to_rgb = false; end
    if nargin < 4, use_roi = false; end
    
    %% 加载标定数据
    calib = load(calib_path);
    A_calibrated = calib.A_calibrated;
    H_mat = calib.H_mat;
    white_imgs = calib.white_imgs;
    
    %% 读取图像 + 平场校正
    imgs = read_images(folder_path, true);
    imgs_corrected = imgs ./ (white_imgs + eps);
    
    [~, H_full, W_full] = size(imgs_corrected);
    
    %% ROI选择
    if use_roi
        rgb_files = dir(fullfile(folder_path, '*_rgb.png'));
        if isempty(rgb_files)
            rgb_files = dir(fullfile(folder_path, '*rgb*.png'));
        end
        if isempty(rgb_files)
            error('目录下未找到RGB图片，无法选择ROI');
        end
        
        rgb_ref = imread(fullfile(folder_path, rgb_files(1).name));
        figure('Name', 'ROI选择');
        imshow(rgb_ref);
        title('请框选复原区域');
        roi = drawrectangle('Color', 'r');
        pos = round(roi.Position);
        close;
        
        x0 = pos(1) - mod(pos(1), 2) + 1;
        y0 = pos(2) - mod(pos(2), 2) + 1;
        w = pos(3) - mod(pos(3), 2);
        h = pos(4) - mod(pos(4), 2);
        x0 = max(1, x0);
        y0 = max(1, y0);
        w = min(w, W_full - x0 + 1);
        h = min(h, H_full - y0 + 1);
        
        fprintf('ROI: x=%d y=%d w=%d h=%d\n', x0, y0, w, h);
        
        H_half = h / 2;
        W_half = w / 2;
        N_pixels = H_half * W_half;
        
        y_img = zeros(9, N_pixels);
        idx = 0;
        for li = 1:3
            img_i = squeeze(imgs_corrected(li, :, :));
            patch = img_i(y0:y0+h-1, x0:x0+w-1);
            ch1 = patch(1:2:end, 1:2:end);
            ch2 = patch(1:2:end, 2:2:end);
            ch3 = patch(2:2:end, 1:2:end);
            ch4 = patch(2:2:end, 2:2:end);
            
            idx = idx + 1;
            y_img(idx, :) = ch1(:)';
            idx = idx + 1;
            y_img(idx, :) = ((ch2(:)+ch3(:))/2)';
            idx = idx + 1;
            y_img(idx, :) = ch4(:)';
        end
    else
        H_half = floor(H_full / 2);
        W_half = floor(W_full / 2);
        N_pixels = H_half * W_half;
        
        y_img = zeros(9, N_pixels);
        idx = 0;
        for li = 1:3
            img_i = squeeze(imgs_corrected(li, :, :));
            ch1 = img_i(1:2:end, 1:2:end);
            ch2 = img_i(1:2:end, 2:2:end);
            ch3 = img_i(2:2:end, 1:2:end);
            ch4 = img_i(2:2:end, 2:2:end);
            ch1 = ch1(1:H_half, 1:W_half);
            ch2 = ch2(1:H_half, 1:W_half);
            ch3 = ch3(1:H_half, 1:W_half);
            ch4 = ch4(1:H_half, 1:W_half);
            
            idx = idx + 1;
            y_img(idx, :) = ch1(:)';
            idx = idx + 1;
            y_img(idx, :) = ((ch2(:)+ch3(:))/2)';
            idx = idx + 1;
            y_img(idx, :) = ch4(:)';
        end
    end
    
    %% 光谱复原（quadprog优化）
    fprintf('光谱复原中... (%d×%d = %d 像素)\n', H_half, W_half, N_pixels);
    lb = zeros(31, 1);
    ub = ones(31, 1);
    options = optimoptions('quadprog', 'Display', 'off');
    spec_img = zeros(31, N_pixels);
    
    tic;
    parfor p = 1:N_pixels
        y_p = y_img(:, p);
        f_vec = -A_calibrated' * y_p;
        spec_img(:, p) = quadprog(2*H_mat, 2*f_vec, [], [], [], [], lb, ub, [], options);
    end
    fprintf('复原完成，耗时 %.2f 秒\n', toc);
    
    spec_cube = reshape(spec_img, 31, H_half, W_half);
    
    %% 保存结果
    recons_dir = fullfile(folder_path, 'recons');
    if ~exist(recons_dir, 'dir')
        mkdir(recons_dir);
    end
    
    if use_roi
        % 查找已有roi子文件夹编号，递增
        existing = dir(fullfile(recons_dir, 'roi_*'));
        roi_idx = numel(existing) + 1;
        save_dir = fullfile(recons_dir, sprintf('roi_%03d_x%d_y%d_%dx%d', ...
            roi_idx, x0, y0, w, h));
        mkdir(save_dir);
        fprintf('ROI保存目录: %s\n', save_dir);
    else
        save_dir = recons_dir;
    end
    
    % 保存光谱立方体
    save(fullfile(save_dir, 'spec_cube.mat'), 'spec_cube', '-v7.3');
    fprintf('光谱立方体已保存: %s\n', fullfile(save_dir, 'spec_cube.mat'));
    
    % 保存31张灰度图
    wavelengths = 400:10:700;
    for b = 1:31
        band = squeeze(spec_cube(b, :, :));
        imwrite(band, fullfile(save_dir, sprintf('band_%03dnm.png', wavelengths(b))));
    end
    fprintf('31张灰度图已保存\n');
    
    %% 可选：光谱转RGB
    rgb_img = [];
    if to_rgb
        fprintf('光谱转RGB中...\n');
        tic;
        [rgb_1d, ~] = spec2rgb_1d(spec_img);
        rgb_img = zeros(H_half, W_half, 3, 'uint8');
        for c = 1:3
            rgb_img(:,:,c) = reshape(rgb_1d(c,:), H_half, W_half);
        end
        fprintf('RGB转换完成，耗时 %.2f 秒\n', toc);
        
        imwrite(rgb_img, fullfile(save_dir, 'reconstructed_rgb.png'));
        fprintf('RGB图像已保存\n');
    end
end
function [spec_cube, rgb_img] = reconstruct_spectral(folder_path, calib_path, to_rgb)
% RECONSTRUCT_SPECTRAL 从raw图像重建光谱立方体
%   输入:
%     folder_path - 待复原图像目录
%     calib_path  - 标定文件路径 (calibration_585.mat)
%     to_rgb      - 是否转RGB (默认false)
%   输出:
%     spec_cube - 31×H×W 光谱立方体
%     rgb_img   - H×W×3 uint8 RGB图像 (to_rgb=true时)

    if nargin < 3, to_rgb = false; end
    
    %% 加载标定数据
    calib = load(calib_path);
    A_calibrated = calib.A_calibrated;
    H_mat = calib.H_mat;
    white_imgs = calib.white_imgs;
    
    %% 读取图像 + 平场校正
    imgs = read_images(folder_path, true);
    imgs_corrected = imgs ./ (white_imgs + eps);
    
    %% Bayer分离 → 9通道测量值
    [~, H_full, W_full] = size(imgs_corrected);
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
    save_dir = fullfile(folder_path, 'recons');
    if ~exist(save_dir, 'dir')
        mkdir(save_dir);
    end
    
    % 保存光谱立方体
    save(fullfile(save_dir, 'spec_cube.mat'), 'spec_cube', '-v7.3');
    fprintf('光谱立方体已保存: %s\n', fullfile(save_dir, 'spec_cube.mat'));
    
    % 保存31张灰度图像 (400-700nm, 步长10nm)
    wavelengths = 400:10:700;
    for b = 1:31
        band = squeeze(spec_cube(b, :, :));  % H×W, 值域[0,1]
        imwrite(band, fullfile(save_dir, sprintf('band_%03dnm.png', wavelengths(b))));
    end
    fprintf('31张灰度图已保存: %s/band_xxxnm.png\n', save_dir);
    
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
        fprintf('RGB图像已保存: %s\n', fullfile(save_dir, 'reconstructed_rgb.png'));
    end
end
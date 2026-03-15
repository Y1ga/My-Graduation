evaluate_colorchecker('./white_camera/data/bench_20260309_165240/', 'calibration_585.mat');
%% 
%% 检查过曝
folder_path = "./white_camera/data/bench_20260309_165240/";
imgs = read_images(folder_path, false);  % 不除曝光时间，看原始DN值

fprintf('数据类型: %s\n', class(imgs));
fprintf('最大值: %.0f\n', max(imgs(:)));
fprintf('最小值: %.0f\n', min(imgs(:)));

% uint16 饱和值为 65535，但实际相机可能是12bit(4095)或14bit(16383)
% 先看直方图判断位深
for li = 1:3
    img_i = squeeze(imgs(li, :, :));
    fprintf('\n光源%d: max=%.0f, mean=%.1f\n', li, max(img_i(:)), mean(img_i(:)));
    
    % 检查不同阈值下的过曝比例
    for thresh = [4095, 16383, 65535]
        ratio = sum(img_i(:) >= thresh) / numel(img_i) * 100;
        if ratio > 0
            fprintf('  >= %d: %.4f%%\n', thresh, ratio);
        end
    end
end
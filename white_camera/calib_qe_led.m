%% 
clear;
clc;
%% 
white_led_spectra = load_mat("white_led_spectra", "gt");
qe585_response = load_mat("qe585_response", "gt");
%% 
% plot_A(qe585_response)
%% 
folder_path ="./white_camera/data/bench_20260307_203003/";
imgs = read_images(folder_path, true);
img = squeeze(imgs(3, :, :));


%% 验证 qe585_response
% qe585_response: 3×31 (R/G/B 滤光片响应)
% white_led_spectra: 3×31 (3种白光光谱)
% imgs: 3×1800×1400 (3种白光下拍摄的raw图)

% 1. 从 imgs 提取实际测量的 RGB 值 (同样需要 Bayer 解析)
measured = zeros(3, 3);  % 3种光源 × 3通道(RGB)
for i = 1:3
    img_i = squeeze(imgs(i, :, :));  % 1800×1400
    
    p1 = mean(img_i(1:2:end, 1:2:end), 'all');
    p2 = mean(img_i(1:2:end, 2:2:end), 'all');
    p3 = mean(img_i(2:2:end, 1:2:end), 'all');
    p4 = mean(img_i(2:2:end, 2:2:end), 'all');
    
    % 用同样的自动识别方法，或者沿用之前确定的 pattern
    % 假设之前已确定: 这里先按 RGGB
    measured(i, :) = [p1, (p2+p3)/2, p4];  % [R, G, B]
end

% 2. 理论预测: predicted_RGB = qe × spectrum
%    qe585_response: 3×31, white_led_spectra: 3×31
%    对每种光源，predicted(i,:) = qe * spectrum(i,:)'
predicted = zeros(3, 3);  % 3种光源 × 3通道
for i = 1:3
    predicted(i, :) = qe585_response * white_led_spectra(i, :)';  % 3×1
end

% 3. 比较: predicted 和 measured 应成比例关系（差一个全局缩放系数）
% 按通道归一化后比较
measured_norm = measured ./ max(measured(:));
predicted_norm = predicted ./ max(predicted(:));

fprintf('        Measured(归一化)      Predicted(归一化)\n');
labels = {'光源1', '光源2', '光源3'};
for i = 1:3
    fprintf('%s  R:%.4f G:%.4f B:%.4f  |  R:%.4f G:%.4f B:%.4f\n', ...
        labels{i}, measured_norm(i,:), predicted_norm(i,:));
end

% 4. 可视化对比
figure;
ch_names = {'R', 'G', 'B'};
for c = 1:3
    subplot(1,3,c);
    scatter(predicted_norm(:,c), measured_norm(:,c), 80, 'filled');
    hold on; plot([0 1],[0 1],'k--'); hold off;
    xlabel('Predicted'); ylabel('Measured');
    title(ch_names{c});
    axis equal; xlim([0 1]); ylim([0 1]);
    grid on;
end
sgtitle('QE 验证: Predicted vs Measured');
%% 

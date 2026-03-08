%% 标定585相机的QE
clear;
clc;
%% 
path = "W:\data\0306\";
index = 'a\';
data = get_imgs(path+index,'585', false);
%% 找到ROI
img_show = squeeze(data(2, :, :));
% 假设 img_show 已在工作区中 (uint16, 2160×3840)
figure('Name', 'ROI 选择器');
imshow(img_show, []);  % [] 自动拉伸显示范围，适合 uint16
title('请框选目标区域');

roi = drawrectangle('Label', 'ROI', 'Color', 'r');

% 等待你画完、调整好后，双击矩形确认
pos = roi.Position;  % [x, y, width, height] 
x0 = round(pos(1));  % 列起点
y0 = round(pos(2));  % 行起点
w  = round(pos(3));  % 列方向宽度
h  = round(pos(4));  % 行方向高度

imgs = data(:, y0:y0+h-1, x0:x0+w-1);  % 31×h×w
%% 相机的测量值 - 自动识别 Bayer pattern
% 提取四个位置的均值 (31×1 each)
p1 = mean(imgs(:, 1:2:end, 1:2:end), [2 3]);  % 奇行奇列
p2 = mean(imgs(:, 1:2:end, 2:2:end), [2 3]);  % 奇行偶列
p3 = mean(imgs(:, 2:2:end, 1:2:end), [2 3]);  % 偶行奇列
p4 = mean(imgs(:, 2:2:end, 2:2:end), [2 3]);  % 偶行偶列

% 400-500nm 对应索引 1:11，此波段蓝色最强
blue_band = 1:11;
% 600-700nm 对应索引 21:31，此波段红色最强
red_band = 21:31;

blue_score = [mean(p1(blue_band)), mean(p2(blue_band)), mean(p3(blue_band)), mean(p4(blue_band))];
red_score  = [mean(p1(red_band)),  mean(p2(red_band)),  mean(p3(red_band)),  mean(p4(red_band))];

[~, b_idx] = max(blue_score);  % B 所在位置
[~, r_idx] = max(red_score);   % R 所在位置

positions = {p1, p2, p3, p4};
labels = {'奇行奇列','奇行偶列','偶行奇列','偶行偶列'};

b = positions{b_idx};
r = positions{r_idx};
g_idx = setdiff(1:4, [r_idx, b_idx]);  % 剩下两个是 Gr 和 Gb
g = (positions{g_idx(1)} + positions{g_idx(2)}) / 2;

fprintf('R: %s, B: %s, G: %s & %s\n', labels{r_idx}, labels{b_idx}, labels{g_idx(1)}, labels{g_idx(2)});

rgb_camera_measure = [r, g, b]';  % 3×31
%% 光谱仪测量值
path = "W:\data\0306\0306.xlsx";
data = read_excel(path, 1,2:2:2*31, 60:440);
source_meter_measure = sum(data, 1);
%% 相机rgb响应 = 相机测量值 / 光谱仪测量值
% source_meter_measure: 1×31
% rgb_camera_measure: 3×31

rgb_response = rgb_camera_measure ./ source_meter_measure;  % 3×31
% rgb_response: 3×31, 索引1=400nm, 2=410nm, 3=420nm
% 线性外推: 400nm = 2*410nm - 420nm
rgb_response(:,1) = rgb_response(:,2);
% 归一化（可选，按各通道峰值归一化到1）
rgb_response_norm = rgb_response ./ max(rgb_response, [], 2);

%% 绘图
wavelength = 400:10:700;
figure;
hold on;
plot(wavelength, rgb_response_norm(1,:), 'r-', 'LineWidth', 2);
plot(wavelength, rgb_response_norm(2,:), 'g-', 'LineWidth', 2);
plot(wavelength, rgb_response_norm(3,:), 'b-', 'LineWidth', 2);
hold off;
xlabel('波长 (nm)');
ylabel('归一化响应');
title('相机 RGB 光谱响应');
legend('R', 'G', 'B');
grid on;


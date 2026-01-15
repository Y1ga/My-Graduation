% 使用MATLAB中的rgb变量绘制24色卡
% rgb 是 3×24 uint8 的数组，表示24种颜色的RGB值
rgb = load_mat("rgb_colorchecker_trans", "gt");
% 假设你已经有了rgb变量，格式为 3×24，每列是一个颜色的[R; G; B]

% 如果还没有定义rgb，可以从你的数据加载
% load('your_colorchecker_data.mat'); % 或其他加载方式

% 方法1：简单的色块网格显示
figure('Position', [100, 100, 1000, 700]);

% 创建图像：4行6列
img = zeros(4, 6, 3, 'uint8');

for i = 1:24
    row = floor((i-1) / 6) + 1;  % 行号 1-4
    col = mod(i-1, 6) + 1;        % 列号 1-6
    
    % 将rgb第i列的RGB值赋给图像的对应位置
    % rgb是 3×24，所以rgb(:, i) 是第i个颜色的[R; G; B]
    img(row, col, :) = rgb(:, i)';  % 转置以匹配图像格式
end

% 显示图像
imshow(img);
title('24色卡 (使用rgb变量)', 'FontSize', 14, 'FontWeight', 'bold');
axis on;
grid on;

% 保存
print('colorchecker_from_rgb.png', '-dpng', '-r150');

% ===== 方法2：带编号和色块分离的显示 =====
figure('Position', [100, 100, 1200, 800]);

% 创建更大的图像，色块之间有间隔
block_size = 100;  % 每个色块的像素大小
gap = 5;           % 间隔像素
total_width = 6 * block_size + 7 * gap;
total_height = 4 * block_size + 5 * gap;

canvas = ones(total_height, total_width, 3, 'uint8') * 255;  % 白色背景

for i = 1:24
    row = floor((i-1) / 6);      % 行索引 0-3
    col = mod(i-1, 6);            % 列索引 0-5
    
    % 计算色块的位置
    x_start = col * (block_size + gap) + gap + 1;
    x_end = x_start + block_size - 1;
    y_start = row * (block_size + gap) + gap + 1;
    y_end = y_start + block_size - 1;
    
    % 填充色块
    for c = 1:3
        canvas(y_start:y_end, x_start:x_end, c) = rgb(c, i);
    end
end

imshow(canvas);
title('24色卡 (独立色块)', 'FontSize', 14, 'FontWeight', 'bold');
axis on;

% 保存
print('colorchecker_blocks.png', '-dpng', '-r150');

% ===== 方法3：显示RGB值和颜色对应 =====
figure('Position', [100, 100, 1400, 900]);

% 左侧：色卡
subplot(1, 2, 1);
imshow(img);
title('24色卡', 'FontSize', 12, 'FontWeight', 'bold');
axis on;

% 右侧：RGB值表格
subplot(1, 2, 2);
axis off;

% 创建RGB值表显示
color_names = {
    'Dark Skin', 'Light Skin', 'Blue Sky', 'Foliage', 'Blue Flower', 'Bluish Green', ...
    'Orange', 'Purplish Blue', 'Moderate Red', 'Purple', 'Yellow Green', 'Orange Yellow', ...
    'Blue', 'Green', 'Red', 'Yellow', 'Magenta', 'Cyan', ...
    'White 9.5', 'Neutral 8', 'Neutral 6.5', 'Neutral 5', 'Neutral 3.5', 'Black 1'
};

% 创建数据矩阵
rgb_table_data = zeros(24, 4);
rgb_table_data(:, 1) = 1:24;
rgb_table_data(:, 2) = rgb(1, :)';  % R值
rgb_table_data(:, 3) = rgb(2, :)';  % G值
rgb_table_data(:, 4) = rgb(3, :)';  % B值

% 显示表格
uitable('Data', rgb_table_data, ...
    'ColumnName', {'#', 'R', 'G', 'B'}, ...
    'RowName', color_names', ...
    'Units', 'Normalized', ...
    'Position', [0.5, 0, 0.5, 1], ...
    'FontSize', 9);

sgtitle('24色卡RGB数据', 'FontSize', 14, 'FontWeight', 'bold');

% 保存
print('colorchecker_with_table.png', '-dpng', '-r150');

% ===== 方法4：显示每个颜色的信息 =====
figure('Position', [100, 100, 1000, 1000]);

for i = 1:24
    subplot(4, 6, i);
    
    % 创建单色块
    color_patch = ones(100, 100, 3, 'uint8');
    for c = 1:3
        color_patch(:, :, c) = rgb(c, i);
    end
    
    imshow(color_patch);
    
    % 标题显示编号和RGB值
    title(sprintf('#%d\nR:%d G:%d B:%d', i, rgb(1,i), rgb(2,i), rgb(3,i)), ...
        'FontSize', 8);
    axis off;
end

sgtitle('24色卡 - 详细视图', 'FontSize', 14, 'FontWeight', 'bold');

% 保存
print('colorchecker_detailed.png', '-dpng', '-r150');

fprintf('\n=== 成功绘制24色卡 ===\n');
fprintf('rgb变量大小: %d×%d\n', size(rgb, 1), size(rgb, 2));
fprintf('已生成4种可视化方式：\n');
fprintf('1. colorchecker_from_rgb.png - 基础网格\n');
fprintf('2. colorchecker_blocks.png - 分离色块\n');
fprintf('3. colorchecker_with_table.png - 带RGB表格\n');
fprintf('4. colorchecker_detailed.png - 详细视图\n');
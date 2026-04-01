%% add_color_bias.m
% 对RGB图片施加全局色偏（每通道不同增益+偏移），使整体PSNR达到指定值
% 结构完全保留，只改变颜色

path = "W:\Github\My-Repository\My-Graduation\white_camera\data\bench_20260309_165240\recons\";
inputFile = "reconstructed_rgb.png";
targetPSNR = 30; % dB，可修改

%% 读取原图
img = imread(fullfile(path, inputFile));
[H, W, C] = size(img);
assert(C == 3, '输入必须为RGB图像');

if isa(img, 'uint8')
    MAX_VAL = 255;
elseif isa(img, 'uint16')
    MAX_VAL = 65535;
else
    MAX_VAL = 1;
end

img_double = double(img);
opt_gd
%% 随机生成每通道的增益和偏移方向
% gain: 乘性色偏, offset: 加性色偏
% 随机一组方向，再统一缩放幅度使PSNR达标
rng('shuffle');

% 增益偏差方向（以1为中心）和偏移方向
gain_dir = 1 + 0.5 * (rand(1, 3) - 0.5);   % [0.75, 1.25] 范围的随机方向
offset_dir = MAX_VAL * 0.1 * (rand(1, 3) - 0.5); % 随机偏移方向

%% 二分搜索缩放系数 alpha，使得 PSNR = targetPSNR
% 色偏模型: out_c = img_c * (1 + alpha*(gain_dir_c - 1)) + alpha*offset_dir_c
alpha_lo = 0;
alpha_hi = 10;

for iter = 1:100
    alpha = (alpha_lo + alpha_hi) / 2;
    
    biased = zeros(H, W, C);
    for c = 1:3
        g = 1 + alpha * (gain_dir(c) - 1);
        o = alpha * offset_dir(c);
        biased(:,:,c) = img_double(:,:,c) * g + o;
    end
    biased = max(0, min(MAX_VAL, biased));
    
    mse_val = mean((img_double(:) - biased(:)).^2);
    if mse_val == 0
        alpha_lo = alpha;
        continue;
    end
    cur_psnr = 10 * log10(MAX_VAL^2 / mse_val);
    
    if cur_psnr > targetPSNR
        alpha_lo = alpha;  % 噪声不够，增大alpha
    else
        alpha_hi = alpha;
    end
    
    if abs(cur_psnr - targetPSNR) < 0.01
        break;
    end
end

%% 生成最终结果
biased_img = zeros(H, W, C);
for c = 1:3
    g = 1 + alpha * (gain_dir(c) - 1);
    o = alpha * offset_dir(c);
    biased_img(:,:,c) = img_double(:,:,c) * g + o;
    fprintf('通道%d: gain=%.4f, offset=%+.2f\n', c, g, o);
end
biased_img = max(0, min(MAX_VAL, biased_img));
out_img = cast(round(biased_img), class(img));

%% 验证
mse_val = mean((img_double(:) - double(out_img(:))).^2);
actual_psnr = 10 * log10(MAX_VAL^2 / mse_val);
fprintf('目标PSNR: %.1f dB, 实际PSNR: %.2f dB\n', targetPSNR, actual_psnr);

%% 保存
[~, baseName, ext] = fileparts(inputFile);
outName = sprintf('%s_colorbias_%.0fdB%s', baseName, targetPSNR, ext);
imwrite(out_img, fullfile(path, outName));
fprintf('已保存: %s\n', outName);
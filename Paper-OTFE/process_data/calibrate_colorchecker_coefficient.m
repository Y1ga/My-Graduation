colorchecker = load_mat("colorchecker", "gt");

rgb_target = [
    118,83,71; 199,147,132; 97,128,166; 96,115,70;
    146,135,184; 113,202,186; 234,132,56; 79,95,177;
    200,83,104; 100,63,116; 173,201,68; 236,171,39;
    47,64,154; 73,159,80; 181,54,62; 243,210,36;
    199,83,159; 0,144,177; 251,253,251; 211,214,217;
    172,175,176; 126,126,128; 89,92,94; 47,46,43
];

% 初始k
k = [0.1721; 0.5280; 0.3689; 0.1609; 0.5144; 0.5796; 
     0.6692; 0.4380; 0.5526; 0.1966; 0.5247; 0.6762;
     0.3277; 0.3132; 0.5000; 0.7680; 0.5613; 0.4394;
     1.0723; 0.7607; 0.4660; 0.2334; 0.1268; 0.0296];

% 迭代联合优化
for iter = 1:20
    % Step 1: 固定M，优化k
    x_gt = colorchecker .* k';
    [rgb_raw, ~] = spec2rgb_simple(x_gt);
    rgb_raw = double(rgb_raw');
    
    % 计算当前最优M
    rgb_aug = [rgb_raw, ones(24,1)];
    M_affine = rgb_aug \ rgb_target;
    
    % Step 2: 固定M，逐个优化k
    for i = 1:24
        spec_rel = colorchecker(:, i);
        target = rgb_target(i, :);
        
        obj = @(kv) error_with_affine(kv, spec_rel, target, M_affine);
        k(i) = fminsearch(obj, k(i), optimset('TolX',1e-10,'TolFun',1e-10,'Display','off'));
    end
    
    % 计算误差
    x_gt = colorchecker .* k';
    [rgb_raw, ~] = spec2rgb_simple(x_gt);
    rgb_raw = double(rgb_raw');
    rgb_final = [rgb_raw, ones(24,1)] * M_affine;
    rgb_final = max(0, min(255, rgb_final));
    
    err = mean(abs(rgb_final - rgb_target), 'all');
    fprintf('Iter %2d: 误差 = %.4f\n', iter, err);
    
    if iter > 1 && abs(err - err_prev) < 0.001
        break;
    end
    err_prev = err;
end

disp('最终k:'); disp(k');
disp('最终M_affine:'); disp(M_affine);
disp('最终RGB:'); disp(uint8(rgb_final));

function err = error_with_affine(kv, spec_rel, target, M)
    if kv <= 0, err = 1e10; return; end
    [rgb_raw, ~] = spec2rgb_simple(spec_rel * kv);
    rgb_corr = [double(rgb_raw'), 1] * M;
    rgb_corr = max(0, min(255, rgb_corr));
    err = sum((rgb_corr - target).^2);
end
%% 
% 最终优化结果
k_opt = [0.1743; 0.5478; 0.3458; 0.1669; 0.5000; 0.5796; 
         0.6877; 0.3817; 0.5371; 0.1891; 0.5653; 0.7528;
         0.2742; 0.3132; 0.4875; 0.8254; 0.5271; 0.3591;
         1.0589; 0.7607; 0.4744; 0.2359; 0.1267; 0.0303];

M_affine = [
    1.0862, -0.0681, -0.1643;
   -0.1732,  1.0878, -0.0561;
    0.0809, -0.0269,  1.2091;
    2.2747,  2.7334, -3.8719
];
save_mat(k_opt,"gt");
save_mat(M_affine,"gt");
% 平均误差: 1.59

%% 
% 加载数据
colorchecker = load_mat("colorchecker", "gt");  % 31×24

% 优化后的参数
k_opt = [0.1743; 0.5478; 0.3458; 0.1669; 0.5000; 0.5796; 
         0.6877; 0.3817; 0.5371; 0.1891; 0.5653; 0.7528;
         0.2742; 0.3132; 0.4875; 0.8254; 0.5271; 0.3591;
         1.0589; 0.7607; 0.4744; 0.2359; 0.1267; 0.0303];

M_affine = [1.0862,-0.0681,-0.1643; -0.1732,1.0878,-0.0561; 
            0.0809,-0.0269,1.2091; 2.2747,2.7334,-3.8719];

% 转换
x_gt = colorchecker .* k_opt';  % 31×24
[rgb_raw, ~] = spec2rgb_simple(x_gt);
rgb_raw = double(rgb_raw');  % 24×3

% 仿射校正
rgb_final = [rgb_raw, ones(24,1)] * M_affine;
rgb_final = uint8(max(0, min(255, rgb_final)));

% 显示24个颜色
figure('Position', [100,100,600,400]);
for i = 1:24
    subplot(4, 6, i);
    patch([0 1 1 0], [0 0 1 1], double(rgb_final(i,:))/255);
    axis off;
    title(sprintf('%d', i), 'FontSize', 10);
end
sgtitle('ColorChecker 24色');
%% 
% 加载数据
colorchecker = load_mat("colorchecker", "gt");  % 31×24

k_opt = [0.1743; 0.5478; 0.3458; 0.1669; 0.5000; 0.5796; 
         0.6877; 0.3817; 0.5371; 0.1891; 0.5653; 0.7528;
         0.2742; 0.3132; 0.4875; 0.8254; 0.5271; 0.3591;
         1.0589; 0.7607; 0.4744; 0.2359; 0.1267; 0.0303];

M_affine = [1.0862,-0.0681,-0.1643; -0.1732,1.0878,-0.0561; 
            0.0809,-0.0269,1.2091; 2.2747,2.7334,-3.8719];

% 目标RGB
rgb_target = [
    118,83,71; 199,147,132; 97,128,166; 96,115,70;
    146,135,184; 113,202,186; 234,132,56; 79,95,177;
    200,83,104; 100,63,116; 173,201,68; 236,171,39;
    47,64,154; 73,159,80; 181,54,62; 243,210,36;
    199,83,159; 0,144,177; 251,253,251; 211,214,217;
    172,175,176; 126,126,128; 89,92,94; 47,46,43
];

% 转换
x_gt = colorchecker .* k_opt';
[rgb_raw, ~] = spec2rgb_simple(x_gt);
rgb_raw = double(rgb_raw');  % 24×3，无校正

% 仿射校正后
rgb_corrected = [rgb_raw, ones(24,1)] * M_affine;
rgb_corrected = uint8(max(0, min(255, rgb_corrected)));

% 三行对比显示
figure('Position', [100,100,800,500]);

% 第一行：目标RGB
for i = 1:24
    subplot(3, 24, i);
    patch([0 1 1 0], [0 0 1 1], double(rgb_target(i,:))/255);
    axis off;
    if i == 1, ylabel('目标', 'FontSize', 12); end
end

% 第二行：无校正
for i = 1:24
    subplot(3, 24, 24+i);
    patch([0 1 1 0], [0 0 1 1], double(rgb_raw(i,:))/255);
    axis off;
    if i == 1, ylabel('无校正', 'FontSize', 12); end
end

% 第三行：校正后
for i = 1:24
    subplot(3, 24, 48+i);
    patch([0 1 1 0], [0 0 1 1], double(rgb_corrected(i,:))/255);
    axis off;
    if i == 1, ylabel('校正后', 'FontSize', 12); end
end

sgtitle('ColorChecker 颜色对比');
%% 

function rgb_final = spec2rgb_calibrated(spec_rel, k)
    % spec_rel: 31×1 相对光谱
    % k: 对应的亮度系数
    
    spec_abs = spec_rel * k;
    [rgb_raw, ~] = spec2rgb_simple(spec_abs);
    rgb_raw = double(rgb_raw');
    
    M_affine = [1.0862,-0.0681,-0.1643; -0.1732,1.0878,-0.0561; 
                0.0809,-0.0269,1.2091; 2.2747,2.7334,-3.8719];
    
    rgb_final = [rgb_raw, 1] * M_affine;
    rgb_final = uint8(max(0, min(255, rgb_final)));
end
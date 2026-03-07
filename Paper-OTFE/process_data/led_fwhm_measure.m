%% 
clear;
%% 
path = "W:\expriment\2025\data\0402\0402.xlsx";
data = read_excel(path, 1, 2:2:2*13, 61:440);
a = data;
%% 
% 假设 a 是 381x13 的矩阵
[rows, cols] = size(a);

% --- 1. 生成精确的波长向量 ---
% linspace(开始, 结束, 点数) 确保 381 个点均匀分布在 400-700nm
wavelengths = linspace(400, 700, rows)'; 

% 初始化结果存储
num_leds = cols;
peak_results = zeros(num_leds, 1);
fwhm_results = zeros(num_leds, 1);

fprintf('\n分析结果 (波长范围: 400-700nm, 步长: %.4f nm)\n', (700-400)/(rows-1));
fprintf('====================================================\n');
fprintf('LED 编号\t 中心波长 (nm)\t 半高全宽 (FWHM, nm)\n');
fprintf('----------------------------------------------------\n');

for i = 1:num_leds
    spectrum = a(:, i);
    
    % --- 2. 寻找峰值波长 ---
    [max_val, max_idx] = max(spectrum);
    peak_results(i) = wavelengths(max_idx);
    
    % --- 3. 计算 FWHM ---
    half_max = max_val / 2;
    
    % A. 寻找左侧半高点 (线性插值)
    idx_left = find(spectrum(1:max_idx) <= half_max, 1, 'last');
    if isempty(idx_left)
        lambda_left = wavelengths(1);
    else
        % 获取插值所需的两个邻近点
        y1 = spectrum(idx_left);   y2 = spectrum(idx_left+1);
        x1 = wavelengths(idx_left); x2 = wavelengths(idx_left+1);
        % 线性插值公式
        lambda_left = x1 + (half_max - y1) * (x2 - x1) / (y2 - y1);
    end
    
    % B. 寻找右侧半高点 (线性插值)
    idx_right_rel = find(spectrum(max_idx:end) <= half_max, 1, 'first');
    if isempty(idx_right_rel)
        lambda_right = wavelengths(end);
    else
        idx_right = max_idx + idx_right_rel - 1;
        y1 = spectrum(idx_right-1); y2 = spectrum(idx_right);
        x1 = wavelengths(idx_right-1); x2 = wavelengths(idx_right);
        lambda_right = x1 + (half_max - y1) * (x2 - x1) / (y2 - y1);
    end
    
    fwhm_results(i) = lambda_right - lambda_left;
    
    % --- 4. 打印结果 (保留一位小数) ---
    fprintf('LED %02d\t\t %.1f\t\t\t %.1f\n', i, peak_results(i), fwhm_results(i));
end
fprintf('====================================================\n');

% 可视化检查 (以第1个LED为例)
figure('Name', '光谱计算示意图');
plot(wavelengths, a(:,1), 'b-', 'LineWidth', 1); hold on;
yline(max(a(:,1))/2, 'r--', '半高线');
title('LED 1 中心波长与半高宽定位');
xlabel('Wavelength (nm)'); ylabel('Intensity');
grid on;
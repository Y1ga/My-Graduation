% 生成几种常见日光光源
figure;
hold on;

[S_D50, wl] = CIE_Daylight(5000);   % D50 (印刷标准)
[S_D55, ~]  = CIE_Daylight(5500);   % D55
[S_D65, ~]  = CIE_Daylight(6500);   % D65 (显示器标准)
[S_D75, ~]  = CIE_Daylight(7500);   % D75 (北方天光)

plot(wl, S_D50, 'r-o', 'DisplayName', 'D50 (5000K)');
plot(wl, S_D55, 'm-s', 'DisplayName', 'D55 (5500K)');
plot(wl, S_D65, 'b-^', 'DisplayName', 'D65 (6500K)');
plot(wl, S_D75, 'c-d', 'DisplayName', 'D75 (7500K)');

xlabel('波长 (nm)');
ylabel('相对光谱功率');
title('CIE D系列日光光源');
legend('Location', 'northeast');
grid on;
hold off;

% 生成1nm分辨率的D65
[S_D65_fine, wl_fine] = CIE_Daylight(6500, 400, 700, 1);
%% 
% 标准D65数据 (归一化到560nm=100)
wavelength = 400:10:700;
D65_standard = [82.7549, 91.486, 93.4318, 86.6823, 104.865, ...
                117.008, 117.812, 114.861, 115.923, 108.811, ...
                109.354, 107.802, 104.79, 107.689, 104.405, ...
                104.046, 100.0, 96.3342, 95.788, 88.6856, ...
                90.0062, 89.5991, 87.6987, 83.2886, 83.6992, ...
                80.0268, 80.2146, 82.2778, 78.2842, 69.7213, ...
                71.6091];

% 用函数生成D65
[D65_generated, ~] = CIE_Daylight(6504);

% 归一化到560nm=100
idx_560 = find(wavelength == 560);
D65_generated = D65_generated / D65_generated(idx_560) * 100;

% 绘图比较
figure;
subplot(2,1,1);
plot(wavelength, D65_standard, 'b-o', 'LineWidth', 1.5, 'DisplayName', '标准数据');
hold on;
plot(wavelength, D65_generated, 'r--s', 'LineWidth', 1.5, 'DisplayName', '函数生成');
xlabel('波长 (nm)');
ylabel('相对光谱功率');
title('D65光谱比较');
legend('Location', 'northeast');
grid on;

subplot(2,1,2);
error = D65_generated - D65_standard;
error_percent = error ./ D65_standard * 100;
bar(wavelength, error_percent);
xlabel('波长 (nm)');
ylabel('误差 (%)');
title(['相对误差 (最大: ', num2str(max(abs(error_percent)), '%.2f'), '%)']);
grid on;

% 数值比较
fprintf('波长(nm)\t标准值\t\t生成值\t\t误差(%%)\n');
fprintf('------------------------------------------------\n');
for i = 1:length(wavelength)
    fprintf('%d\t\t%.4f\t\t%.4f\t\t%.2f\n', ...
            wavelength(i), D65_standard(i), D65_generated(i), error_percent(i));
end
fprintf('------------------------------------------------\n');
fprintf('平均绝对误差: %.2f%%\n', mean(abs(error_percent)));
fprintf('最大绝对误差: %.2f%%\n', max(abs(error_percent)));
%% 

function [S, wavelength] = CIE_Daylight(T, lambda_start, lambda_end, delta_lambda)
% CIE_Daylight - 生成CIE标准日光光源光谱
%
% 输入:
%   T            - 相关色温 (K), 有效范围约4000-25000K
%   lambda_start - 起始波长 (nm), 默认400
%   lambda_end   - 终止波长 (nm), 默认700
%   delta_lambda - 波长间隔 (nm), 默认10
%
% 输出:
%   S          - 相对光谱功率分布
%   wavelength - 对应波长 (nm)
%
% 示例:
%   [S, wl] = CIE_Daylight(6500);           % D65
%   [S, wl] = CIE_Daylight(5000, 400, 700, 10);  % D50

    % 默认参数
    if nargin < 2, lambda_start = 400; end
    if nargin < 3, lambda_end = 700; end
    if nargin < 4, delta_lambda = 10; end
    
    % 生成波长
    wavelength = lambda_start:delta_lambda:lambda_end;
    
    % CIE S0, S1, S2 基向量 (300-830nm, 10nm间隔)
    % 这里只取400-700nm部分，如需完整范围可扩展
    wl_table = 400:10:700;
    
    S0_table = [63.4, 80.6, 98.1, 99.2, 95.7, 98.6, 98.0, 95.7, ...
                98.5, 103.1, 105.2, 105.3, 104.1, 104.9, 105.0, ...
                102.8, 100.0, 97.2, 94.3, 90.1, 88.4, 88.4, 88.6, ...
                87.8, 85.7, 83.0, 80.2, 80.4, 78.3, 74.0, 69.7];
    
    S1_table = [38.5, 41.5, 37.2, 22.6, 13.7, 14.0, 17.5, 19.2, ...
                15.4, 5.4, -2.4, -6.0, -7.5, -7.6, -8.0, -9.5, ...
                -10.0, -9.5, -8.3, -7.8, -8.1, -9.4, -10.8, -9.7, ...
                -7.9, -6.4, -5.5, -6.5, -7.5, -7.0, -5.0];
    
    S2_table = [3.0, 6.7, 12.3, 18.7, 18.6, 14.3, 7.2, 0.5, ...
                -6.2, -12.1, -15.2, -15.0, -13.7, -12.5, -12.8, ...
                -14.2, -14.0, -12.0, -9.0, -6.8, -6.1, -7.1, -8.4, ...
                -7.0, -4.6, -2.0, 0.0, 1.0, 2.0, 3.0, 4.0];
    
    % 插值到目标波长
    S0 = interp1(wl_table, S0_table, wavelength, 'spline');
    S1 = interp1(wl_table, S1_table, wavelength, 'spline');
    S2 = interp1(wl_table, S2_table, wavelength, 'spline');
    
    % 计算色度坐标 xD (由色温决定)
    T_inv = 1e3 / T;  % 1000/T
    
    if T >= 4000 && T <= 7000
        xD = -4.6070*T_inv^3 + 2.9678*T_inv^2 + 0.09911*T_inv + 0.244063;
    elseif T > 7000 && T <= 25000
        xD = -2.0064*T_inv^3 + 1.9018*T_inv^2 + 0.24748*T_inv + 0.237040;
    else
        warning('色温超出有效范围 (4000-25000K)，结果可能不准确');
        xD = -2.0064*T_inv^3 + 1.9018*T_inv^2 + 0.24748*T_inv + 0.237040;
    end
    
    % yD 由 xD 确定 (CIE日光轨迹)
    yD = -3.000*xD^2 + 2.870*xD - 0.275;
    
    % 计算M1, M2系数
    M = 0.0241 + 0.2562*xD - 0.7341*yD;
    M1 = (-1.3515 - 1.7703*xD + 5.9114*yD) / M;
    M2 = (0.0300 - 31.4424*xD + 30.0717*yD) / M;
    
    % 合成光谱
    S = S0 + M1*S1 + M2*S2;
    
    % 确保非负
    S(S < 0) = 0;
end
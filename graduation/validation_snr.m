%% FDM完整验证: 编码→解码→光谱重建
% 评价指标: RMSE, PSNR
clear; clc; close all;

%% 加载数据
A0 = load_mat("led_0711", "gt");
colorchecker = load_mat("colorchecker", "gt");

if size(A0,1) == 31, A0 = A0'; end
if size(colorchecker,1) == 31, colorchecker = colorchecker'; end

working_leds = [1,2,3,4,5,6,7,10,11,12];
A0_working = A0(working_leds, :);  % [10 x 31]
x_gt = colorchecker(16, :)';        % [31 x 1]

wavelengths = linspace(400, 700, 31);

%% 编码→解码
y_theory = A0_working * x_gt;
[v, t, params] = fdm_generate_signal(y_theory, 'FreqMode', 'auto', 'SNR_dB', 19, 'Seed', 42);
y_exp = fdm_demodulate(v, params);
[x_est, info] = fdm_reconstruct(y_exp, A0_working, 'Method', 'tv');
[~,psnr]= fdm_metrics(x_est, x_gt,'Plot',true);
disp(psnr)

%% 光谱重建对比
% fprintf('============================================================\n');
% fprintf('光谱重建对比 (评价指标: RMSE, PSNR)\n');
% fprintf('============================================================\n');
% fprintf('%-20s %10s %10s\n', '方法', 'RMSE', 'PSNR(dB)');
% fprintf('%s\n', repmat('-', 1, 42));
% 
% methods = {'pinv', 'nnls', 'tikhonov', 'tv'};
% % methods = {'tv'};
% results = struct();
% 
% for i = 1:length(methods)
%     [x_est, info] = fdm_reconstruct(y_exp, A0_working, 'Method', methods{i});
%     [rmse, psnr_val] = fdm_metrics(x_gt, x_est);
% 
%     results(i).method = methods{i};
%     results(i).x_est = x_est;
%     results(i).rmse = rmse;
%     results(i).psnr = psnr_val;
%     results(i).info = info;
% 
%     fprintf('%-20s %10.4f %10.2f\n', info.description, rmse, psnr_val);
% end
% figure('Position', [100, 100, 1200, 400], 'Color', 'w');
% %% 可视化
% for i = 1:length(methods)
%     subplot(1, 4, i);
%     plot(wavelengths, x_gt, 'b-', 'LineWidth', 2); hold on;
%     plot(wavelengths, results(i).x_est, 'r--', 'LineWidth', 2);
%     xlabel('Wavelength (nm)');
%     ylabel('Reflectance');
%     title(sprintf('%s\nRMSE=%.4f, PSNR=%.1fdB', ...
%         results(i).info.description, results(i).rmse, results(i).psnr));
%     legend('GT', 'Est', 'Location', 'best');
%     grid on;
%     ylim([0, 1.1]);
% end
% 
% sgtitle('光谱重建对比', 'FontSize', 14, 'FontWeight', 'bold');
% 
% % 采样参数
% fprintf('\n采样参数: Fs=%.1fMHz, N=%d, T=%.0fμs, df=%.0fkHz\n', ...
%     params.Fs/1e6, params.N, params.T*1e6, params.df/1e3);

%% 画信噪比-RMSE曲线
model_dir_path = "W:\Github\My-Repository\LiteSpectralNet\runs\";
model_path = "20260121_154837_spectral_12in_31out_train90k_noise0\";
file_name = "spectral_predictions.mat";
data = load(model_dir_path + model_path + file_name);
Y_gt = data.Y_gt;
Y_pred = data.Y_pred;
rmse = RMSE(Y_gt, Y_pred, 2);
psnr = PSNR(rmse);
n_files = 42;
x_P_list = load_mat("x_P_list_smps_0118", "gt");
Y_pred = x_P_list;
noise_psnr_raw_data = load_mat("noise_rmse_psnr_smps_0118", "gt");
noise = noise_psnr_raw_data(:, 1);
noise_psnr = zeros(n_files, 2);
noise_psnr(:, 1) = noise;
noise_psnr(:, 2) = noise_psnr_raw_data(:, 2);
[noise_psnr_sorted, sorted_idx] = sortrows(noise_psnr, 1);
selected_list = [1,  8, 9, 16, 20, 25, 29, 30, 34, 36, 39, 42];

Y_pred_sorted = Y_pred(sorted_idx, :);
x_pred_selected = Y_pred_sorted(selected_list, :);

noise = noise_psnr_sorted(selected_list, 1);
snr = 1 ./ noise;
snr = 20 * log10(snr);
noise = snr;
psnr = noise_psnr_sorted(selected_list, 2);
x_pred_double_selected = x_pred_selected(3:3+3, :);
noise_double_selected = noise(3:3+3, :);

%%
figure(2);
% plot(noise, psnr);
noise_selected2 = noise(3:end, :);
psnr_selected2 = psnr(3:end, :);
ax = gca;
plot(ax, noise_selected2, psnr_selected2, '--s', ... % Line with circle markers
     'Color', [0 0.4470 0.7410], ... % A nice blue color
     'LineWidth', 2, ... % Line thickness
     'MarkerSize', 6, ... % Marker size
     'MarkerFaceColor', [0 0.4470 0.7410], ... % Filled markers
     'MarkerEdgeColor', [0 0.4470 0.7410]); % Marker edge color

h_gt = gcf;
FONT_SIZE = 16;
xlabel('SNR (dB)', 'FontSize', 11);
ylabel('RMSE', 'FontSize', 11);
set(gca, 'XDir', 'reverse');
h = set_fig(h_gt, 'Arial', FONT_SIZE, 1.5, [18, 14]);
%% 
% 光谱重建对比图
wav = linspace(400, 700, 31);
x_gt = Y_gt(1, :);
hold on;
% 定义低饱和度颜色（柔和色调）
colors = [
    0.4, 0.6, 0.8;   % 浅蓝
    0.8, 0.5, 0.5;   % 浅红
    0.5, 0.7, 0.5;   % 浅绿
    0.7, 0.5, 0.7;   % 浅紫
    0.8, 0.7, 0.4;   % 浅黄
    0.5, 0.7, 0.7;   % 浅青
];

% 根据noise_double_selected生成图例名称
pred_names = cell(length(noise_double_selected), 1);
for i = 1:length(noise_double_selected)
    pred_names{i} = sprintf('SNR: %.2f dB', noise_double_selected(i) );
    % 或者如果噪声值本身就是百分比形式：
    % pred_names{i} = sprintf('噪声 %.1f%%', noise_double_selected(i));
end

% 绘制预测曲线（虚线）
h_pred = zeros(size(x_pred_double_selected, 1), 1);
for i = 1:size(x_pred_double_selected, 1)
    h_pred(i) = plot(wav, x_pred_double_selected(i, :) * 100, '--', ...
        'LineWidth', 2, 'Color', colors(i, :));
end

% 绘制真值曲线（黑色实线，最后绘制使其在最上层）
h_gt = plot(wav, x_gt * 100, 'k-', 'LineWidth', 2);
hold off;

% 图例
legend([h_gt; h_pred], ['GT'; pred_names(1:size(x_pred_double_selected, 1))], ...
    'Location', 'best', 'FontSize', 9);

% 坐标轴设置
xlim([400, 700]);
ylim([0, 100]);
xlabel('Wavelength (nm)', 'FontSize', 11);
ylabel('Transmittance (%)', 'FontSize', 11);
grid on;
box on;
set(gca, 'XDir', 'normal');
h_gt = gcf;
FONT_SIZE = 16;
h = set_fig(h_gt, 'Arial', FONT_SIZE, 1.5, [18, 14]);
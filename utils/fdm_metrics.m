function [rmse, psnr_val] = fdm_metrics(x_gt, x_est, varargin)
% FDM_METRICS 计算光谱重建的RMSE和PSNR，可选绘图
%
% 语法:
%   [rmse, psnr] = fdm_metrics(x_gt, x_est)
%   [rmse, psnr] = fdm_metrics(x_gt, x_est, 'Plot', true)
%   [rmse, psnr] = fdm_metrics(x_gt, x_est, 'Plot', true, 'Wavelengths', 400:10:700)
%
% 输入:
%   x_gt    - 真实光谱 [N x 1]
%   x_est   - 重建光谱 [N x 1]
%
% 可选参数:
%   'Plot'        - 是否绘图 (默认: false)
%   'Wavelengths' - 波长轴 (默认: linspace(400,700,N))
%   'Title'       - 图标题 (默认: 'Spectrum Reconstruction')
%   'Labels'      - 图例标签 {gt, est} (默认: {'Ground Truth', 'Estimated'})
%
% 输出:
%   rmse    - 均方根误差
%   psnr    - 峰值信噪比 (dB)
%
% 示例:
%   [rmse, psnr] = fdm_metrics(x_gt, x_est, 'Plot', true);
%   [rmse, psnr] = fdm_metrics(x_gt, x_est, 'Plot', true, 'Title', 'ColorChecker #16');

    x_gt = x_gt(:);
    x_est = x_est(:);
    N = length(x_gt);
    
    % 解析参数
    p = inputParser;
    addParameter(p, 'Plot', false, @islogical);
    addParameter(p, 'Wavelengths', linspace(400, 700, N), @isnumeric);
    addParameter(p, 'Title', 'Spectrum Reconstruction', @ischar);
    addParameter(p, 'Labels', {'Ground Truth', 'Estimated'}, @iscell);
    parse(p, varargin{:});
    opts = p.Results;
    
    % RMSE
    rmse = sqrt(mean((x_gt - x_est).^2));
    
    % PSNR (假设信号范围[0,1])
    mse = mean((x_gt - x_est).^2);
    if mse < eps
        psnr_val = Inf;
    else
        psnr_val = 10 * log10(1 / mse);
    end
    
    % 绘图
    if opts.Plot
        wl = opts.Wavelengths(:);
        
        figure('Position', [100, 100, 900, 350], 'Color', 'w');
        
        % 光谱对比图
        subplot(1, 2, 1);
        plot(wl, x_gt, 'b-', 'LineWidth', 2); hold on;
        plot(wl, x_est, 'r--', 'LineWidth', 2);
        xlabel('Wavelength (nm)');
        ylabel('Reflectance');
        title(sprintf('%s\nRMSE=%.4f, PSNR=%.2fdB', opts.Title, rmse, psnr_val));
        legend(opts.Labels{1}, opts.Labels{2}, 'Location', 'best');
        grid on;
        xlim([min(wl), max(wl)]);
        ylim([0, max([x_gt; x_est]) * 1.1]);
        
        % 误差图
        subplot(1, 2, 2);
        error = x_est - x_gt;
        bar(wl, error, 'FaceColor', [0.8, 0.2, 0.2], 'EdgeColor', 'none');
        xlabel('Wavelength (nm)');
        ylabel('Error (Est - GT)');
        title(sprintf('Reconstruction Error\nMax=%.4f, Mean=%.4f', max(abs(error)), mean(abs(error))));
        grid on;
        xlim([min(wl), max(wl)]);
        
        % 添加零线
        hold on;
        plot([min(wl), max(wl)], [0, 0], 'k-', 'LineWidth', 0.5);
    end
end
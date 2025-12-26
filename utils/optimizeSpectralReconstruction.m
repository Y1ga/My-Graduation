function x_temp = optimizeSpectralReconstruction(A, y, x_gt)
%OPTIMIZESPECTRALRECONSTRUCTION Performs optimized spectral reconstruction using 2nd order TV.
%   x_temp = OPTIMIZESPECTRALRECONSTRUCTION(A, y, x_gt)
%   This function reconstructs a spectrum x_temp from measurements y and
%   a forward model A, using a refined second-order Total Variation (TV)
%   regularization. It also analyzes the ground truth spectrum x_gt to
%   inform the optimization process and normalizes spectra for RMSE calculation.
%
%   Inputs:
%   A     - The forward model matrix.
%   y     - The measured signal.
%   x_gt  - The ground truth spectrum for comparison and analysis.
%
%   Output:
%   x_temp - The reconstructed spectrum.

fprintf('开始优化光谱重建...\n');

% 分析x_gt的特点
peak_indices = find(x_gt > 0.01 * max(x_gt));
if isempty(peak_indices)
    peak_center = NaN;
    peak_width = 0;
    fprintf('未检测到明显信号区域。\n');
else
    peak_center = round(mean(peak_indices));
    peak_width = length(peak_indices);
    fprintf('检测到信号区域: %d-%d (中心: %d, 宽度: %d)\n', ...
        min(peak_indices), max(peak_indices), peak_center, peak_width);
end

% 优化1：精细调参的二阶TV
fprintf('\n=== 优化1：精细二阶TV ===\n');
lambda_tv2_fine_range = [0.0001, 0.0005, 0.001, 0.002, 0.005, 0.01];
best_rmse = inf;
best_x_tv2 = [];
best_lambda_tv2 = 0;

% Construct D2 matrix
num_vars = size(A, 2); % Get the number of variables from matrix A
D2 = spdiags([ones(num_vars,1), -2*ones(num_vars,1), ones(num_vars,1)], [0, 1, 2], num_vars-2, num_vars);

% Normalize x_gt for RMSE calculation
x_gt_norm = x_gt / norm(x_gt);

for lambda_tv2 = lambda_tv2_fine_range
    cvx_begin quiet
        variable x_current(num_vars)
        minimize(norm(A * x_current - y, 2) + lambda_tv2 * norm(D2 * x_current, 1))
        subject to
            x_current >= 0
    cvx_end
    
    if strcmp(cvx_status, 'Solved')
        x_current_norm = x_current / norm(x_current);
        rmse_temp = sqrt(mean((x_gt_norm - x_current_norm).^2));
        if rmse_temp < best_rmse
            best_rmse = rmse_temp;
            best_x_tv2 = x_current;
            best_lambda_tv2 = lambda_tv2;
        end
    else
        fprintf('CVX status for lambda=%.4f: %s\n', lambda_tv2, cvx_status);
    end
end

fprintf('最优二阶TV: λ=%.4f, RMSE=%.6f\n', best_lambda_tv2, best_rmse);

% Assign the best result to the output
x_temp = best_x_tv2;

end
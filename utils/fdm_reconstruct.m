function [x_est, info] = fdm_reconstruct(y, A, varargin)
% FDM_RECONSTRUCT 从测量响应y和系统矩阵A重建光谱x
%
% 问题: y = A * x, 已知y和A，求x
%
% 语法:
%   x_est = fdm_reconstruct(y, A)
%   x_est = fdm_reconstruct(y, A, 'Method', 'tv')
%   [x_est, info] = fdm_reconstruct(y, A, ...)
%
% 输入:
%   y       - 测量响应 [M x 1]
%   A       - 系统矩阵 [M x N], M<N为欠定系统
%
% 可选参数:
%   'Method'    - 求解方法:
%                 'pinv'     - 伪逆
%                 'tikhonov' - Tikhonov正则化
%                 'lsqnonneg'/'nnls' - 非负最小二乘
%                 'tv'       - TV+L1+L2正则化梯度下降 (默认，推荐)
%   'Lambda'    - 正则化参数 (tikhonov用)
%   'Beta'      - [beta1, beta2, beta3] TV方法的正则化参数
%                 beta1: L1, beta2: L2, beta3: TV (默认: [0, 0.05, 1])
%   'MaxIter'   - 最大迭代次数 (默认: 2000)
%   'Alpha'     - 学习率 (默认: 0.001)
%   'Tol'       - 收敛阈值 (默认: 1e-6)
%   'Verbose'   - 是否打印信息 (默认: false)
%
% 输出:
%   x_est   - 重建的光谱 [N x 1]
%   info    - 结构体，包含求解信息
%
% 示例:
%   x_est = fdm_reconstruct(y_exp, A0_working);  % 默认TV方法
%   x_est = fdm_reconstruct(y_exp, A0_working, 'Method', 'tv', 'Beta', [0, 0.05, 1]);
%
% 作者: Claude
% 日期: 2024-12

    p = inputParser;
    addRequired(p, 'y', @isnumeric);
    addRequired(p, 'A', @isnumeric);
    addParameter(p, 'Method', 'tv', @ischar);  % 默认TV方法
    addParameter(p, 'Lambda', 0.01, @isnumeric);
    addParameter(p, 'Beta', [0, 0.05, 1], @isnumeric);  % [L1, L2, TV]
    addParameter(p, 'MaxIter', 2000, @isnumeric);
    addParameter(p, 'Alpha', 0.001, @isnumeric);
    addParameter(p, 'Tol', 1e-6, @isnumeric);
    addParameter(p, 'Verbose', false, @islogical);
    addParameter(p, 'x0', [], @isnumeric);
    parse(p, y, A, varargin{:});
    
    opts = p.Results;
    y = y(:);
    [M, N] = size(A);
    
    info.method = opts.Method;
    info.M = M;
    info.N = N;
    
    switch lower(opts.Method)
        case 'pinv'
            x_est = pinv(A) * y;
            info.description = '伪逆';
            
        case 'tikhonov'
            lambda = opts.Lambda;
            x_est = (A' * A + lambda * eye(N)) \ (A' * y);
            info.lambda = lambda;
            info.description = sprintf('Tikhonov (λ=%.4f)', lambda);
            
        case {'lsqnonneg', 'nnls'}
            x_est = lsqnonneg(A, y);
            info.description = 'NNLS';
            
        case {'tikhonov_nn', 'ridge_nn'}
            % Tikhonov + 非负截断
            lambda = opts.Lambda;
            x_est = (A' * A + lambda * eye(N)) \ (A' * y);
            x_est(x_est < 0) = 0;  % 非负截断
            info.lambda = lambda;
            info.description = sprintf('Tikhonov+NN (λ=%.4f)', lambda);
            
        case {'tv', 'gd', 'opt_gd'}
            % TV + L1 + L2 正则化梯度下降
            beta = opts.Beta;
            if length(beta) < 3
                beta = [0, 0.05, 1];
            end
            beta1 = beta(1);  % L1
            beta2 = beta(2);  % L2
            beta3 = beta(3);  % TV
            
            alpha = opts.Alpha;
            max_iter = opts.MaxIter;
            tol = opts.Tol;
            
            % 自适应缩放：让 y*scale 的均值约为100
            target_mean = 100;
            y_mean = mean(abs(y));
            if y_mean < eps
                scale = 1;
            else
                scale = target_mean / y_mean;
            end
            
            A_scaled = A * scale;
            y_scaled = y * scale;
            
            % 初始化
            if isempty(opts.x0)
                x = 0.5 * ones(N, 1);
            else
                x = opts.x0(:);
            end
            
            % 差分算子
            D = diff(eye(N));
            
            % 梯度下降
            for iter = 1:max_iter
                % 数据拟合项梯度
                residual = A_scaled * x - y_scaled;
                norm_res = norm(residual);
                if norm_res < eps
                    norm_res = eps;
                end
                grad_fit = A_scaled' * residual / norm_res;
                
                % L1正则化梯度
                grad_l1 = beta1 * sign(x);
                
                % L2正则化梯度
                norm_x = norm(x);
                if norm_x < eps
                    norm_x = eps;
                end
                grad_l2 = beta2 * x / norm_x;
                
                % TV正则化梯度
                diff_x = D * x;
                tv_norm = sqrt(sum(diff_x.^2) + 1e-8);
                grad_tv = beta3 * (D' * diff_x) / tv_norm;
                
                % 总梯度
                grad = grad_fit + grad_l1 + grad_l2 + grad_tv;
                
                % 更新
                x_new = x - alpha * grad;
                
                % 投影到[0,1]
                x_new = max(0, min(1, x_new));
                
                % 收敛检查
                if norm(x_new - x) < tol
                    break;
                end
                
                x = x_new;
            end
            
            x_est = x;
            info.beta = beta;
            info.iterations = iter;
            info.alpha = alpha;
            info.scale = scale;
            info.y_scaled_mean = mean(y_scaled);
            info.description = sprintf('TV+L1+L2 (β=[%.3f,%.3f,%.3f])', beta1, beta2, beta3);
            
            if opts.Verbose
                obj_val = norm(A*x_est - y, 2) + beta1*norm(x_est,1) + ...
                          beta2*norm(x_est,2) + beta3*sqrt(sum(diff(x_est).^2));
                fprintf('迭代次数: %d, scale: %.1f, y_scaled均值: %.1f\n', iter, scale, mean(y_scaled));
            end
            
        case 'ridge'
            lambda = opts.Lambda;
            x_est = (A' * A + lambda * eye(N)) \ (A' * y);
            info.lambda = lambda;
            info.description = sprintf('Ridge (λ=%.4f)', lambda);
            
        otherwise
            error('未知方法: %s', opts.Method);
    end
    
    % 计算y的重建
    y_recon = A * x_est;
    info.y_recon = y_recon;
    info.residual = norm(y - y_recon);
end
function x_P = opt_cvx(A_t, y_t, R_t, lambda_l1, lambda_tv, lambda_l2)  
    % 优化函数，通过CVX求解  
    % 输入参数：  
    % A_t      : 设计矩阵  
    % R_t      : 原始信号  
    % lambda_l1: L1正则权重  
    % lambda_tv : TV（全变差）正则权重  
    % lambda_l2: L2正则权重  
    % 输出参数：  
    % x_P      : 优化结果  

    % 计算 y_t  
    % y_t = A_t * R_t;  
    n = size(R_t, 1); % 确定维度  

    % CVX优化  
    cvx_begin  
        variable x_P(n, 1)  
        % 构造 TV 项  
        t = x_P(2:end) - x_P(1:end-1);  
        
        % 目标：数据拟合 + L1 + TV  
        minimize( ...  
            norm(A_t * x_P - y_t, 2) ...  
            + lambda_l1 * norm(x_P, 1) ...  
            + lambda_tv * norm(t, 1) ...  
            + lambda_l2 * norm(t, 2) ...  
        )  
    cvx_end  

    % 可选：计算并绘制RMSE和PSNR  
    rmse = RMSE(x_P, R_t);  
    psnr = PSNR(rmse);  
    wav = get_wav(); % 假设你有这个函数  
    % plot(wav, x_P, wav, R_t);  
    legend('pred', 'gt');  
    title(sprintf('PSNR: %.2f', psnr));  
end
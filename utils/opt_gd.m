function x = opt_gd(A, y, beta)
    if nargin == 2
        % 正则化参数
        beta1 = 0e-3;
        beta2 = 5e-2;
        % beta2 = 0e-1;
        beta3 = 1e-0;
    else
        beta1 = beta(1);
        beta2 = beta(2);
        beta3 = beta(3);
    end
    % 数据
    % A = randn(100, 50); % 100 个样本，50 个特征
    % y = randn(100, 1);  % 100 个样本的响应
    x0 = rand(size(A, 2), 1);  % 初始猜测值



    % 学习率
    alpha = 0.001;

    % 最大迭代次数
    max_iter = 1e5;

    % 收敛阈值
    tol = 1e-6;

    % 初始化
    x = x0;
    iter = 0;

    % 差分算子 D
    D = diff(eye(length(x))); % 50x50 单位矩阵的差分

    % 梯度下降迭代
    while iter < max_iter
        % 计算数据拟合项的梯度
        residual = A * x - y;
        grad_fit = A' * residual / norm(residual);

        % 计算 L1 正则化项的梯度
        grad_l1 = beta1 * sign(x);
        % 
        % 计算 L2 正则化项的梯度
        grad_l2 = beta2 * x / norm(x);
        % 
        % % % 计算 TV 正则化项的梯度
        diff_x = D * x;
        tmp = sum(diff_x .^ 2);
        grad_tv = beta3 * (D' * diff_x) / sqrt(sum(diff_x .^ 2));

        % 总梯度
        grad = grad_fit + grad_l1 + grad_l2 + grad_tv;
        % grad = grad_fit;
        % 更新参数
        x_new = x - alpha * grad;
        % 投影操作：限制 x_new 在 [0, 1] 范围内
        % x_new = max(0, min(1, x_new));
        x_new = max(0, min(1, x_new));

        % 检查收敛条件
        if norm(x_new - x) < tol
            break;
        end

        % 更新参数
        x = x_new;
        iter = iter + 1;
    end


    % 输出结果
    disp('优化解:');
    disp(x);
    disp('目标函数值:');
    disp(norm(A * x - y, 2) + beta1 * norm(x, 1) + beta2 * norm(x, 2) + beta3 * sqrt(sum(diff(x) .^ 2)));
    disp('迭代次数:');
    disp(iter);
end
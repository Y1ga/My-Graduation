function [x_Fmincon, fVal] = opt_fmincon(A, y, beta)
    if nargin == 2
        maxIter = 10000;
        beta1 = 0e-2;
        % beta1 = 5e-0;
        beta2 = 5e-1;
        beta3 = 1;
    else
         beta1 = beta(1);
        beta2 = beta(2);
        beta3 = beta(3);
    end
    maxIter = 10000;
    % 平滑因子betaSmooth
    % 惩罚项：betaSmooth * mean(sqrt(diff(x) .^ 2))，用于增加光谱曲线平滑度
    % 目标函数||Ax - y||_2

    objective = @(x) norm(A * x - y, 2) + beta1 *norm(x, 1) + beta2 * norm(x, 2) + beta3 * norm(diff(x), 2);
    % objective = @(x)  sqrt(mean((A * x-y).^ 2)) + beta1 *norm(x, 1) + beta2 * norm(x, 2) + beta3 * norm(diff(x), 2);

    % 初始化初值，下界，上界
    n = size(A, 2);
    initial_values = zeros(n, 1);
    lb = initial_values;
    ub = 1e5 * ones(n, 1);
    opt = optimoptions('fmincon',  'MaxIterations', maxIter, 'Display','off');
    % opt.SpecifyObjectiveGradient = True;
    % 优化，启动！
    [x_Fmincon, fVal] = fmincon(objective, initial_values, [], [], [], [], lb, ub, [], opt);
end

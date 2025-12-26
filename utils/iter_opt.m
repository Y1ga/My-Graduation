function [x_opt, f_opt, rmse_opt] = iter_opt(A, y, x, beta1, beta2, beta3)
if nargin == 3
    beta1 = 5e-2;
    beta2 = 5e-1;
    beta3 = 1;
end
    n = 100;
    % n = size(x, 2);
    x_opt = zeros(size(x,1), n);
    f_opt = zeros(n, 1);
    rmse_opt = zeros(n, 1);
    tic;
    


    parfor i = 1 : n
        y_test = y(:, i);
        x_test = x(:, i);
        [x_opt(:, i), f_opt(i)] = opt_fmincon(A, y_test, ...
            1000, beta1, beta2, beta3);
        rmse_opt(i) = RMSE(x_test, x_opt(:, i));
    end
    end_time = toc;
    fprintf('Cost Time:%gs\n', end_time);
end
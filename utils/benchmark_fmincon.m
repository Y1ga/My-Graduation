function x_P = benchmark_fmincon(A, y, x)
    n = size(x, 2);
    % n = 100;
    x_P = zeros([size(x,1), n]);
    tic;
    parfor i = 1 : n
         x_P(:, i) = opt_fmincon(A, y(:, i));
    end
    end_time = toc;
    print_time(end_time);
    rmse = RMSE(x_P, x(:,1:n));
    print_rmse(rmse);
end
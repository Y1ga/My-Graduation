function x_norm = norm_1(x, dim)
    if nargin == 1
        dim = 1;
    end
    x_norm = x ./ max(x, [], dim);
end
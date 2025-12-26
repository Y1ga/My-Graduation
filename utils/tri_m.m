function [x_min,  x_max, x_mean, i_min, i_max] =tri_m(x)
    x_mean = mean(x);
    [x_min, i_min] = min(x);
    [x_max, i_max] = max(x);
    fprintf("Mean Value: %g\n", x_mean);
    fprintf("Min Value:  %g\n", x_min);
    fprintf("Max Value:  %g\n", x_max);
end
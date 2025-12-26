function rmse = RMSE(x1, x2, dim)
if nargin == 2
    dim = 1;
end
delta = x1 - x2;
% deleta(151- 25:end) = 0;
deltaSquare = delta .^ 2;
deltaSquareMean = mean(deltaSquare, dim);
rmse = sqrt(deltaSquareMean);
end
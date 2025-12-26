
function newMat = interp_dim(mat, dim, new_num, type)
% 不指定插值类型，默认为pchip
if nargin == 3
    type = 'pchip';
end
x = 1 : size(mat, dim);
newX = linspace(1, size(mat, dim), new_num);
if (dim == 1)
    newMat = interp1(x, mat, newX, type);
elseif (dim == 2)
    mat = mat';
    mat = interp1(x, mat, newX, type);
    newMat = mat';
end
end
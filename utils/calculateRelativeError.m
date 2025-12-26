function relError = calculateRelativeError(matrix_A, matrix_B)
% calculateRelativeError 计算两个矩阵之间的相对误差
%
% 输入:
%   matrix_A - 参考矩阵 (真实值矩阵)
%   matrix_B - 待比较的矩阵 (测量值或近似值矩阵)
%
% 输出:
%   relError - 计算出的相对误差 (一个标量)
%
% 该函数还会将相对误差以百分比形式显示在命令窗口中。
%
% 用法:
%   true_matrix = [1, 2; 3, 4];
%   approx_matrix = [1.1, 2.2; 3.3, 4.4];
%   error = calculateRelativeError(true_matrix, approx_matrix);

% --- 输入检查 ---
if ~isequal(size(matrix_A), size(matrix_B))
    error('输入矩阵的维度必须相同。');
end
if ~isnumeric(matrix_A) || ~isnumeric(matrix_B)
    error('输入必须是数值矩阵。');
end

% --- 计算 Frobenius 范数 ---
% norm(matrix_A, 'fro') 计算矩阵A的Frobenius范数
% norm(matrix_A) 默认也是计算Frobenius范数
norm_A = norm(matrix_A);
norm_diff = norm(matrix_A - matrix_B);

% --- 计算相对误差 ---
% 检查 matrix_A 的范数是否为零，以避免除以零
if norm_A == 0
    if norm_diff == 0
        % 如果两个矩阵都是零矩阵，则误差为0
        relError = 0;
    else
        % 如果参考矩阵是零矩阵但差异不为零，则误差为无穷大
        relError = inf;
    end
else
    relError = norm_diff / norm_A;
end

% --- 以百分比形式显示结果 ---
% 使用 fprintf 函数格式化输出
% '%.4f' 表示保留四位小数的浮点数
% '%%' 用来显示一个百分号 '%'
fprintf('两个矩阵间的相对误差是: %.4f%%\n', relError * 100);

end

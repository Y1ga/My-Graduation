function err_percent = print_relative_error(mat1, mat2)
    % 计算相对误差（按元素）
    err_percent = relativeError(mat1, mat2, 'A', true); % 返回与 mat1 同尺寸的误差矩阵
    
    % 如果输入是二维以上矩阵，沿第一维取平均
    if ndims(mat1) >= 2 && size(mat1, 2) ~= 1
        % 计算沿第一维的平均相对误差（保持第一维）
        avg_err_percent = mean(err_percent, 2); % 对第一维以外的维度取平均
        avg_err_percent = squeeze(avg_err_percent); % 移除单一维度
        disp('相对误差(%):');
        disp(avg_err_percent);
    else
        avg_err_percent = mean(err_percent(:)); % 二维矩阵直接全局平均
        % 显示结果
        disp('相对误差(%):');
        disp(err_percent);
    end
    fprintf('平均相对误差：%.2f%%\n', mean(avg_err_percent(:)));
end
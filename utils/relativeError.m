function rel_error = relativeError(A, B, ref_type, show_percent)
% relativeError 计算两个矩阵的相对误差
%
%   rel_error = relativeError(A, B)
%       对于 2D 矩阵, 返回逐元素的相对误差矩阵 |A-B|./|A|。
%       对于 3D 矩阵, 返回一个列向量, 包含每个通道(第一维)的平均相对误差。
%
%   rel_error = relativeError(A, B, 'B') 使用B作为参考。
%   rel_error = relativeError(A, B, 'mean') 使用A和B的绝对值平均作为参考。
%   rel_error = relativeError(A, B, 'max') 使用A和B的绝对值最大值作为参考。
%
%   rel_error = relativeError(..., true) 将输出结果乘以100以百分比显示。
%
%   当A和B是3维矩阵时，函数假定第一维是通道维 [Channels, Height, Width]。
%   返回的 rel_error 将是一个大小为 [Channels, 1] 的向量。

%% --- 输入参数处理 ---
if nargin < 3 || isempty(ref_type)
    ref_type = 'A';  % 默认使用A作为参考
end
if nargin < 4 || isempty(show_percent)
    show_percent = false;  % 默认不显示百分号
end

% 检查维度是否一致
if ~isequal(size(A), size(B))
    error('输入矩阵A和B的维度必须相同。');
end

%% --- 核心计算 ---

% 根据矩阵维度选择不同处理方式
if ndims(A) == 3
    % --- 3D 矩阵处理 ---
    num_channels = size(A, 1);
    rel_error = zeros(num_channels, 1); % 初始化输出向量

    % 遍历第一维(通道)
    for i = 1:num_channels
        % 提取当前通道的2D数据
        A_slice = squeeze(A(i, :, :));
        B_slice = squeeze(B(i, :, :));

        % 对当前通道计算逐元素误差
        abs_error_slice = abs(A_slice - B_slice);

        % 根据类型获取参考矩阵
        switch lower(ref_type)
            case 'a'
                ref_slice = abs(A_slice);
            case 'b'
                ref_slice = abs(B_slice);
            case 'mean'
                ref_slice = (abs(A_slice) + abs(B_slice)) / 2;
            case 'max'
                ref_slice = max(abs(A_slice), abs(B_slice));
            otherwise
                error('不支持的参考类型。可用选项: ''A'', ''B'', ''mean'', ''max''');
        end

        % 避免除以零
        ref_slice(ref_slice == 0) = eps;
        
        rel_error_matrix_slice = abs_error_slice ./ ref_slice;

        % 计算该通道的平均相对误差，并存入结果向量
        rel_error(i) = mean(rel_error_matrix_slice, 'all');
    end

else
    % --- 1D/2D 矩阵处理 (原始逻辑) ---
    abs_error = abs(A - B);
    switch lower(ref_type)
        case 'a'
            ref = abs(A);
        case 'b'
            ref = abs(B);
        case 'mean'
            ref = (abs(A) + abs(B)) / 2;
        case 'max'
            ref = max(abs(A), abs(B));
        otherwise
            error('不支持的参考类型。可用选项: ''A'', ''B'', ''mean'', ''max''');
    end
    
    % 避免除以零
    ref(ref == 0) = eps;
    
    rel_error = abs_error ./ ref;
end


%% --- 输出格式化 ---
% 如果需要显示百分号
if show_percent
    rel_error = rel_error * 100;
end

end
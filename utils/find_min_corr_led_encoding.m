function [best_encode_mat, best_encode_A, min_corr_mean, min_corr_max] = find_min_corr_led_encoding(epoch_num)

    % 输入:
    %   led_shape: 13×31 的 LED 光谱矩阵（每行是一个 LED 的光谱）
    %   epoch_num: 随机生成的编码矩阵数量
    % 输出:
    %   best_encode_mat: 最优的 6×13 LED 编码矩阵（按均值相关系数）
    %   best_encode_A: 最优的 6×31 光谱矩阵（按均值相关系数）
    %   min_corr_mean: 最小均值相关系数
    %   min_corr_max: 最小最大相关系数

    % 初始化编码矩阵和光谱矩阵
    led_shape = load_mat("A","0402");
    % plot(get_wav,led_shape);
    encode_A = zeros(epoch_num, 6, 31);
    encode_mat = zeros(epoch_num, 6, 13);

    % 随机生成编码矩阵并计算对应的光谱矩阵
    for i = 1 : epoch_num
        encode_mat(i, :, :) = randi([0, 1], 6, 13);
        encode_A(i, :, :) = squeeze(encode_mat(i, :, :)) * led_shape;
    end

    % 初始化最优解
    min_corr_mean = inf;
    min_corr_max = inf;
    best_mat_mean = [];
    best_mat_max = [];
    best_encode_mat_mean = [];
    best_encode_mat_max = [];

    % 遍历所有随机生成的矩阵
    for i = 1 : epoch_num
        current_A = squeeze(encode_A(i, :, :));  % 当前 6×31 光谱矩阵
        current_encode_mat = squeeze(encode_mat(i, :, :));  % 当前 6×13 编码矩阵

        % 计算相关系数矩阵（6×6）
        corr_mat = abs(corr(current_A'));

        % 提取上三角部分（不包括对角线）
        upper_tri = triu(corr_mat, 1);
        corr_values = upper_tri(upper_tri ~= 0);  % 15 个相关系数

        % 计算统计量
        mean_abs_corr = mean(corr_values);
        max_abs_corr = max(corr_values);

        % 更新最优解（按均值）
        if mean_abs_corr < min_corr_mean
            min_corr_mean = mean_abs_corr;
            best_mat_mean = current_A;
            best_encode_mat_mean = current_encode_mat;
        end

        % 更新最优解（按最大值）
        if max_abs_corr < min_corr_max
            min_corr_max = max_abs_corr;
            best_mat_max = current_A;
            best_encode_mat_max = current_encode_mat;
        end
    end

    % 返回结果（默认按均值最优）
    best_encode_mat = best_encode_mat_mean;
    best_encode_A = best_mat_mean;

    % 显示结果
    disp('Best LED encoding matrix (by mean abs correlation):');
    disp(best_encode_mat);
    disp(['Mean absolute correlation: ', num2str(min_corr_mean)]);

    disp('Best LED encoding matrix (by max abs correlation):');
    disp(best_encode_mat_max);
    disp(['Max absolute correlation: ', num2str(min_corr_max)]);
end
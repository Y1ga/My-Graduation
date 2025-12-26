function [R, G, B] = extractRGBFrom585(rawImg, h1, h2, w1, w2)
    % 从 RGGB 排列的 RAW 图像中提取 R、G、B 分量
    % 输入：
    %   rawImg: 2160x3840 的 RAW 图像数据
    %   h1, h2: 切片的高度范围
    %   w1, w2: 切片的宽度范围
    % 输出：
    %   R, G, B: 提取到的 R、G、B 分量

    % 检查输入参数
    if h1 < 1 || h2 > 2160 || w1 < 1 || w2 > 3840 || h1 > h2 || w1 > w2
        error('Invalid slice range.');
    end

    % 切片范围
    slice = rawImg(h1:h2, w1:w2);

    % 获取切片尺寸
    [rows, cols] = size(slice);

    % 调整切片尺寸，确保是 2 的倍数
    rows = rows - mod(rows, 2);
    cols = cols - mod(cols, 2);
    slice = slice(1:rows, 1:cols);

    % 初始化 R、G、B 分量
    R = zeros(rows / 2, cols / 2);
    G = zeros(rows / 2, cols / 2);
    B = zeros(rows / 2, cols / 2);

    % 提取 R、G、B 分量
    rRow = 1;
    gRow = 1;
    bRow = 1;
    for i = 1:2:rows
        rCol = 1;
        gCol = 1;
        bCol = 1;
        for j = 1:2:cols
            % 根据 h1 和 w1 的奇偶性，确定 RGGB 排列
            if mod(h1, 2) == 1 && mod(w1, 2) == 1 % RGGB
                R(rRow, rCol) = slice(i, j);
                G(gRow, gCol) = slice(i, j + 1);
                G(bRow, bCol) = slice(i + 1, j);
                B(bRow, bCol) = slice(i + 1, j + 1);
            elseif mod(h1, 2) == 1 && mod(w1, 2) == 0 % GRBG
                G(rRow, rCol) = slice(i, j);
                R(gRow, gCol) = slice(i, j + 1);
                B(bRow, bCol) = slice(i + 1, j);
                G(bRow, bCol) = slice(i + 1, j + 1);
            elseif mod(h1, 2) == 0 && mod(w1, 2) == 1 % GBGR
                G(rRow, rCol) = slice(i, j);
                B(gRow, gCol) = slice(i, j + 1);
                R(bRow, bCol) = slice(i + 1, j);
                G(bRow, bCol) = slice(i + 1, j + 1);
            else % BGGR
                B(rRow, rCol) = slice(i, j);
                G(gRow, gCol) = slice(i, j + 1);
                G(bRow, bCol) = slice(i + 1, j);
                R(bRow, bCol) = slice(i + 1, j + 1);
            end
            rCol = rCol + 1;
            gCol = gCol + 1;
            bCol = bCol + 1;
        end
        rRow = rRow + 1;
        gRow = gRow + 1;
        bRow = bRow + 1;
    end
end
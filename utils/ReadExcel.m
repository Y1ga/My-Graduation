function originData = ReadExcel( path, isNorm,  colIndex, rowIndex, sheet_index)
if nargin == 1
    isNorm = true;
    rowIndex = [61, 74, 86, 99, 111, 124, 136, 149, 161, 174, 187, 199, 212, 224, 237, 250, 262, 275, 288, 301, 313, 326, 339, 351, 364, 377, 390, 402, 416, 428, 441];
    colIndex = 2 ;
    sheet_index = 1;
elseif nargin == 2
    rowIndex = [61, 74, 86, 99, 111, 124, 136, 149, 161, 174, 187, 199, 212, 224, 237, 250, 262, 275, 288, 301, 313, 326, 339, 351, 364, 377, 390, 402, 416, 428, 441];
    colIndex = 2 ;
    sheet_index = 1;
elseif nargin == 3
    rowIndex = [61, 74, 86, 99, 111, 124, 136, 149, 161, 174, 187, 199, 212, 224, 237, 250, 262, 275, 288, 301, 313, 326, 339, 351, 364, 377, 390, 402, 416, 428, 441];
    sheet_index = 1;
elseif nargin == 4
    sheet_index = 1;
end
originData = readtable(path, 'Sheet', sheet_index);
originData = originData(rowIndex, colIndex);
originData = table2array(originData);
% 除去负数
originData(originData < 5) = 0;
if (isNorm == true)
    maxRow = max(originData, [], 1);
    originData = originData ./ maxRow;
end
end
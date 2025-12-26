function originData = read_excel(path, sheet_index, colIndex, rowIndex)
if nargin == 1
    rowIndex = ReadRow;
    colIndex = 2 ;
    sheet_index = 1;
elseif nargin == 2
    rowIndex = ReadRow;
    colIndex = 2 ;
elseif nargin == 3
    rowIndex = ReadRow;
end
originData = readtable(path, 'Sheet', sheet_index);
originData = originData(rowIndex, colIndex);
originData = table2array(originData);
% 除去负数
originData(originData < 5) = 0;

end
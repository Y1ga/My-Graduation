function spec = ReadSpec(path)
    row = ReadRow();
    files = dir(path);
    files = files(3:end);
    spec = zeros(length(files), 31);
    for i = 1 : length(files)
        file_name = files(i).name;
        if contains(file_name, ".txt")
            data = readtable(path + "/" + file_name);
            spec_tmp = data(:, 2);
            spec_tmp =  table2array(spec_tmp);
            index = extractAfter(file_name, "_");
            index = extractBefore(index, ".");
            index = str2double(index);
            spec(index, :) = spec_tmp(row);
        end
    end
end
function table = ReadTxt(path)
    files = dir(path);
    files = files(3:end);
    table = zeros(length(files), 380);
    for i = 1 : length(files)
        file_name = files(i).name;
        if contains(file_name, ".txt")
            data = table2array(readtable(path + "/" + file_name));
            info = extractAfter(file_name, "Queen");
            info = extractBefore(info, ".");
            exp_time = str2double(extractAfter(info, "_"));
            index = str2double(extractBefore(info, "_"));
            table(index, :) = data * 1000 / (exp_time);
        end
    end
end
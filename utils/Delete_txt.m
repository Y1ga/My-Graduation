function Delete_txt(path)
    files = dir(path);
    for i = 1:length(files)
        file_name = files(i).name;
        if contains(file_name, ".txt")
            delete(path+"/"+file_name);
        end
    end
end
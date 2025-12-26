function [files, len] = GetFiles(path)
    files = dir(path);
    files = files(3:end);
    len = length(files);
end
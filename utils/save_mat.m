
function save_mat(mat, date)
    path = "./data/" + date + "/mat/";
        if ~isempty(path)
            mkdir(path);
        end
    mat_name = inputname(1);
    save(path + mat_name, "mat","-v7.3");
end
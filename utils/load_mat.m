function mat = load_mat(mat_name, date)
mat_path = "./data/" + date + "/mat/";
mat = load(mat_path + mat_name);
mat = mat.mat;
end

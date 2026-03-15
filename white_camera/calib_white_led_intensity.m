%% 保存标定结果（只需运行一次）
% 确保以下变量已在工作区中:
%   A_calibrated - 9×31 校正后的测量矩阵
%   A0           - 9×31 原始测量矩阵
%   k_vec        - 9×1 缩放系数

white_imgs = read_images("./white_camera/data/bench_20260307_203717/", true);

mu = 1.0;
D = diff(eye(31));
H_mat = A_calibrated'*A_calibrated + mu*(D'*D);  % 31×31

save('calibration_585.mat', 'A_calibrated', 'A0', 'k_vec', 'H_mat', 'white_imgs', 'mu', '-v7.3');
fprintf('标定数据已保存到 calibration_585.mat\n');
clear;
clc;
%% ==================== 路径配置 ====================
DATA_DIR = 'W:\Github\My-Repository\My-Graduation\paper-02\generate_dataset';
CONFIG_FILE = 'spectral_12in_31out_train90k_noise20.mat';  % 训练数据集配置
fprintf('\n========== 加载配置 ==========\n');
A = load_mat("led_pd_0118", "gt")';   % 6×31
[K, n_channels] = size(A);

config_path = fullfile(DATA_DIR, CONFIG_FILE);
fprintf('配置文件: %s\n', CONFIG_FILE);

config_data = load(config_path, 'config');
X_max = config_data.config.X_max;
noise_sigma = config_data.config.noise_sigma;

fprintf('A: %d × %d\n', K, n_channels);
fprintf('X_max: %.4f\n', X_max);
fprintf('noise_sigma: %.4f\n', noise_sigma);
%% 保存透射色卡数据集
y_measured_list = load_mat("y_measured_list_0118", "gt"); 
X_test = single(y_measured_list / X_max);
colorchecker = load_mat("colorchecker_trans_0118", "gt");
idx = 15;
x = colorchecker(:, idx);
n_files = size(X_test, 1);
Y_test = repmat(x, 1, n_files)';
Y_test = single(Y_test);
fprintf('\n========== 保存 ==========\n');
save_path = fullfile(DATA_DIR, 'colorchecker_trans_15_test.mat');
save(save_path, 'X_test', 'Y_test');
fprintf('已保存: %s\n', save_path);
%% 保存反射色卡数据集
DATA_DIR = 'W:\Github\My-Repository\My-Graduation\paper-02\generate_dataset';
y_measured_list = load_mat("y_measured_list_0104", "gt")'; 
X_test = single(y_measured_list);
colorchecker = load_mat("colorchecker_gt", "gt");
x = colorchecker;
n_files = size(X_test, 1);
Y_test = x';
Y_test = single(Y_test);
fprintf('\n========== 保存 ==========\n');
save_path = fullfile(DATA_DIR, 'colorchecker_ref_all_test.mat');
save(save_path, 'X_test', 'Y_test');
fprintf('已保存: %s\n', save_path);
%% 保存透射色卡数据集
DATA_DIR = 'W:\Github\My-Repository\My-Graduation\paper-02\generate_dataset';
y_measured_list = load_mat("y_measured_list_0118_colorchecker_trans", "gt"); 
X_test = single(y_measured_list);
colorchecker = load_mat("colorchecker_trans_0118", "gt");
x = colorchecker;
n_files = size(X_test, 1);
Y_test = x';
Y_test = single(Y_test);
fprintf('\n========== 保存 ==========\n');
save_path = fullfile(DATA_DIR, 'colorchecker_trans_all_test.mat');
save(save_path, 'X_test', 'Y_test');
fprintf('已保存: %s\n', save_path);

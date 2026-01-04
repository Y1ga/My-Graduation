clear;clc;

%% 配置（自动检测路径）
[mat_path, base_path] = get_project_paths();

% 文件路径
white_csv = fullfile(base_path, '新建文件3.csv');
sample_csv = fullfile(base_path, '新建文件4.csv');
skip_leds = [];
color_idx = 6;


%% 分步调用
% 1. 构建系统矩阵 A
[A, A_info] = build_system_matrix(white_csv, 'SkipLEDs', skip_leds, 'A0Path', mat_path);
% 2. 提取测量值 y
[y, y_info] = extract_measurement(sample_csv, 'SkipLEDs', skip_leds);
% 3. 加载色卡真值 x
[x, x_info] = load_ground_truth(color_idx, 'ColorPath', mat_path);
% 4. 计算理论值
y_theory = A * x;
% 5. 对比
metrics = compare_theory_vs_measurement(y, y_theory, 'Labels', A_info.working_leds);

%% 或者直接用于光谱重建
% x_gt = x;
% [x_est, info] = fdm_reconstruct(y, A, 'Method', 'tv');
% [rmse, psnr_val] = fdm_metrics(x_gt, x_est,'Plot',true);

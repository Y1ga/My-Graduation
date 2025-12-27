%% 1. 基本用法 - 修改路径后运行
config.root_folder = "W:\dataset\KAIST\";
config.save_folder = "W:\dataset\KAIST_MAT\";

% 运行脚本即可

%% 2. 检查 EXR 文件内容 (调试用)
info = inspect_exr_channels('W:\dataset\KAIST\scene01_reflectance.exr');

%% 3. 验证转换结果
verify_kaist_conversion('W:\dataset\KAIST_MAT\')

%% 4. 预览转换后的场景
preview_kaist_scene('W:\dataset\KAIST_MAT\scene01.mat')
%% 
function info = inspect_exr_channels(filepath)
    % 查看 EXR 文件中的所有通道
    %
    % 用法: info = inspect_exr_channels('scene01_reflectance.exr')
    
    fprintf('检查文件: %s\n', filepath);
    fprintf('%s\n', repmat('=', 1, 50));
    
    % 尝试使用 exrinfo 获取通道信息 (如果可用)
    if exist('exrinfo', 'file')
        try
            exr_info = exrinfo(filepath);
            fprintf('使用 exrinfo 读取\n');
            disp(exr_info);
            info = exr_info;
            return;
        catch
        end
    end
    
    % 尝试读取单个已知通道来测试接口
    fprintf('测试 exrreadchannels 接口...\n');
    
    try
        % 测试读取单通道
        R = exrreadchannels(filepath, 'R');
        [H, W] = size(R);
        fprintf('接口类型: exrreadchannels(file, channel_name)\n');
        fprintf('图像尺寸: %d x %d\n', H, W);
        
        % 测试常见通道
        test_channels = {'R', 'G', 'B', 'w420nm', 'w430nm', 'w550nm', 'w720nm'};
        valid_channels = {};
        
        for i = 1:length(test_channels)
            try
                data = exrreadchannels(filepath, test_channels{i});
                valid_channels{end+1} = test_channels{i}; %#ok<AGROW>
            catch
            end
        end
        
        fprintf('\n已验证的通道: %s\n', strjoin(valid_channels, ', '));
        
        info = struct('height', H, 'width', W, 'tested_channels', {valid_channels});
        
    catch ME
        fprintf('exrreadchannels 测试失败: %s\n', ME.message);
        fprintf('\n请检查 openexr-matlab 的安装和用法。\n');
        fprintf('参考: help exrreadchannels\n');
        info = struct();
    end
end
function verify_kaist_conversion(mat_folder)
    % 验证转换结果
    %
    % 用法: verify_kaist_conversion('W:\dataset\KAIST_MAT\')
    
    mat_files = dir(fullfile(mat_folder, '*.mat'));
    
    fprintf('验证 %d 个 MAT 文件:\n', length(mat_files));
    fprintf('%s\n', repmat('-', 1, 80));
    fprintf('%-25s | %12s | %8s | %8s | %s\n', ...
            '文件名', '尺寸', '最小值', '最大值', '波长范围');
    fprintf('%s\n', repmat('-', 1, 80));
    
    for i = 1:length(mat_files)
        filepath = fullfile(mat_folder, mat_files(i).name);
        data = load(filepath);
        
        if isfield(data, 'hsi')
            hsi = data.hsi;
            sz_str = sprintf('%dx%dx%d', size(hsi,1), size(hsi,2), size(hsi,3));
            
            if isfield(data, 'wavelengths')
                wl_str = sprintf('%d-%dnm', data.wavelengths(1), data.wavelengths(end));
            else
                wl_str = 'N/A';
            end
            
            fprintf('%-25s | %12s | %8.4f | %8.4f | %s\n', ...
                    mat_files(i).name, sz_str, min(hsi(:)), max(hsi(:)), wl_str);
        else
            fprintf('%-25s | %12s\n', mat_files(i).name, '无 hsi 变量');
        end
    end
end
function preview_kaist_scene(mat_path)
    % 预览 KAIST 场景
    %
    % 用法: preview_kaist_scene('W:\dataset\KAIST_MAT\scene01.mat')
    
    data = load(mat_path);
    
    [~, name, ~] = fileparts(mat_path);
    
    figure('Color', 'w', 'Position', [100, 100, 1200, 400], ...
           'Name', ['KAIST Preview: ' name]);
    
    % RGB 图像
    subplot(1, 3, 1);
    if isfield(data, 'rgb')
        rgb_display = data.rgb;
        rgb_display = rgb_display / max(rgb_display(:));
        rgb_display = rgb_display .^ 0.45;  % Gamma 校正
        imshow(rgb_display);
        title('RGB (Gamma 校正)');
    else
        text(0.5, 0.5, '无 RGB 数据', 'HorizontalAlignment', 'center');
        axis off;
    end
    
    % 单波段显示 (550nm - 绿色)
    subplot(1, 3, 2);
    if isfield(data, 'wavelengths')
        [~, idx_550] = min(abs(data.wavelengths - 550));
    else
        idx_550 = 14;  % 默认第14波段约为550nm
    end
    band_550 = data.hsi(:,:,idx_550);
    imagesc(band_550); axis image; colormap(gca, gray); colorbar;
    title(sprintf('波段 %d (≈550nm)', idx_550));
    
    % 光谱曲线 (中心点)
    subplot(1, 3, 3);
    [H, W, ~] = size(data.hsi);
    center_spectrum = squeeze(data.hsi(round(H/2), round(W/2), :));
    
    if isfield(data, 'wavelengths')
        plot(data.wavelengths, center_spectrum, 'b-', 'LineWidth', 1.5);
        xlabel('波长 (nm)');
    else
        plot(1:size(data.hsi, 3), center_spectrum, 'b-', 'LineWidth', 1.5);
        xlabel('波段序号');
    end
    ylabel('反射率');
    title('中心像素光谱');
    grid on;
    
    sgtitle(['场景: ' strrep(name, '_', '\_')], 'FontSize', 14);
end


function try_compile_mex()
    % 尝试自动编译 openexr-matlab MEX 文件
    
    fprintf('\n尝试自动编译 MEX 文件...\n');
    
    % 查找 openexr-matlab 路径
    exr_help_path = which('exrreadchannels');
    if isempty(exr_help_path)
        error('找不到 exrreadchannels.m，请确保 openexr-matlab 在 MATLAB 路径中');
    end
    
    openexr_folder = fileparts(exr_help_path);
    fprintf('openexr-matlab 路径: %s\n', openexr_folder);
    
    % 检查是否有编译脚本
    compile_script = fullfile(openexr_folder, 'compileMex.m');
    if exist(compile_script, 'file')
        fprintf('找到编译脚本，正在执行...\n');
        current_dir = pwd;
        cd(openexr_folder);
        try
            run('compileMex.m');
            fprintf('编译完成！\n');
        catch ME
            fprintf('编译失败: %s\n', ME.message);
        end
        cd(current_dir);
    else
        fprintf('未找到 compileMex.m，请手动编译\n');
        fprintf('参考: https://github.com/KAIST-VCLAB/openexr-matlab\n');
    end
end
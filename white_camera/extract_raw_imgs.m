%% demosaic_raw.m
% 自动查找Violet开头、_1/_2/_3结尾的RAW图，解马赛克后提取R/G/B通道

path = "W:\Github\My-Repository\My-Graduation\white_camera\data\bench_20260309_165240\";
outDir = fullfile(path, "raw_demosaic");
if ~exist(outDir, 'dir')
    mkdir(outDir);
end

%% 自动查找 Violet*_1.png / _2.png / _3.png
allFiles = dir(fullfile(path, "Violet*.png"));
rawFiles = [];
for k = 1:numel(allFiles)
    name = allFiles(k).name;
    % 匹配 Violet???_1.png / _2.png / _3.png（排除_rgb等后缀）
    if ~isempty(regexp(name, '^Violet.+_[123]\.png$', 'once'))
        rawFiles = [rawFiles; string(name)]; %#ok<AGROW>
    end
end

fprintf('找到 %d 张RAW文件:\n', numel(rawFiles));
for i = 1:numel(rawFiles)
    fprintf('  %s\n', rawFiles(i));
end

%% 解马赛克
for i = 1:numel(rawFiles)
    fname = rawFiles(i);
    raw = imread(fullfile(path, fname));

    % 确保是单通道（Bayer马赛克图）
    if size(raw, 3) > 1
        warning('%s 不是单通道图像，取第1通道作为Bayer数据', fname);
        raw = raw(:,:,1);
    end

    % 解马赛克 (RGGB)
    rgb = demosaic(raw, 'rggb');

    % 提取3个通道
    R = rgb(:,:,1);
    G = rgb(:,:,2);
    B = rgb(:,:,3);

    % 生成不带扩展名的基础名
    [~, baseName, ~] = fileparts(fname);

    % 保存为灰度PNG
    imwrite(R, fullfile(outDir, baseName + "_R.png"));
    imwrite(G, fullfile(outDir, baseName + "_G.png"));
    imwrite(B, fullfile(outDir, baseName + "_B.png"));

    fprintf('已处理: %s -> R/G/B 三通道已保存\n', fname);
end

fprintf('\n全部完成！共生成 %d 张灰度图，保存在:\n%s\n', numel(rawFiles)*3, outDir);
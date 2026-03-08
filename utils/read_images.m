function imgs = read_images(folder_path, normalize)
% READ_IMAGES 读取带索引的灰度图，拼接为 [N, H, W]
% normalize=true 时除以曝光时间*100
    if nargin < 2
        normalize = true;
    end

    files = dir(fullfile(folder_path, '*.png'));
    names = {files.name};
    tokens = regexp(names, 'Violet(\d+)_(\d+)\.png$', 'tokens');
    mask = ~cellfun(@isempty, tokens);
    files = files(mask);
    tokens = tokens(mask);
    exp_times = cellfun(@(t) str2double(t{1}{1}), tokens);
    indices   = cellfun(@(t) str2double(t{1}{2}), tokens);
    [~, order] = sort(indices);
    files = files(order);
    exp_times = exp_times(order);
    N = numel(files);
    for i = 1:N
        img = double(imread(fullfile(folder_path, files(i).name)));
        if normalize
            img = img * 100 / exp_times(i);
        end
        if i == 1
            [H, W] = size(img);
            imgs = zeros(N, H, W);
        end
        imgs(i, :, :) = img;
        fprintf('  [%d] %s  exp=%d\n', i, files(i).name, exp_times(i));
    end
    fprintf('输出 size: [%d, %d, %d]\n', size(imgs));
end
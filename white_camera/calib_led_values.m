clear;
%% 强度
folder_path ="./white_camera/data/bench_20260305_202806/";
imgs = read_images(folder_path);
%% 
img = squeeze(imgs(3, :, :));

%% 光谱
qe585 = load_mat("qe_585syscolor_0628", "gt");
led_spectra = load_mat("white_led", "gt");
led_spectra = led_spectra(1:3, :);
% qe585_led = qe585 * led_spectra;
wav = get_wav;
plot(wav, led_spectra);

%% 
led4 = led_spectra(2, :);
led4 = led4 ./ max(led4,[],'all') * 0.7;
% plot(wav, led4);
rgb4 = spec2rgb_1d(led4');
rectangle("LineWidth",1,"EdgeColor",rgb4,'FaceColor',rgb4);

%% 
function imgs = read_images(folder_path)
% READ_IMAGES 读取带索引的灰度图，除以曝光时间*100，拼接为 [3, H, W]

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
        img = img * 100 / exp_times(i);
        if i == 1
            [H, W] = size(img);
            imgs = zeros(N, H, W);
        end
        imgs(i, :, :) = img;
        fprintf('  [%d] %s  exp=%d\n', i, files(i).name, exp_times(i));
    end

    fprintf('输出 size: [%d, %d, %d]\n', size(imgs));
end
%% 
clear;
clc;
%% 读取432数据
folder_a = "W:\Github\My-Repository\My-Graduation\graduation\盲审\data\2026-03-15_06_07_28Z";
folder_b = "W:\Github\My-Repository\My-Graduation\graduation\盲审\data\2026-03-15_06_08_17Z";
delete(fullfile(folder_a, '*.txt'));
delete(fullfile(folder_b, '*.txt'));
path = folder_a;
files = dir(path);
files = files(3:end);
% num = 150;
num = length(files);
led_img = zeros(num, 1104, 1608,'uint16');
for i = 1:num
    file_name = files(i).name;
    if contains(file_name, ".TIF") && ~contains(file_name, ".txt")
        img = imread(path + "/" + file_name);
        led_img(i, :, :) = img;
    end
end
img1 = reshape(led_img,[size(led_img, 1), size(led_img, 2) * size(led_img, 3)]);

path = folder_b;
files = dir(path);
files = files(3:end);
led_img = zeros(num, 1104, 1608,'uint16');
for i = 1:num
    file_name = files(i).name;
    if contains(file_name, ".TIF") && ~contains(file_name, ".txt")
        img = imread(path + "/" + file_name);
        led_img(i, :, :) = img;
    end
end
img2 = reshape(led_img,[size(led_img, 1), size(led_img, 2) * size(led_img, 3)]);

img = horzcat(img1, img2);
clear [img1,img2];
img_mean = mean(img,1);
img_std = std(double(img), 1);
img_mean = uint16(round(img_mean));
%% 保存432数据
signal = save_signal(img_mean, img_std);
s_432 = signal;
save_mat(s_432, "0315");
%% 
clear;
s_432 = load_mat("s_432", "0315");
signal = s_432;
signal_mean = signal(:, 1);
signal_std = signal(:, 2);
noise = signal_std ./ signal_mean;
snr = signal_mean ./ signal_std;
snr = 20 * log10(snr);
% scatter(signal_mean, snr);
xlim([0,60000]);
scatter(signal_mean, noise);

%% 
signal_mean = signal(:, 1);
signal_std = signal(:, 2);
noise = signal_std ./ signal_mean;

%% Extra
function signal = save_signal(img_mean, img_std)
    signal = zeros(65536, 2);
    signal(:, 1) =0 : 65535;
    for i = 1 : length(img_mean)
        key = img_mean(i) + 1;
        signal_std = signal(key, 2);
        if (signal_std == 0)
            signal_std = img_std(i);
        else
            signal_std = (signal_std + img_std(i)) / 2;   
        end
        signal(key, 2) = signal_std;
    end
end
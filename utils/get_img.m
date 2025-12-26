% 获取指定文件夹下面的图片，灰度值归一化=灰度值*100/曝光
function imgs = get_img(path, str)
    if nargin == 1
        str = "432";
    end
    if str == "585"
        h = 2160;
        w = 3840;
    elseif str =="432"
        h = 1104;
        w = 1608;
    end
    [files, len] = GetFiles(path);
    imgs = zeros(len, h, w);
    for i = 1 : len
        file_name = files(i).name;
        if contains(file_name, "Violet") && contains(file_name, ".png") 
            led_string = extractBefore(file_name, ".png");
            led_string = extractAfter(led_string, "Violet");
            coded_index = str2double(extractAfter(led_string, "_"));
            exp_time = str2double(extractBefore(led_string, "_"));
            index = coded_index;
            img = double(imread(path + file_name));
            img = img  * 100 / exp_time;
            imgs(index, :, :) = img;
        end
    end
end
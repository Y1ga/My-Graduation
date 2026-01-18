clear;
clc;
%% 保存新的led光谱数据：led_0115
path = "./data/spec-26-01-18.xlsx";
data = read_excel(path, 2, 2:2:2*12, 61:440);
led_spec = data;
led_spec = interpSwitch(led_spec, 1, 31);
% 保存数据
led_spec = led_spec ./ sum(led_spec, 1);
led_0118 = led_spec;
% save_mat(led_0118, "gt");
led_pd_0118 = led_0118 .* reponse_pd;
reponse_pd = load_mat("response_pd", "gt");
led_pd_0118 = led_pd_0118 ./ sum(led_pd_0118, 1);
% save_mat(led_pd_0118, "gt");
%% 保存透射色卡光谱数据
path = "./data/spec-26-01-18.xlsx";
data = read_excel(path, 1, 2:2:2*25, 61:440);
bg = data(:, 1);
colorchecker_trans = data(:, 2:25);
colorchecker_trans = colorchecker_trans ./ bg;
colorchecker_trans_0118 = interpSwitch(colorchecker_trans, 1, 31);
% save_mat(colorchecker_trans_0118, "gt");

%% 保存投射色卡rgb数据
rgb = spec2rgb_1d(colorchecker_trans_0118);
rgb_colorchecker_trans_0118 = rgb;
% save_mat(rgb_colorchecker_trans_0118, "gt");

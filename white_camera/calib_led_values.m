clear;
%% 强度
folder_path ="./white_camera/data/bench_20260305_202806/";
imgs = read_images(folder_path);
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


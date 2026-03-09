%% 
clear;
clc;
%% 
path = "W:\Github\My-Repository\My-Graduation\white_camera\exp0305.xlsx";
data = read_excel(path, 1, 2:2:2*3, 60:440);
led_spectra = interpSwitch(data, 1, 31)';
white_led_spectra = led_spectra;
white_led_spectra = white_led_spectra ./ sum(white_led_spectra, 2);
save_mat(white_led_spectra, "gt");

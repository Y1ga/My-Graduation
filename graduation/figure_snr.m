%% 
clear;
clc;
%% s3a：拟合噪声公式
figure('Color', 'white', 'Position', [0 0 500 500]); % Adjust position for a good-sized figure

% Load and process data
s = load_mat("s_432", "0315");
s_mean = s(:,1);
s_std = s(:,2);
s_std = s_std(1:65002);
s_mean = s_mean(s_std ~= 0);
s_std = s_std(s_std ~= 0);

% Normalize and calculate noise for the second plot
noise = s_std ./ s_mean;
cdate2 = s_mean;
pop2 = noise * 100;

% Perform the fit
f2 = fit(cdate2, pop2, "power2");

% --- Plotting and Formatting ---

% Create the plot and get the handles for the data and the fit
h = plot(f2, cdate2, pop2); 
set(h(2), 'LineWidth', 3); 
% h(1) is the handle for the original data points
% h(2) is the handle for the fitted curve

% Set the line width of the fitted curve (the second handle) to 3
set(h(2), 'LineWidth', 3);
% You can also change other properties, e.g., color
% set(h(2), 'Color', 'r');

% Configure plot labels and legends
legend('Original Data', 'Fitted Curve');
xlabel('Intensity');
ylabel('Noise(%)');
xlim([0, cdate2(end)]);


% Configure axes properties
ax = gca; % Get current axes handle
set(ax, 'FontName', 'Arial');
set(ax, 'YDir', 'normal');
set(ax, 'XTickMode', 'manual');
set(ax, 'YTickMode', 'manual');
set(ax, 'FontSize', 16);
set(ax, 'LineWidth', 3);
grid off;
set(ax, 'XMinorTick', 'off', 'YMinorTick', 'off');
%% 4c: 拟合噪声公式 (Fit SNR (dB) formula)

% Load and process data
y_max = 1;
s = load_mat("s_432", "0315");
s_mean = s(:,1);
s_std = s(:,2);
figure('Color', 'white', 'Position', [0 0 500 500]); % Adjust position for a good-sized figure

% --- Data Cleaning ---
s_std = s_std(1:65002);
% Filter out data where std is zero or mean is not positive, to avoid errors in log.
valid_indices = s_std > 0;
s_mean = s_mean(valid_indices);
s_std = s_std(valid_indices);

% --- SNR Calculation and dB Conversion ---
% Calculate linear SNR
snr_linear = s_mean ./ s_std;

% Convert linear SNR to dB
snr_db = 20 * log10(snr_linear);

% Prepare data for fitting
cdate2 = s_mean; % x-axis data (Intensity)
pop2 = snr_db;   % y-axis data (SNR in dB)

% --- Perform the fit ---
% The relationship between SNR(dB) and linear Intensity is logarithmic.
% Therefore, we change the fit type to a logarithmic model.
% Define the fit type: f(x) = a*log(x) + b
fit_model = fittype('a*log(x) + b');
f2 = fit(cdate2, pop2, fit_model);

% --- Plotting and Formatting ---
% Create the plot and get the handles
h = plot(f2, cdate2, pop2);

% h(1) is the handle for the original data points
% h(2) is the handle for the fitted curve
set(h(2), 'LineWidth', 5); % Set the line width of the fitted curve

% Configure plot labels and legends
legend('Original Data', 'Fitted Curve');
xlabel('Intensity');
ylabel('SNR (dB)'); % Updated label for decibels
xlim([0, cdate2(end)]);

% Configure axes properties
ax = gca; % Get current axes handle
set(ax, 'YDir', 'normal');
set(ax, 'XTickMode', 'manual');
set(ax, 'YTickMode', 'manual');
set(ax, 'FontSize', 16);
set(ax, 'LineWidth', 3);
grid off;
set(ax, 'XMinorTick', 'off', 'YMinorTick', 'off');
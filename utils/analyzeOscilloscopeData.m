function [f_axis, P1] = analyzeOscilloscopeData(filename,display_figures)
%analyzeOscilloscopeData Analyzes oscilloscope .mat file data in both time and frequency domains.
%   [f_axis, P1] = analyzeOscilloscopeData(filename) loads the specified
%   .mat file, performs time and frequency domain analysis, generates a
%   diagnostic report in the command window, and plots the results.
%   It returns the frequency axis (f_axis) and the single-sided amplitude
%   spectrum (P1).
%
%   Input:
%       filename - String, the name of the .mat file to analyze.
%                  Assumes the file is in the same directory as the script
%                  or a fully qualified path is provided.
%
%   Outputs:
%       f_axis   - Vector, the frequency axis for the spectrum.
%       P1       - Vector, the single-sided amplitude spectrum.

%% 1. Initialization and File Configuration
% Clear command window, variables, and close figures are handled by the function scope.
clc; % Clear command window for each run
% --- User Setting: Only for plotting purposes within the function ---
plot_freq_limit = 200; % Default limit for frequency plot (Hz)
% -------------------------------------
path
%% 2. Load and Validate Data
fprintf('>>> Loading and analyzing file: %s\n\n', filename);
try
    data = load(filename);
catch ME
    error('!!! Failed to load file: %s\n Please check the path and filename are correct. Error: %s', filename, ME.message);
end

% Extract data and validate
if isfield(data, 'C2_time') && isfield(data, 'C2_data')
    t = data.C2_time;
    y = data.C2_data;
    if isempty(t) || isempty(y) || length(t) ~= length(y)
        error('!!! Invalid data file content or mismatch in time and voltage data length.');
    end
else
    error('!!! Variables C2_time and C2_data not found in the .mat file.');
end

%% 3. Time Domain Analysis and Parameter Calculation
N = length(y);                      % Total number of sampling points (N)
total_time = t(end) - t(1);         % Total acquisition time (T)
dt = mean(diff(t));                 % Time resolution (Δt), i.e., sampling period Ts
Fs = 1 / dt;                        % Sampling rate (Fs)
V_max = max(y);                     % Maximum voltage
V_min = min(y);                     % Minimum voltage
V_pp = V_max - V_min;               % Peak-to-peak voltage
V_dc_time = mean(y);                % DC mean calculated in time domain

%% 4. Frequency Domain Analysis (FFT) and Parameter Calculation
% Perform FFT
Y = fft(y);
P2 = abs(Y/N);
P1 = P2(1:floor(N/2)+1);
P1(2:end-1) = 2*P1(2:end-1);

% Create frequency axis
f_axis = Fs*(0:(N/2))/N;
df = Fs / N;                        % Frequency resolution (Δf)

% Extract key information from spectrum
dc_from_fft = P1(1);                % DC component from frequency domain (at 0Hz)

% Find significant frequency peaks
[pks, locs] = findpeaks(P1, f_axis, 'MinPeakHeight', max(P1(2:end))*0.01, 'MinPeakDistance', 1*df);

%% 5. Generate and Print Full Diagnostic Report
fprintf('=======================================================\n');
fprintf('|              Signal Diagnostic Report             |\n');
fprintf('=======================================================\n\n');
fprintf('--- Time Domain Parameters ---\n');
fprintf('Total Sampling Points (N)    : %d points\n', N);
fprintf('Total Acquisition Time (T)   : %.4f s  (%.2f ms)\n', total_time, total_time*1000);
fprintf('Time Resolution (Δt)         : %.4f µs (%.4f ns)\n', dt*1e6, dt*1e9);
fprintf('Sampling Rate (Fs)           : %.2f Hz (%.2f MSa/s)\n', Fs, Fs/1e6);
fprintf('Maximum Voltage (Vmax)       : %.3f V\n', V_max);
fprintf('Minimum Voltage (Vmin)       : %.3f V\n', V_min);
fprintf('Peak-to-peak Voltage (Vp-p)  : %.3f V\n', V_pp);
fprintf('DC Mean (Vdc)                : %.4f V\n\n', V_dc_time);

fprintf('--- Frequency Domain Parameters ---\n');
fprintf('FFT Frequency Resolution (Δf): %.3f Hz\n', df);
fprintf('DC Component (0 Hz)          : %.4f V\n\n', dc_from_fft);

fprintf('--- Detected Frequency Peaks ---\n');
if ~isempty(pks)
    for i = 1:length(pks)
        fprintf('  - Peak at %.3f Hz: Amplitude %.4f V\n', locs(i), pks(i));
    end
else
    fprintf('  No significant peaks detected.\n');
end
fprintf('=======================================================\n\n');

%% 6. Plot Graphical Results (Conditional Display)
if display_figures
    % figure('Name', ['Analysis of ' filename], 'NumberTitle', 'off', 'Position', [100, 100, 800, 600]);

    % Subplot 1: Time Domain Waveform
    subplot(2, 1, 1);
    plot(t, y, 'LineWidth', 1);
    title(['Time Domain: ' strrep(filename, '_', '\_')], 'Interpreter', 'tex'); % Use strrep for filenames with underscores
    xlabel('Time (s)');
    ylabel('Voltage (V)');
    grid on;
    axis tight;

    % Subplot 2: Frequency Domain Spectrum (Annotated)
    subplot(2, 1, 2);
    stem(f_axis, P1, 'LineWidth', 1.0, 'Marker', 'none', 'BaseValue', -0.05*max(P1));
    hold on;

    if ~isempty(pks)
        plot(locs, pks, 'rv', 'MarkerFaceColor', 'r'); % Mark all found peak points
        for i = 1:length(pks)
            % Only add text labels for peaks within the plot_freq_limit
            if locs(i) <= plot_freq_limit
                text(locs(i), pks(i), sprintf('  %.1f Hz', locs(i)), 'VerticalAlignment', 'bottom', 'FontSize', 8);
            end
        end
    end
    hold off;

    title(sprintf('Frequency Spectrum (0 - %.0f Hz)', plot_freq_limit));
    xlabel('Frequency (Hz)');
    ylabel('Amplitude');
    grid on;
    xlim([0, plot_freq_limit]);
    ylim([-0.05*max(P1), 1.1*max(P1)]);
end

end
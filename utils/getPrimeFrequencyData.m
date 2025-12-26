function [prime_frequencies, prime_P1_values] = getPrimeFrequencyData(f_axis, P1, display_figures)
%getPrimeFrequencyData Extracts frequency and amplitude data for specific prime numbers.
%   [prime_frequencies, prime_P1_values] = getPrimeFrequencyData(f_axis, P1, display_figures)
%   identifies a predefined list of prime numbers, finds their closest
%   corresponding frequencies in f_axis, and extracts the P1 amplitudes
%   at those frequencies. It also prints a report and can optionally
%   display a plot.
%
%   Inputs:
%       f_axis          - Vector, the frequency axis from an FFT.
%       P1              - Vector, the single-sided amplitude spectrum from an FFT,
%                         corresponding to f_axis.
%       display_figures - Optional logical (true/false). If true (default),
%                         a plot highlighting the prime frequencies will be displayed.
%                         If false, no figures will be generated.
%
%   Outputs:
%       prime_frequencies - Vector, the frequencies from f_axis that are
%                           closest to the target prime numbers.
%       prime_P1_values   - Vector, the P1 amplitudes corresponding to
%                           prime_frequencies.

% Handle optional input argument for figure display
if nargin < 3
    display_figures = true; % Default to true if not provided
end

% 1. Define the list of prime numbers to search for
target_primes = [113, 127, 131, 137, 139, 149, 151, 157, 163, 167, 173, 179];

% Pre-allocate arrays for efficiency
prime_frequencies = zeros(1, length(target_primes));
prime_P1_values = zeros(1, length(target_primes));

fprintf('--- Extracting Prime-related Frequency and P1 Values ---\n');
for i = 1:length(target_primes)
    prime_val = target_primes(i);

    % Find the index of the frequency in f_axis closest to the target prime
    % We assume f_axis is sorted in ascending order.
    [~, idx] = min(abs(f_axis - prime_val));

    prime_frequencies(i) = f_axis(idx);
    prime_P1_values(i) = P1(idx);

    fprintf('Prime: %d Hz -> Matched Frequency: %.3f Hz, Corresponding P1 Value: %.6f\n', ...
            prime_val, prime_frequencies(i), prime_P1_values(i));
end

% 2. Summarize Results
fprintf('\n==================================================\n');
fprintf('Target Primes (Hz):'); fprintf('%8d ', target_primes); fprintf('\n');
fprintf('Matched Freq (Hz): '); fprintf('%8.3f ', prime_frequencies); fprintf('\n');
fprintf('Corresponding P1:  '); fprintf('%8.6f ', prime_P1_values); fprintf('\n');
fprintf('==================================================\n');

% 3. Optional: Plot these specific frequency points
if display_figures
    figure('Name', 'Selected Prime Frequencies on Spectrum', 'NumberTitle', 'off');
    stem(f_axis, P1, 'LineWidth', 1.0, 'Marker', 'none', 'BaseValue', -0.05*max(P1));
    hold on;
    plot(prime_frequencies, prime_P1_values, 'ro', 'MarkerSize', 8, 'LineWidth', 1.5, 'MarkerFaceColor', 'r');
    
    % Add text labels for the prime numbers
    text(prime_frequencies, prime_P1_values, cellstr(num2str(target_primes')), ...
         'VerticalAlignment', 'bottom', 'HorizontalAlignment', 'right', 'FontSize', 9);
    hold off;
    title('Frequency Spectrum with Specific Prime Frequencies Highlighted');
    xlabel('Frequency (Hz)');
    ylabel('Amplitude (P1)');
    grid on;

    % Auto-adjust X-axis limits to clearly show the marked primes
    min_freq_plot = min(target_primes) - 10;
    max_freq_plot = max(target_primes) + 10;
    xlim([min_freq_plot, max_freq_plot]);
    ylim([-0.05*max(P1), 1.1*max(P1)]);
end

end
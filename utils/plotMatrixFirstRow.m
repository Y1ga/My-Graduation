function plotMatrixFirstRow(A, A2)
%plotMatrixFirstRow Plots the first row of two input matrices.
%   plotMatrixFirstRow(A, A2) creates a 2D plot comparing the values
%   in the first row of matrix A with the values in the first row of matrix A2.
%
%   Inputs:
%       A  - The first input matrix. It must have at least one row.
%       A2 - The second input matrix. It must have at least one row,
%            and its first row should have the same number of columns as A's first row.

% Check if matrices have at least one row
if isempty(A) || size(A, 1) < 1
    error('Input matrix A must have at least one row.');
end
if isempty(A2) || size(A2, 1) < 1
    error('Input matrix A2 must have at least one row.');
end

% Create a new figure for the plot
figure; 

% Plot the first row of A
plot(A(1,:), 'DisplayName', 'Matrix A (First Row)');
hold on; % Keep the current plot to add another line

% Plot the first row of A2
plot(A2(1,:), 'DisplayName', 'Matrix A2 (First Row)');

% Add plot labels, title, and legend for clarity
title('Comparison of First Rows of Matrices A and A2');
xlabel('Column Index');
ylabel('Value');
legend('show'); % Display the legend using the DisplayName values
grid on;       % Add a grid for better readability
hold off;      % Release the plot hold

end
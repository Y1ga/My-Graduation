function [height, width] = get_hw(path_or_img)
%GET_HW Gets height and width from an image by user click.
%   [height, width] = GET_HW(path_or_img) takes either an image file path
%   (string) or an image matrix, displays it, and allows the user to click
%   a point to determine the height and width.
%
%   Input:
%       path_or_img - Can be:
%                     1. A character array (string) representing the full path
%                        to an image file (e.g., 'C:\images\my_image.png').
%                     2. An image matrix (e.g., a 2D grayscale image or a
%                        3D RGB image).
%
%   Output:
%       height - The rounded y-coordinate of the user's click.
%       width  - The rounded x-coordinate of the user's click.

    % Check if the input is a string (file path) or an image matrix
    if ischar(path_or_img) || isstring(path_or_img)
        % Input is a string, so read the image from the path
        ref_img = imread(path_or_img);
    else
        % Input is already an image matrix
        ref_img = path_or_img;
    end

    % Display the image
    figure; % Create a new figure for displaying the image
    imshow(ref_img, []); % Display image, [] scales display range
    axis on; % Show axis tick marks and labels

    % Get user click for width and height
    title('Click on the point to get width and height'); % Add a title to guide the user
    [width_click, height_click] = ginput(1); % ginput returns [x, y]

    % Round the coordinates to the nearest integer
    width = round(width_click);
    height = round(height_click);

    close(gcf); % Close the figure after getting the input

end
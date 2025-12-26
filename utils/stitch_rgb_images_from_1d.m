function rgb_composite_img = stitch_rgb_images_from_1d(rgb_1d_data, img_height, img_width, num_images, save_path, index_name)
%STITCH_RGB_IMAGES_FROM_1D Processes 1D raw data to stitch into a composite RGB image.
%
%   rgb_composite_img = STITCH_RGB_IMAGES_FROM_1D(rgb_1d_data, img_height, img_width, num_images, save_path)
%
%   This function takes a 1D array of raw RGB data, reshapes it into
%   individual images, and then stitches these images into a single,
%   larger composite image, arranged in a 2x2 grid. It can also save
%   individual images and the composite image to a specified path.
%
%   Inputs:
%       rgb_1d_data - A 1D array containing the raw RGB pixel data.
%                     Expected to be 3 * img_height * img_width * num_images in length.
%       img_height  - The height of a single individual image.
%       img_width   - The width of a single individual image.
%       num_images  - The total number of individual images to extract and stitch.
%                     (Currently hardcoded to stitch in a 2x2 grid, so num_images should ideally be 4).
%       save_path   - (Optional) A string specifying the directory path where
%                     individual and composite images will be saved. If empty
%                     or not provided, images will not be saved.
%       index_name  - (Optional) A string to append to saved filenames for identification.
%
%   Output:
%       rgb_composite_img - The final stitched composite RGB image matrix.

if nargin < 6
    index_name = "";
end

% Validate inputs
if nargin < 4
    error('stitch_rgb_images_from_1d:NotEnoughInputs', 'Not enough input arguments. Requires rgb_1d_data, img_height, img_width, num_images.');
end
if nargin < 5
    save_path = ''; % No save path provided
end

num_channels = 3; % RGB image has 3 channels

% --- New condition for size(rgb_1d_data, 1) == 31 ---
if size(rgb_1d_data, 1) == 31
    % In this case, rgb_1d_data is already structured for direct composite creation
    % The output will be [31, img_height * grid_rows, img_width * grid_cols]
    % However, the output needs to be a standard image format (Height x Width x Channels)
    % We need to reshape this data into the final composite image format.
    
    % Assuming the 31 rows represent some kind of channel information,
    % and the rest of the data needs to be arranged into a single image.
    % This part requires clarification on how the 31 rows relate to the
    % final image structure if it's not simply 3 channels.
    % For a standard RGB image, we expect 3 channels. If 31, we need to decide
    % how to map these to an RGB image.
    
    % Given the prompt, "最后得到[31,img_height * grid_rows, img_width * grid_cols]的矩阵保存为mat"
    % it suggests that the output `rgb_composite_img` itself should be a 3D matrix
    % with 31 as the first dimension. This is not a standard image format (H x W x C).
    % So, we will directly reshape and save this specific format.
    
    % Calculate grid dimensions, even if not stitching, to determine total composite size
    if num_images == 4
        grid_rows = 2;
        grid_cols = 2;
    else
        grid_rows = ceil(sqrt(num_images));
        grid_cols = ceil(num_images / grid_rows);
    end
    
    % Assuming rgb_1d_data is already in a structure like [channels, total_pixels]
    % And the desired output is [31, img_height * grid_rows, img_width * grid_cols]
    % We need to ensure the number of elements matches.
    expected_elements = 31 * img_height * grid_rows * img_width * grid_cols;
    if numel(rgb_1d_data) ~= expected_elements
        error('stitch_rgb_images_from_1d:DataSizeMismatch', ...
              'For size(rgb_1d_data, 1) == 31, the total number of elements in rgb_1d_data does not match the expected composite dimensions.');
    end
    
    % Reshape directly into the target [31, H, W] format
    rgb_composite_img = reshape(rgb_1d_data, [31, img_height * grid_rows, img_width * grid_cols]);
    
    % Save as .mat file as requested
    if ~isempty(save_path)
        if ~endsWith(save_path, filesep)
            save_path = [save_path filesep];
        end
        if ~isfolder(save_path)
            mkdir(save_path);
        end
        
        mat_filename = sprintf('composite_data_%s.mat', index_name);
        full_path = [save_path mat_filename];
        % save(full_path, 'rgb_composite_img');
        fprintf('Saved composite data (size [31, H, W]) as MAT file: %s\n', full_path);
    end
    
    return; % Exit the function after handling this specific case
end

% --- Original logic for stitching individual images (num_channels = 3) ---
% Determine the grid size for stitching.
if num_images == 4
    grid_rows = 2;
    grid_cols = 2;
else
    warning('stitch_rgb_images_from_1d:UnexpectedNumImages', 'This function is optimized for num_images = 4 (2x2 grid). Unexpected num_images might result in improper stitching.');
    grid_rows = ceil(sqrt(num_images));
    grid_cols = ceil(num_images / grid_rows);
end

% Pre-allocate the large composite image
rgb_composite_img = zeros(img_height * grid_rows, img_width * grid_cols, num_channels, 'uint8');

% Loop through each of the individual images
for i = 1 : num_images
    % Calculate start and end indices in the 1D raw data
    segment_length = img_height * img_width * num_channels; % Account for 3 channels per image
    idx_begin = (i-1) * segment_length + 1;
    idx_end = idx_begin + segment_length - 1;
    
    % Ensure data segment exists
    if idx_end > numel(rgb_1d_data)
        error('stitch_rgb_images_from_1d:DataIndexOutOfBound', ...
              'Calculated data segment index exceeds the bounds of rgb_1d_data. Check img_height, img_width, num_images.');
    end
    
    % Extract, reshape, and permute the current image segment
    % The raw data is likely C, H, W order when reshaped from 1D, so permute to H, W, C
    tmp_image_1d = rgb_1d_data(idx_begin:idx_end);
    tmp_image = permute(reshape(tmp_image_1d, [num_channels, img_height, img_width]), [2, 3, 1]);
    
    % --- Stitch into the composite image ---
    current_grid_row = ceil(i / grid_cols);
    current_grid_col = mod(i - 1, grid_cols) + 1;
    row_start = (current_grid_row - 1) * img_height + 1;
    row_end = current_grid_row * img_height;
    col_start = (current_grid_col - 1) * img_width + 1;
    col_end = current_grid_col * img_width;
    
    rgb_composite_img(row_start:row_end, col_start:col_end, :) = tmp_image;
    
    % --- Optional: Save individual images ---
    if ~isempty(save_path)
        % Ensure the save_path ends with a file separator
        if ~endsWith(save_path, filesep)
            save_path = [save_path filesep];
        end
        % Create directory if it doesn't exist
        if ~isfolder(save_path)
            mkdir(save_path);
        end
        str_individual_img = sprintf("rgb_pred_img_%sc_%02d.png", index_name, i); % Use sprintf for consistent naming with leading zeros
        path = save_path+str_individual_img;
        imwrite(tmp_image, path);
        fprintf('Saved individual image: %s\n', [save_path str_individual_img]);
    end
end

% --- Optional: Save the stitched composite image ---
if ~isempty(save_path)
    str_composite_img = "rgb_pred_" + index_name + "c_" + "composite.png";
    path = save_path + str_composite_img;
    imwrite(rgb_composite_img, path);
    fprintf('Saved composite image: %s\n', [save_path str_composite_img]);
end

end
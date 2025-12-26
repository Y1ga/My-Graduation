function x_2d = convert_3d_to_2d(x_3d)
    x_2d = reshape(x_3d, [size(x_3d, 1), size(x_3d, 2) * size(x_3d, 3)]);
end
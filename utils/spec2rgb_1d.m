function [rgb_1d, XYZ_1d] = spec2rgb_1d(x)
    num = length(x);
    XYZ = zeros(3, num);

    % spec2rgb
    parfor i = 1 : num
        x_tmp = x(:, i);
        XYZ_tmp = spec2xyz_31(x_tmp);
        XYZ(:, i) = XYZ_tmp;
    end
    % xyz2rgb
    rgb = zeros(3, num);
    parfor i = 1 : num
        XYZ_tmp2 = XYZ(:, i);
        rgb(:, i) = xyz2rgb([XYZ_tmp2(1),XYZ_tmp2(2),XYZ_tmp2(3)], 'OutputType','uint8');
    end
    rgb_1d = uint8(rgb);
    XYZ_1d = XYZ;
end
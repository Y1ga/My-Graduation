function [rgb_img, XYZ_img] = spec2rgb_img(R)
    x = R;
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
    rgb_img = reshape(rgb, [size(rgb, 1), 512, 512]);
    % rgb_img = reshape(rgb, [size(rgb, 1), 1104, 1608]);
    % 记得转为uint8
    rgb_img = uint8(permute(rgb_img,[2,3,1]));
    XYZ_img = XYZ;
end
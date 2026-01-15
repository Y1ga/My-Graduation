function [rgb_out, XYZ] = spec2rgb_simple(x)
    % spec_31: 31×N 光谱数据 (400:10:700)    
    num = size(x, 2);
    XYZ = zeros(3, num);

    % spec2rgb
    for i = 1 : num
        x_tmp = x(:, i);
        XYZ_tmp = spec2xyz_31(x_tmp);
        XYZ(:, i) = XYZ_tmp;
    end
    % xyz2rgb
    rgb = zeros(3, num);
    for i = 1 : num
        XYZ_tmp2 = XYZ(:, i);
        rgb(:, i) = xyz2rgb([XYZ_tmp2(1),XYZ_tmp2(2),XYZ_tmp2(3)], 'OutputType','uint8');
    end
    rgb_out = uint8(rgb);
end
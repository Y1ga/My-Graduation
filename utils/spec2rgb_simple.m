function [rgb_out, XYZ] = spec2rgb_simple(spec_31)
    % spec_31: 31×N 光谱数据 (400:10:700)
    
    [~, num] = size(spec_31);
    
    % 加载数据
    ciexyz = load_mat("ciexyz31_1", "gt");   % 301×4
    ill = load_mat("ill_D65", "gt");          % 301×2
    
    wl_full = 400:700;      % 301点
    wl_31 = 400:10:700;     % 31点
    
    source = ill(:, 2);
    xbar = ciexyz(:, 2);
    ybar = ciexyz(:, 3);
    zbar = ciexyz(:, 4);
    
    % 归一化系数 (确保完美白色反射体Y=1)
    k = 1 / sum(source .* ybar);
    
    XYZ = zeros(3, num);
    
    for i = 1:num
        % 插值到301点
        rf = interp1(wl_31, spec_31(:,i), wl_full, 'makima')';
        
        % 计算XYZ
        XYZ(1,i) = k * sum(source .* xbar .* rf);
        XYZ(2,i) = k * sum(source .* ybar .* rf);
        XYZ(3,i) = k * sum(source .* zbar .* rf);
    end
    
    % XYZ转sRGB
    rgb_out = xyz2rgb(XYZ', 'ColorSpace', 'srgb', 'OutputType', 'uint8')';
end
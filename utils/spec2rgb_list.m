function rgb_output = spec2rgb_list(r)

    num_items = size(r, 1);
    rgb_output = zeros(num_items, 3, size(r, 3));
    
    tic;
    for i = 1 : num_items
        r_tmp = squeeze(r(i, :, :));
        rgb_output(i, :, :) = spec2rgb_1d(r_tmp);
    end
    end_time = toc;
    print_time(end_time);

end
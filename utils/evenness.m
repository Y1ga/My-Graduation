%% 分析光照均匀性(输入imgs)
function img_mean = evenness(imgs)
    imgs_10x = imgs;
    imgs_mean = zeros(size(imgs_10x, 1));
    for i = 1 : size(imgs_10x, 1)
        img = squeeze(imgs_10x(i, :, :));
        img_mean = mean(img, 'all');
        img_diff = abs(img - img_mean);
        img_sigma = img_diff / img_mean;
        img_sigma_mean = mean(img_sigma,"all");
        imgs_mean(i) = img_sigma_mean;
        fprintf("Index %d Sigma: %g%%\n", i, img_sigma_mean*100);
    end
end

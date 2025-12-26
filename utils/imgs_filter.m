function imgs_filter = imgs_filter(imgs, kernel_size)
    imgs_filter = zeros(size(imgs));
    for i = 1 : size(imgs,1)
        img = squeeze(imgs(i,:,:));
        imgs_filter(i,:,:) = imfilter(img, fspecial('average', kernel_size), 'replicate');
    end
end

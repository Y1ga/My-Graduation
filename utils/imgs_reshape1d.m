function imgs = imgs_reshape1d(imgs)
    imgs = reshape(imgs,[size(imgs,1),size(imgs,2)*size(imgs,3)]);
end
function psnr = PSNR(rmse)
    psnr = 20 * log10(1 ./ rmse);
end
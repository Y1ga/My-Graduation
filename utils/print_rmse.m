function print_rmse(rmse)
    [rmse_min, rmse_max, rmse_mean, index_min, index_max] = tri_m(rmse);
    psnr = PSNR(rmse);
    [psnr_min, psnr_max, psnr_mean, index_min, index_max] = tri_m(psnr);
end
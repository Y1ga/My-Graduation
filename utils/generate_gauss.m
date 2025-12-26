function gauss = generate_gauss(miu, fwhm)
    if nargin == 1
        miu = 850;
    elseif nargin == 0
        miu = 850;
        fwhm = 5;
    end
    x = 800:0.5:900;
    sigma = fwhm / (2*sqrt(2*log(2)));
    gauss = exp(-((x-miu).^2)/(2*sigma^2))/(2*pi*sigma^2);
    gauss = norm_1(gauss,2);
    % plot(x,gauss);
end
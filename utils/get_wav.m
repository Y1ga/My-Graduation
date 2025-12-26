function wav = get_wav(num)
    if nargin == 0
        num = 31;
    end
    wav = linspace(400, 700, num);
end
function compare_two(former, latter, axisx)
    if nargin == 2
        plot(former);
        hold on;
        plot(latter);
        legend('1', '2');
    elseif nargin == 3
        plot(axisx, former);
        hold on;
        plot(axisx, latter);
        legend('pred', 'gt');
    end

end
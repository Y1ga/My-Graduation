function filename = save_dataset(path, input_data, output_data,input_valid,output_valid)
        timestamp = datestr(now, 'yyyymmdd_HHMMSS');
        prefix = 'badge';  % 避免使用 str 作为变量名
        filename = [prefix, '_', datestr(now(), 'yyyymmdd_HHMMSS'), '.mat'];
        disp(['生成文件名: ', filename]);
        input_data = single(input_data);
        output_data = single(output_data);
    if nargin == 3
        % 保存到文件
        save(path + filename, "input_data","output_data","-v7");
    end
    if nargin == 5
        input_valid = single(input_valid);
        output_valid = single(output_valid);
        save(path + filename, "input_data","output_data","input_valid","output_valid","-v7");
    end
    disp(['已保存至: ', filename]);
end
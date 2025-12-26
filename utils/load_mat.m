function mat = load_mat(varargin)
% LOAD_MAT 灵活加载mat文件
%
%   用法：
%     load_mat(filepath)                    % 完整路径
%     load_mat(filename, folder)            % 文件名 + 所在文件夹
%     load_mat(filename, date)              % 文件名 + 日期（使用默认目录结构）
%     load_mat(..., 'var', varname)         % 指定要提取的变量名
%
%   示例：
%     A = load_mat('D:/data/test.mat')
%     A = load_mat('test', 'D:/data/')
%     A = load_mat('spectrum', '20241225')

    % 解析参数
    [filepath, varname] = parse_inputs(varargin{:});
    
    % 检查文件
    if ~isfile(filepath)
        show_error(filepath);
    end
    
    % 加载
    if isempty(varname)
        data = load(filepath);
        mat = extract_data(data);
    else
        data = load(filepath, varname);
        if isfield(data, varname)
            mat = data.(varname);
        else
            error('文件中不存在变量: %s', varname);
        end
    end
end

%% ================== 参数解析 ==================

function [filepath, varname] = parse_inputs(varargin)
    varname = '';
    
    % 查找 'var' 参数
    var_idx = find(strcmpi(varargin, 'var'), 1);
    if ~isempty(var_idx)
        if var_idx < numel(varargin)
            varname = char(varargin{var_idx + 1});
            varargin([var_idx, var_idx+1]) = [];
        else
            error('var 参数后需要指定变量名');
        end
    end
    
    % 处理主要参数
    if numel(varargin) == 1
        % 单参数：完整路径
        filepath = to_path(varargin{1});
        
    elseif numel(varargin) == 2
        arg1 = char(varargin{1});  % 文件名
        arg2 = to_path(varargin{2});  % 文件夹或日期
        
        if is_path(arg2)
            % arg2 是文件夹路径
            filepath = fullfile(arg2, arg1);
        else
            % arg2 是日期，使用默认目录结构
            base_dir = get_base_dir();
            filepath = fullfile(base_dir, 'data', arg2, 'mat', arg1);
        end
    else
        error('参数错误，用法: load_mat(filepath) 或 load_mat(filename, folder)');
    end
    
    % 补全 .mat 扩展名
    if ~endsWith(filepath, '.mat', 'IgnoreCase', true)
        filepath = [filepath, '.mat'];
    end
end

function p = to_path(s)
    % 转换为标准路径格式，统一使用正斜杠避免转义问题
    p = char(s);
    p = strrep(p, '\', '/');  % 反斜杠转正斜杠
end

function tf = is_path(s)
    % 判断是否为路径（包含路径分隔符、盘符、或已存在的文件夹）
    s = char(s);
    has_separator = contains(s, '/') || contains(s, '\');
    has_drive = (length(s) >= 2 && s(2) == ':');  % Windows盘符
    starts_with_slash = startsWith(s, '/') || startsWith(s, '~');  % Unix绝对路径
    
    tf = has_separator || has_drive || starts_with_slash || isfolder(s);
end

function base_dir = get_base_dir()
    stack = dbstack('-completenames');
    for i = numel(stack):-1:1
        if ~isempty(stack(i).file)
            [base_dir, ~, ~] = fileparts(stack(i).file);
            if ~isempty(base_dir)
                return;
            end
        end
    end
    base_dir = pwd;
end

function mat = extract_data(data)
    fields = fieldnames(data);
    if numel(fields) == 1
        mat = data.(fields{1});
    elseif ismember('mat', fields)
        mat = data.mat;
    elseif ismember('data', fields)
        mat = data.data;
    else
        warning('load_mat:multipleVars', ...
            'mat文件包含多个变量: %s，返回完整结构体', strjoin(fields, ', '));
        mat = data;
    end
end

function show_error(filepath)
    [folder, name, ext] = fileparts(filepath);
    if isempty(ext), ext = '.mat'; end
    
    % 使用 fprintf 直接输出，避免 sprintf 转义问题
    fprintf('\n========== load_mat 错误 ==========\n');
    fprintf('找不到: %s%s\n', name, ext);
    fprintf('完整路径: %s\n', filepath);
    
    if isempty(folder), folder = pwd; end
    
    if ~isfolder(folder)
        fprintf('目录不存在: %s\n', folder);
    else
        files = dir(fullfile(folder, '*.mat'));
        if isempty(files)
            fprintf('该目录无.mat文件\n');
        else
            fprintf('可用文件:\n');
            for i = 1:min(numel(files), 8)
                fprintf('  %s\n', files(i).name);
            end
        end
    end
    fprintf('====================================\n\n');
    
    % 抛出简洁错误
    error('load_mat:fileNotFound', '文件不存在: %s', strrep(filepath, '\', '/'));
end
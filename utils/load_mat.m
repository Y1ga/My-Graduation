function mat = load_mat(varargin)
% LOAD_MAT 灵活加载mat文件
%
%   用法：
%     load_mat(filepath)                    % 完整路径
%     load_mat(filename, folder)            % 文件名 + 所在文件夹
%     load_mat(filename, date)              % 文件名 + 日期（使用默认目录结构）
%     load_mat(filename, 'gt')              % 文件名 + 'gt'（从 pwd/data/gt/mat 加载）
%     load_mat(..., 'var', varname)         % 指定要提取的变量名
%
%   示例：
%     A = load_mat('D:/data/test.mat')
%     A = load_mat('test', 'D:/data/')
%     A = load_mat('spectrum', '20241225')
%     A = load_mat('led_0711', 'gt')        % 从当前目录下的 ./data/gt/mat 加载

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
        arg2 = to_path(varargin{2});  % 文件夹、日期或特殊关键字
        
        if is_path(arg2)
            % arg2 是文件夹路径
            filepath = fullfile(arg2, arg1);
        else
            % arg2 可能是日期或特殊关键字（如 'gt'）
            % 基于当前工作目录 pwd
            base_dir = pwd;
            
            % 尝试多个可能的路径
            possible_paths = {
                fullfile(base_dir, 'data', arg2, 'mat', arg1)      % ./data/gt/mat/
                fullfile(base_dir, 'data', 'mat', arg2, arg1)      % ./data/mat/gt/
                fullfile(base_dir, 'data', arg2, arg1)             % ./data/gt/
                fullfile(base_dir, arg2, 'mat', arg1)              % ./gt/mat/
                fullfile(base_dir, arg2, arg1)                     % ./gt/
            };
            
            % 补全 .mat 扩展名后检查
            filepath = '';
            for i = 1:length(possible_paths)
                test_path = possible_paths{i};
                if ~endsWith(test_path, '.mat', 'IgnoreCase', true)
                    test_path = [test_path, '.mat'];
                end
                if isfile(test_path)
                    filepath = test_path;
                    break;
                end
            end
            
            % 如果都找不到，使用第一个路径（让后续报错）
            if isempty(filepath)
                filepath = possible_paths{1};
            end
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
    p = char(s);
    p = strrep(p, '\', '/');
end

function tf = is_path(s)
    s = char(s);
    has_separator = contains(s, '/') || contains(s, '\');
    has_drive = (length(s) >= 2 && s(2) == ':');
    starts_with_slash = startsWith(s, '/') || startsWith(s, '~');
    
    tf = has_separator || has_drive || starts_with_slash || isfolder(s);
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
    
    fprintf('\n========== load_mat 错误 ==========\n');
    fprintf('找不到: %s%s\n', name, ext);
    fprintf('完整路径: %s\n', filepath);
    fprintf('当前工作目录: %s\n', pwd);
    
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
    
    error('load_mat:fileNotFound', '文件不存在: %s', strrep(filepath, '\', '/'));
end
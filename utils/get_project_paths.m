function [mat_path, base_path] = get_project_paths()
% GET_PROJECT_PATHS 自动检测项目路径（适配多台电脑）
%
% 用法：
%   [mat_path, base_path] = get_project_paths()

    % 定义可能的根路径
    possible_roots = {
        'X:/Github/My-Repository/My-Graduation'
        'W:/Github/My-Repository/My-Graduation'
        'D:/Github/My-Repository/My-Graduation'
        'C:/Users/YourName/Github/My-Repository/My-Graduation'  % 可以继续添加
        '~/Github/My-Repository/My-Graduation'  % Linux/Mac
    };
    
    % 自动检测哪个路径存在
    project_root = '';
    for i = 1:length(possible_roots)
        if isfolder(possible_roots{i})
            project_root = possible_roots{i};
            break;
        end
    end
    
    % 如果都不存在，尝试从当前脚本位置推断
    if isempty(project_root)
        % 获取调用此函数的脚本路径
        stack = dbstack('-completenames');
        if numel(stack) >= 2
            script_path = fileparts(stack(2).file);
            % 向上查找包含 'data/mat' 的目录
            test_path = script_path;
            for j = 1:5  % 最多向上5层
                if isfolder(fullfile(test_path, 'data', 'mat'))
                    project_root = test_path;
                    break;
                end
                [test_path, ~, ~] = fileparts(test_path);
            end
        end
    end
    
    % 仍然没找到，报错
    if isempty(project_root)
        error('找不到项目根目录，请检查路径配置或手动指定');
    end
    
    % 构建子路径
    mat_path = fullfile(project_root, 'data', 'mat');
    base_path = fullfile(project_root, 'paper-02', 'data', '1222');
    
    % 验证路径存在
    if ~isfolder(mat_path)
        warning('mat路径不存在: %s', mat_path);
    end
    if ~isfolder(base_path)
        warning('数据路径不存在: %s', base_path);
    end
    
    fprintf('项目根目录: %s\n', project_root);
end
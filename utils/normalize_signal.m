function [y_norm, norm_params] = normalize_signal(y, method)
% NORMALIZE_SIGNAL 归一化时域信号，用于E2E网络训练
%
% 输入：
%   y      - 原始时域信号 (N×1)
%   method - 归一化方法:
%            'zscore'  : 零均值、单位方差 (默认，推荐)
%            'minmax'  : 归一化到 [0, 1]
%            'ac_only' : 只去直流，保留原始AC幅度
%            'ac_std'  : 去直流，AC部分归一化到单位方差
%
% 输出：
%   y_norm      - 归一化后的信号
%   norm_params - 归一化参数（用于反归一化）
%
% 使用示例：
%   [y_norm, params] = normalize_signal(y, 'zscore');
%   y_recover = denormalize_signal(y_norm, params);

    if nargin < 2 || isempty(method)
        method = 'zscore';
    end
    
    norm_params.method = method;
    norm_params.mean = mean(y);
    norm_params.std = std(y);
    norm_params.min = min(y);
    norm_params.max = max(y);
    
    switch lower(method)
        case 'zscore'
            % 零均值、单位方差（最推荐，对网络友好）
            y_norm = (y - norm_params.mean) / norm_params.std;
            
        case 'minmax'
            % 归一化到 [0, 1]
            y_norm = (y - norm_params.min) / (norm_params.max - norm_params.min);
            
        case 'ac_only'
            % 只去直流，保留AC幅度
            y_norm = y - norm_params.mean;
            
        case 'ac_std'
            % 去直流，AC归一化到单位方差
            y_ac = y - norm_params.mean;
            norm_params.ac_std = std(y_ac);
            y_norm = y_ac / norm_params.ac_std;
            
        otherwise
            error('未知的归一化方法: %s', method);
    end
end

function y_recover = denormalize_signal(y_norm, norm_params)
% DENORMALIZE_SIGNAL 反归一化信号
%
% 输入：
%   y_norm      - 归一化后的信号
%   norm_params - 归一化参数（来自 normalize_signal）
%
% 输出：
%   y_recover   - 恢复的原始尺度信号

    switch lower(norm_params.method)
        case 'zscore'
            y_recover = y_norm * norm_params.std + norm_params.mean;
            
        case 'minmax'
            y_recover = y_norm * (norm_params.max - norm_params.min) + norm_params.min;
            
        case 'ac_only'
            y_recover = y_norm + norm_params.mean;
            
        case 'ac_std'
            y_recover = y_norm * norm_params.ac_std + norm_params.mean;
            
        otherwise
            error('未知的归一化方法: %s', norm_params.method);
    end
end
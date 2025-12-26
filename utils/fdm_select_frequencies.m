function [freqs, info] = fdm_select_frequencies(K, varargin)
% FDM_SELECT_FREQUENCIES 自动选择满足FDM约束的调制频率
%
% 四条原则：
%   1. 频率可分辨：|fi - fj| > Δf
%   2. 谐波规避：fj ≠ n·fi (n=2,3,4,5)
%   3. 差频规避：|fi - fj| ≠ fk
%   4. 合频规避：fi + fj ≠ fk
%
% 语法:
%   freqs = fdm_select_frequencies(K)
%   freqs = fdm_select_frequencies(K, 'T', 100e-6, 'FreqMin', 50e3)
%   [freqs, info] = fdm_select_frequencies(K, ...)
%
% 输入:
%   K           - 需要的频率数量（LED数量）
%
% 可选参数:
%   'T'         - 采样时间 (默认: 100e-6 = 100μs)
%   'FreqMin'   - 最小频率Hz (默认: 50e3)
%   'FreqMax'   - 最大频率Hz (默认: 500e3)
%   'Harmonics' - 需规避的谐波阶数 (默认: [2,3,4,5])
%   'Verbose'   - 是否打印详情 (默认: false)
%
% 输出:
%   freqs       - 选中的频率数组 [1 x K] (Hz)
%   info        - 结构体，包含详细信息
%
% 示例:
%   % 选择12个频率
%   freqs = fdm_select_frequencies(12);
%
%   % 自定义参数
%   freqs = fdm_select_frequencies(10, 'T', 200e-6, 'FreqMin', 100e3);
%
%   % 获取详细信息
%   [freqs, info] = fdm_select_frequencies(12, 'Verbose', true);
%
% 作者: Claude
% 日期: 2024-12

    %% 解析参数
    p = inputParser;
    addRequired(p, 'K', @(x) isnumeric(x) && x > 0);
    addParameter(p, 'T', 100e-6, @isnumeric);           % 采样时间
    addParameter(p, 'FreqMin', 50e3, @isnumeric);       % 最小频率
    addParameter(p, 'FreqMax', 500e3, @isnumeric);      % 最大频率
    addParameter(p, 'Harmonics', [2,3,4,5], @isnumeric);% 谐波阶数
    addParameter(p, 'Verbose', false, @islogical);      % 打印详情
    parse(p, K, varargin{:});
    
    opts = p.Results;
    T = opts.T;
    f_min = opts.FreqMin;
    f_max = opts.FreqMax;
    harmonics = opts.Harmonics;
    verbose = opts.Verbose;
    
    % 频率分辨率
    delta_f = 1 / T;
    
    if verbose
        fprintf('============================================================\n');
        fprintf('FDM频率自动选择\n');
        fprintf('============================================================\n');
        fprintf('参数: K=%d, T=%.0fμs, df=%.0fkHz, 范围=[%.0f,%.0f]kHz\n', ...
            K, T*1e6, delta_f/1e3, f_min/1e3, f_max/1e3);
    end
    
    %% 贪婪搜索
    f_candidates = f_min:delta_f:f_max;
    f_selected = [];
    
    for f = f_candidates
        if isempty(f_selected)
            f_selected = f;
            continue;
        end
        
        if ~check_constraints(f, f_selected, delta_f, harmonics)
            continue;
        end
        
        f_selected = [f_selected, f];
        if length(f_selected) >= K
            break;
        end
    end
    
    %% 检查结果
    if length(f_selected) < K
        warning('只找到 %d 个满足约束的频率（需要 %d 个）', length(f_selected), K);
        warning('建议: 增大FreqMax 或 减小T（增大df）');
    end
    
    freqs = f_selected;
    
    %% 构建输出信息
    info.K = length(freqs);
    info.T = T;
    info.delta_f = delta_f;
    info.freq_min = min(freqs);
    info.freq_max = max(freqs);
    info.freq_range = [f_min, f_max];
    info.harmonics = harmonics;
    info.intervals = diff(freqs);
    info.gcd = compute_gcd(freqs);
    
    % 验证约束
    [info.all_pass, info.violations] = verify_all_constraints(freqs, delta_f, harmonics);
    
    % 推荐采样参数
    info.recommended_Fs = max(freqs) * 2.5;  % 过采样2.5倍
    info.recommended_N = round(info.recommended_Fs / info.gcd);
    info.recommended_df = info.gcd;
    
    if verbose
        fprintf('\n选中频率 (kHz):\n  ');
        fprintf('%.0f ', freqs/1e3);
        fprintf('\n\n');
        fprintf('频率GCD: %.0f kHz\n', info.gcd/1e3);
        fprintf('推荐采样: Fs=%.2fMHz, N=%d, df=%.0fkHz\n', ...
            info.recommended_Fs/1e6, info.recommended_N, info.recommended_df/1e3);
        fprintf('约束验证: %s\n', bool2str(info.all_pass));
    end
end

%% ==================== 辅助函数 ====================

function pass = check_constraints(f, f_selected, delta_f, harmonics)
    % 检查新频率f是否满足所有约束
    pass = true;
    
    % 原则1: 频率可分辨
    for fi = f_selected
        if abs(f - fi) <= delta_f
            pass = false;
            return;
        end
    end
    
    % 原则2: 谐波规避
    for fi = f_selected
        for n = harmonics
            if abs(f - n*fi) < delta_f/2 || abs(fi - n*f) < delta_f/2
                pass = false;
                return;
            end
        end
    end
    
    % 原则3: 差频规避
    for fi = f_selected
        beat = abs(f - fi);
        for fj = f_selected
            if abs(beat - fj) < delta_f/2
                pass = false;
                return;
            end
        end
        if abs(beat - f) < delta_f/2
            pass = false;
            return;
        end
    end
    
    % 原则4: 合频规避
    for fi = f_selected
        sum_f = f + fi;
        for fj = f_selected
            if abs(sum_f - fj) < delta_f/2
                pass = false;
                return;
            end
        end
        if abs(sum_f - f) < delta_f/2
            pass = false;
            return;
        end
    end
end

function [all_pass, violations] = verify_all_constraints(freqs, delta_f, harmonics)
    % 验证所有约束
    K = length(freqs);
    violations = 0;
    
    % 原则1
    for i = 1:K
        for j = i+1:K
            if abs(freqs(i) - freqs(j)) <= delta_f
                violations = violations + 1;
            end
        end
    end
    
    % 原则2
    for i = 1:K
        for j = 1:K
            if i ~= j
                for n = harmonics
                    if abs(freqs(j) - n*freqs(i)) < delta_f/2
                        violations = violations + 1;
                    end
                end
            end
        end
    end
    
    % 原则3
    for i = 1:K
        for j = i+1:K
            beat = abs(freqs(i) - freqs(j));
            for k = 1:K
                if abs(beat - freqs(k)) < delta_f/2
                    violations = violations + 1;
                end
            end
        end
    end
    
    % 原则4
    for i = 1:K
        for j = i+1:K
            sum_f = freqs(i) + freqs(j);
            for k = 1:K
                if abs(sum_f - freqs(k)) < delta_f/2
                    violations = violations + 1;
                end
            end
        end
    end
    
    all_pass = (violations == 0);
end

function g = compute_gcd(freqs)
    % 计算所有频率的最大公约数
    freqs_int = round(freqs);
    g = freqs_int(1);
    for i = 2:length(freqs_int)
        g = gcd(g, freqs_int(i));
    end
end

function s = bool2str(b)
    if b
        s = '✓ 全部通过';
    else
        s = '✗ 存在冲突';
    end
end

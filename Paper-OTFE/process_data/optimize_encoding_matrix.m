%% encoding_optimize：优化编码矩阵（多次初始化版本）
clear;
clc;
%% step 1: 读取原始光谱矩阵
wav = linspace(400, 700, 31);
phi = load_mat("A_0115", "gt");
plot(wav, phi);
%% 
optimize_encoding_matrix_multi(phi)

%% 
function optimize_encoding_matrix_multi(phi)
    % ================= 设置参数 =================
    M = 12;             % LED 通道数 (Phi 的行数)
    N = 31;             % 光谱采样数 (Phi 的列数)
    K = 6;              % 测量次数 (E 的行数)
    N_sample = 1e6;     % 每次运行的采样次数
    N_runs = 10;        % 独立运行次数
    
    % ================= 1. 数据准备 =================
    if nargin < 1 || isempty(phi)
        if evalin('base', 'exist(''phi'', ''var'')')
            phi = evalin('base', 'phi');
            fprintf('已加载工作区中的 phi 矩阵。\n');
        else
            error('请提供 phi 矩阵！');
        end
    end
    
    % 检查维度
    [rows_phi, cols_phi] = size(phi);
    if rows_phi ~= M || cols_phi ~= N
        error('Phi 矩阵维度不符合预期，应为 %dx%d', M, N);
    end

    % ================= 2. 初始化全局最优变量 =================
    global_min_corr = inf;
    global_best_E = zeros(K, M);
    all_runs_results = zeros(N_runs, 1);  % 记录每次运行的最优值
    all_loss_history = zeros(N_sample, N_runs);  % 记录所有收敛曲线
    
    fprintf('========================================\n');
    fprintf('开始 %d 次独立运行，每次 %d 采样\n', N_runs, N_sample);
    fprintf('========================================\n\n');
    
    total_tic = tic;
    
    % ================= 3. 多次独立运行 =================
    for run = 1:N_runs
        fprintf('--- 第 %d/%d 次运行 ---\n', run, N_runs);
        run_tic = tic;
        
        % 本次运行的局部最优
        local_min_corr = inf;
        local_best_E = zeros(K, M);
        loss_history = zeros(N_sample, 1);
        
        % 蒙特卡洛搜索
        for i = 1:N_sample
            % A. 生成随机二值矩阵 E
            E_curr = randi([0, 1], K, M);
            
            % 确保没有全零行
            while any(sum(E_curr, 2) == 0)
                E_curr = randi([0, 1], K, M);
            end
            
            % B. 计算传感矩阵 A
            A = E_curr * phi;
            
            % C. 计算皮尔逊相关系数矩阵
            R = corrcoef(A');
            
            % D. 计算目标函数值
            abs_R = abs(R);
            abs_R(logical(eye(size(abs_R)))) = 0;
            sum_corr = sum(abs_R(:));
            num_off_diagonal = K * (K - 1);
            current_avg_corr = sum_corr / num_off_diagonal;
            
            % E. 更新局部最优
            if current_avg_corr < local_min_corr
                local_min_corr = current_avg_corr;
                local_best_E = E_curr;
            end
            
            loss_history(i) = local_min_corr;
        end
        
        run_time = toc(run_tic);
        
        % 记录本次运行结果
        all_runs_results(run) = local_min_corr;
        all_loss_history(:, run) = loss_history;
        
        fprintf('  本次最优相关系数: %.5f, 耗时: %.1f 秒\n', local_min_corr, run_time);
        
        % 更新全局最优
        if local_min_corr < global_min_corr
            global_min_corr = local_min_corr;
            global_best_E = local_best_E;
            fprintf('  *** 发现新的全局最优！ ***\n');
        end
        fprintf('\n');
    end
    
    total_time = toc(total_tic);
    
    % ================= 4. 结果统计与展示 =================
    fprintf('========================================\n');
    fprintf('优化完成！总耗时: %.1f 秒\n', total_time);
    fprintf('========================================\n\n');
    
    fprintf('各次运行结果:\n');
    for run = 1:N_runs
        marker = '';
        if all_runs_results(run) == global_min_corr
            marker = ' <-- 最优';
        end
        fprintf('  第 %2d 次: %.5f%s\n', run, all_runs_results(run), marker);
    end
    
    fprintf('\n统计信息:\n');
    fprintf('  最优值: %.5f\n', min(all_runs_results));
    fprintf('  最差值: %.5f\n', max(all_runs_results));
    fprintf('  平均值: %.5f\n', mean(all_runs_results));
    fprintf('  标准差: %.5f\n', std(all_runs_results));
    
    fprintf('\n全局最佳编码矩阵 E (%dx%d):\n', K, M);
    disp(global_best_E);
    
    % ================= 5. 可视化 =================
    figure('Position', [100, 100, 1200, 400]);
    
    % 子图1：所有收敛曲线
    subplot(1, 3, 1);
    plot(all_loss_history, 'LineWidth', 0.8);
    hold on;
    % 找到最优的那次运行并高亮
    [~, best_run_idx] = min(all_runs_results);
    plot(all_loss_history(:, best_run_idx), 'k-', 'LineWidth', 2);
    hold off;
    title('所有运行的收敛曲线');
    xlabel('采样次数');
    ylabel('平均相关系数');
    legend_str = arrayfun(@(x) sprintf('Run %d', x), 1:N_runs, 'UniformOutput', false);
    legend_str{best_run_idx} = [legend_str{best_run_idx} ' (最优)'];
    legend(legend_str, 'Location', 'northeast', 'FontSize', 7);
    grid on;
    
    % 子图2：各次运行最终结果柱状图
    subplot(1, 3, 2);
    bar(all_runs_results);
    hold on;
    bar(best_run_idx, all_runs_results(best_run_idx), 'FaceColor', [0.8, 0.2, 0.2]);
    yline(mean(all_runs_results), 'r--', sprintf('均值=%.4f', mean(all_runs_results)));
    hold off;
    title('各次运行最优值');
    xlabel('运行次数');
    ylabel('最优相关系数');
    grid on;
    
    % 子图3：最优传感矩阵相关系数热力图
    subplot(1, 3, 3);
    A_best = global_best_E * phi;
    R_best = corrcoef(A_best');
    imagesc(abs(R_best));
    colorbar;
    title(sprintf('最优A的相关系数 (Avg=%.4f)', global_min_corr));
    axis square;
    xlabel('测量索引');
    ylabel('测量索引');
    
    sgtitle(sprintf('编码矩阵优化结果 (%d次运行, 每次%d采样)', N_runs, N_sample));
    
    % ================= 6. 保存结果 =================
    % 保存到工作区
    assignin('base', 'best_E', global_best_E);
    assignin('base', 'min_avg_corr', global_min_corr);
    assignin('base', 'all_runs_results', all_runs_results);
    assignin('base', 'all_loss_history', all_loss_history);
    
    % 保存到文件
    save_filename = sprintf('encoding_opt_result_%s.mat', datestr(now, 'yyyymmdd_HHMMSS'));
    save(save_filename, 'global_best_E', 'global_min_corr', 'all_runs_results', 'all_loss_history', 'phi');
    fprintf('\n结果已保存到: %s\n', save_filename);
end
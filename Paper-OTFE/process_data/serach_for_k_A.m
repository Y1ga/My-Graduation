%% 改进版: LED光谱响应系统标定
% 主要改进:
% 1. 统一目标函数和评估函数
% 2. 优化相对比例而非绝对值
% 3. 多策略组合优化
% 4. 自适应搜索范围
clear; clc;

%% 加载数据
A0 = load_mat("led_0711", "gt")';
colorchecker = load_mat("colorchecker_gt", "gt");

path = "./data/PD-01-04/";
k_A_init = read_rigol_wfm(path+"新建文件-1.wfm", 1e9, 100e-5);
y_measured_all = zeros(12, 24);
for idx = 1:24
    y_measured_all(:, idx) = read_rigol_wfm(path+"新建文件"+num2str(idx)+".wfm", 1e9, 100e-5);
end

% fprintf('初始误差: %.4f%%\n', calc_unified_error(k_A_init, A0, colorchecker, y_measured_all));

%% 方法1: 优化相对比例 (固定第一个通道)
fprintf('\n===== 方法1: 相对比例优化 =====\n');

% 归一化为相对比例
k_ratio_init = k_A_init / k_A_init(1);  % 第一个固定为1

% 只优化后11个参数
n_dim = 11;
ratio_init = k_ratio_init(2:end);

% 更大的搜索范围
lb = ratio_init * 0.1;
ub = ratio_init * 10;

% 目标函数: 输入11维比例，输出误差
obj_func = @(ratio) calc_unified_error([1; ratio(:)] * k_A_init(1), A0, colorchecker, y_measured_all);

% PSO优化
options_pso = struct();
options_pso.n_particles = 100;
options_pso.n_iterations = 200;
options_pso.w_start = 0.9;
options_pso.w_end = 0.4;
options_pso.c1 = 2.0;
options_pso.c2 = 2.0;

[ratio_pso, err_pso] = pso_optimize(obj_func, ratio_init, lb, ub, options_pso);
k_A_ratio = [1; ratio_pso] * k_A_init(1);
fprintf('相对比例PSO误差: %.4f%%\n', err_pso);

%% 方法2: 逐通道优化
fprintf('\n===== 方法2: 逐通道优化 =====\n');

k_A_channel = k_A_init;
for ch = 1:12
    % 对每个通道单独优化
    best_k = k_A_channel(ch);
    best_err = calc_unified_error(k_A_channel, A0, colorchecker, y_measured_all);
    
    % 细粒度搜索
    for scale = linspace(0.1, 10, 1000)
        k_A_test = k_A_channel;
        k_A_test(ch) = k_A_init(ch) * scale;
        err = calc_unified_error(k_A_test, A0, colorchecker, y_measured_all);
        if err < best_err
            best_err = err;
            best_k = k_A_test(ch);
        end
    end
    k_A_channel(ch) = best_k;
end
err_channel = calc_unified_error(k_A_channel, A0, colorchecker, y_measured_all);
fprintf('逐通道优化误差: %.4f%%\n', err_channel);

%% 方法3: CMA-ES (协方差矩阵自适应进化策略)
fprintf('\n===== 方法3: CMA-ES =====\n');

% 在对数空间优化 (确保正值)
log_k_init = log(k_A_init);
sigma = 0.5;  % 初始步长

[log_k_cmaes, err_cmaes] = cmaes_optimize(@(log_k) calc_unified_error(exp(log_k), A0, colorchecker, y_measured_all), ...
                                           log_k_init, sigma, 200);
k_A_cmaes = exp(log_k_cmaes);
fprintf('CMA-ES误差: %.4f%%\n', err_cmaes);

%% 方法4: 混合优化 (全局 + 局部)
fprintf('\n===== 方法4: 混合优化 =====\n');

% 先用DE全局搜索
lb_full = k_A_init * 0.05;
ub_full = k_A_init * 20;

options_de = struct();
options_de.pop_size = 100;
options_de.max_gen = 150;
options_de.F = 0.8;
options_de.CR = 0.9;

obj_func_full = @(k_A) calc_unified_error(k_A, A0, colorchecker, y_measured_all);
[k_A_de, ~] = de_optimize(obj_func_full, k_A_init, lb_full, ub_full, options_de);

% 再用Nelder-Mead局部精修
options_nm = optimset('Display', 'off', 'MaxIter', 1000, 'TolFun', 1e-8);
k_A_hybrid = fminsearch(@(k) calc_unified_error(abs(k), A0, colorchecker, y_measured_all), k_A_de, options_nm);
k_A_hybrid = abs(k_A_hybrid);
err_hybrid = calc_unified_error(k_A_hybrid, A0, colorchecker, y_measured_all);
fprintf('混合优化误差: %.4f%%\n', err_hybrid);

%% 方法5: 加权误差优化 (重点降低最大误差)
fprintf('\n===== 方法5: 加权优化(降低最大误差) =====\n');

% 使用加权目标函数
obj_func_weighted = @(k_A) calc_weighted_error(k_A, A0, colorchecker, y_measured_all);
[k_A_weighted, ~] = de_optimize(obj_func_weighted, k_A_init, lb_full, ub_full, options_de);
k_A_weighted = fminsearch(@(k) calc_weighted_error(abs(k), A0, colorchecker, y_measured_all), k_A_weighted, options_nm);
k_A_weighted = abs(k_A_weighted);
err_weighted = calc_unified_error(k_A_weighted, A0, colorchecker, y_measured_all);
err_weighted_max = max(calc_err_list_unified(k_A_weighted, A0, colorchecker, y_measured_all)) * 100;
fprintf('加权优化: 平均%.4f%%, 最大%.4f%%\n', err_weighted, err_weighted_max);

%% 结果对比
fprintf('\n========== 结果对比 ==========\n');
methods = {'初始值', '相对比例PSO', '逐通道', 'CMA-ES', '混合优化', '加权优化'};
k_A_all = {k_A_init, k_A_ratio, k_A_channel, k_A_cmaes, k_A_hybrid, k_A_weighted};

results = zeros(6, 3);  % [平均误差, 最大误差, 最小误差]
for i = 1:6
    err_list = calc_err_list_unified(k_A_all{i}, A0, colorchecker, y_measured_all);
    results(i, :) = [mean(err_list), max(err_list), min(err_list)] * 100;
end

fprintf('%-12s  平均%%    最大%%    最小%%\n', '方法');
fprintf('----------------------------------------\n');
for i = 1:6
    fprintf('%-12s  %6.2f   %6.2f   %6.2f\n', methods{i}, results(i,1), results(i,2), results(i,3));
end

% 选择最佳
[~, best_method] = min(results(:,1));
k_A_best = k_A_all{best_method};
fprintf('\n最佳方法: %s\n', methods{best_method});

%% 详细分析最佳结果
fprintf('\n===== 最佳结果详细分析 =====\n');
err_list_best = calc_err_list_unified(k_A_best, A0, colorchecker, y_measured_all);
[sorted_err, sorted_idx] = sort(err_list_best, 'descend');

fprintf('各色卡误差 (从大到小):\n');
for i = 1:24
    fprintf('色卡%2d: %6.2f%%\n', sorted_idx(i), sorted_err(i)*100);
end
fprintf('\n统计: 平均%.2f%%, 最大%.2f%%, 标准差%.2f%%\n', ...
    mean(err_list_best)*100, max(err_list_best)*100, std(err_list_best)*100);

fprintf('\n最佳k_A:\n');
disp(k_A_best');

fprintf('\n相对于初始值的变化:\n');
change_ratio = k_A_best ./ k_A_init;
for i = 1:12
    fprintf('通道%2d: %.4f (%.1f%%)\n', i, change_ratio(i), (change_ratio(i)-1)*100);
end

% 保存
k_A = k_A_best;
save('k_A_calibrated_improved.mat', 'k_A');
fprintf('\n结果已保存到 k_A_calibrated_improved.mat\n');
%% 
save_mat(k_A_best, "gt");
% save_mat(k_A, "gt");
%% ==================== 辅助函数 ====================

%% 统一的误差计算 (使用相同的缩放方式)
function err = calc_unified_error(k_A, A0, colorchecker, y_measured_all)
    if any(k_A <= 0)
        err = 1e10;
        return;
    end
    err_list = calc_err_list_unified(k_A, A0, colorchecker, y_measured_all);
    err = mean(err_list) * 100;
end

function err_list = calc_err_list_unified(k_A, A0, colorchecker, y_measured_all)
    A = k_A .* A0;
    err_list = zeros(24, 1);
    for idx = 1:24
        x = colorchecker(:, idx);
        y_theory = A * x;
        y_meas = y_measured_all(:, idx);
        
        % 使用最小二乘缩放 (统一方式)
        k_scale = (y_meas' * y_theory) / (y_theory' * y_theory + 1e-10);
        y_scaled = y_theory * k_scale;
        
        % 相对误差
        rel_error = abs(y_meas - y_scaled) ./ (abs(y_meas) + 1e-10);
        err_list(idx) = mean(rel_error);
    end
end

%% 加权误差 (惩罚大误差)
function err = calc_weighted_error(k_A, A0, colorchecker, y_measured_all)
    if any(k_A <= 0)
        err = 1e10;
        return;
    end
    err_list = calc_err_list_unified(k_A, A0, colorchecker, y_measured_all);
    
    % 加权: 平均 + 最大值惩罚
    err = mean(err_list) + 0.5 * max(err_list) + 0.1 * std(err_list);
    err = err * 100;
end

%% PSO优化器 (改进版)
function [x_best, f_best] = pso_optimize(obj_func, x_init, lb, ub, options)
    n_particles = options.n_particles;
    n_iterations = options.n_iterations;
    n_dim = length(x_init);
    
    % 初始化
    particles = rand(n_particles, n_dim) .* (ub - lb)' + lb';
    particles(1, :) = x_init';  % 包含初始值
    velocities = zeros(n_particles, n_dim);
    
    pbest = particles;
    pbest_scores = inf(n_particles, 1);
    
    for i = 1:n_particles
        pbest_scores(i) = obj_func(particles(i,:)');
    end
    [f_best, gbest_idx] = min(pbest_scores);
    gbest = particles(gbest_idx, :);
    
    v_max = ((ub(:) - lb(:)) * 0.2)';
    
    for iter = 1:n_iterations
        % 自适应惯性权重
        w = options.w_start - (options.w_start - options.w_end) * iter / n_iterations;
        
        for i = 1:n_particles
            r1 = rand(1, n_dim);
            r2 = rand(1, n_dim);
            
            velocities(i,:) = w * velocities(i,:) + ...
                              options.c1 * r1 .* (pbest(i,:) - particles(i,:)) + ...
                              options.c2 * r2 .* (gbest - particles(i,:));
            
            % 速度限制
            velocities(i,:) = max(min(velocities(i,:), v_max), -v_max);
            
            particles(i,:) = particles(i,:) + velocities(i,:);
            particles(i,:) = max(particles(i,:), lb');
            particles(i,:) = min(particles(i,:), ub');
            
            score = obj_func(particles(i,:)');
            
            if score < pbest_scores(i)
                pbest_scores(i) = score;
                pbest(i,:) = particles(i,:);
            end
            
            if score < f_best
                f_best = score;
                gbest = particles(i,:);
            end
        end
        
        if mod(iter, 50) == 0
            fprintf('  PSO Iter %3d: %.4f%%\n', iter, f_best);
        end
    end
    
    x_best = gbest';
end

%% DE优化器 (改进版)
function [x_best, f_best] = de_optimize(obj_func, x_init, lb, ub, options)
    pop_size = options.pop_size;
    max_gen = options.max_gen;
    n_dim = length(x_init);
    
    % 初始化
    pop = rand(pop_size, n_dim) .* (ub - lb)' + lb';
    pop(1, :) = x_init';
    
    fitness = zeros(pop_size, 1);
    for i = 1:pop_size
        fitness(i) = obj_func(pop(i,:)');
    end
    
    for gen = 1:max_gen
        % 自适应参数
        F = 0.5 + 0.3 * rand();
        CR = 0.8 + 0.2 * rand();
        
        for i = 1:pop_size
            % DE/best/1策略
            [~, best_idx] = min(fitness);
            
            idx = randperm(pop_size, 2);
            while any(idx == i) || any(idx == best_idx)
                idx = randperm(pop_size, 2);
            end
            
            mutant = pop(best_idx,:) + F * (pop(idx(1),:) - pop(idx(2),:));
            mutant = max(mutant, lb');
            mutant = min(mutant, ub');
            
            trial = pop(i,:);
            j_rand = randi(n_dim);
            for j = 1:n_dim
                if rand < CR || j == j_rand
                    trial(j) = mutant(j);
                end
            end
            
            trial_fitness = obj_func(trial');
            if trial_fitness < fitness(i)
                pop(i,:) = trial;
                fitness(i) = trial_fitness;
            end
        end
        
        if mod(gen, 50) == 0
            fprintf('  DE Gen %3d: %.4f%%\n', gen, min(fitness));
        end
    end
    
    [f_best, best_idx] = min(fitness);
    x_best = pop(best_idx,:)';
end

%% 简化版CMA-ES
function [x_best, f_best] = cmaes_optimize(obj_func, x_init, sigma, max_iter)
    n = length(x_init);
    lambda = 4 + floor(3 * log(n));  % 种群大小
    mu = floor(lambda / 2);          % 选择数量
    
    % 权重
    weights = log(mu + 0.5) - log(1:mu)';
    weights = weights / sum(weights);
    mueff = 1 / sum(weights.^2);
    
    % 学习率
    cc = (4 + mueff/n) / (n + 4 + 2*mueff/n);
    cs = (mueff + 2) / (n + mueff + 5);
    c1 = 2 / ((n + 1.3)^2 + mueff);
    cmu = min(1 - c1, 2 * (mueff - 2 + 1/mueff) / ((n + 2)^2 + mueff));
    damps = 1 + 2*max(0, sqrt((mueff-1)/(n+1)) - 1) + cs;
    
    % 初始化
    xmean = x_init;
    pc = zeros(n, 1);
    ps = zeros(n, 1);
    B = eye(n);
    D = ones(n, 1);
    C = eye(n);
    
    chiN = sqrt(n) * (1 - 1/(4*n) + 1/(21*n^2));
    
    f_best = obj_func(xmean);
    x_best = xmean;
    
    for iter = 1:max_iter
        % 采样
        arz = randn(n, lambda);
        arx = zeros(n, lambda);
        for k = 1:lambda
            arx(:, k) = xmean + sigma * B * (D .* arz(:, k));
        end
        
        % 评估
        arfitness = zeros(lambda, 1);
        for k = 1:lambda
            arfitness(k) = obj_func(arx(:, k));
        end
        
        % 排序
        [~, arindex] = sort(arfitness);
        
        % 更新最佳
        if arfitness(arindex(1)) < f_best
            f_best = arfitness(arindex(1));
            x_best = arx(:, arindex(1));
        end
        
        % 更新均值
        xold = xmean;
        xmean = arx(:, arindex(1:mu)) * weights;
        
        % 更新进化路径
        ps = (1 - cs) * ps + sqrt(cs * (2 - cs) * mueff) * (B \ (xmean - xold)) / sigma;
        hsig = norm(ps) / sqrt(1 - (1-cs)^(2*iter)) / chiN < 1.4 + 2/(n+1);
        pc = (1 - cc) * pc + hsig * sqrt(cc * (2 - cc) * mueff) * (xmean - xold) / sigma;
        
        % 更新协方差矩阵
        artmp = (arx(:, arindex(1:mu)) - xold) / sigma;
        C = (1 - c1 - cmu) * C + c1 * (pc * pc' + (1 - hsig) * cc * (2 - cc) * C) + ...
            cmu * artmp * diag(weights) * artmp';
        
        % 更新步长
        sigma = sigma * exp((cs / damps) * (norm(ps) / chiN - 1));
        
        % 更新B和D
        C = triu(C) + triu(C, 1)';
        [B, D] = eig(C);
        D = sqrt(diag(D));
        
        if mod(iter, 50) == 0
            fprintf('  CMA-ES Iter %3d: %.4f%%\n', iter, f_best);
        end
    end
end
clear; 
clc;
%% 
A0 = load_mat("led_0711", "gt")';
colorchecker = load_mat("colorchecker_gt", "gt");
idx = 10;
x = colorchecker(:, idx);

%% 
% -1,0是白板,
% 1~24对应24色卡
path = "./data/PD-01-04/";
duration = 350e-6;
sampling_rate = 50e7;
k_A = read_rigol_wfm(path+"新建文件-1.wfm", sampling_rate, duration);
y = read_rigol_wfm(path+"新建文件"+num2str(idx)+".wfm", sampling_rate, duration);
y = y ./ k_A;
y_theory = A0 * x;
%% 
beta = 1e0;
a = A0 * beta;
yy = y * beta;
x_P = opt_gd(A0 , yy);
wav = get_wav;
colorchecker = load_mat("colorchecker","gt");
x_gt = colorchecker(:,idx);
x_gt = x_gt * max(x_P,[],'all') / max(x_gt,[],'all');
plot(wav,x_P,wav,x_gt);
legend('预测','真实');
ylim([0,1]);
rmse = RMSE(x_P, x_gt);
disp(rmse);
rgb_P = spec2rgb_simple(x_P);
rgb_gt = spec2rgb_simple(x_gt);
function x = opt_gd(A, y, beta)
    if nargin == 2
        % 正则化参数
        beta1 = 0e-3;
        beta2 = 5e-2;
        % beta2 = 0e-1;
        beta3 = 1e-0;
    else
        beta1 = beta(1);
        beta2 = beta(2);
        beta3 = beta(3);
    end
    % 数据
    % A = randn(100, 50); % 100 个样本，50 个特征
    % y = randn(100, 1);  % 100 个样本的响应
    x0 = rand(size(A, 2), 1);  % 初始猜测值



    % 学习率
    alpha = 0.006;

    % 最大迭代次数
    max_iter = 1e5;

    % 收敛阈值
    tol = 1e-6;

    % 初始化
    x = x0;
    iter = 0;

    % 差分算子 D
    D = diff(eye(length(x))); % 50x50 单位矩阵的差分

    % 梯度下降迭代
    while iter < max_iter
        % 计算数据拟合项的梯度
        residual = A * x - y;
        grad_fit = A' * residual / norm(residual);

        % 计算 L1 正则化项的梯度
        grad_l1 = beta1 * sign(x);
        % 
        % 计算 L2 正则化项的梯度
        grad_l2 = beta2 * x / norm(x);
        % 
        % % % 计算 TV 正则化项的梯度
        diff_x = D * x;
        tmp = sum(diff_x .^ 2);
        grad_tv = beta3 * (D' * diff_x) / sqrt(sum(diff_x .^ 2));

        % 总梯度
        grad = grad_fit + grad_l1 + grad_l2 + grad_tv;
        % grad = grad_fit;
        % 更新参数
        x_new = x - alpha * grad;
        % 投影操作：限制 x_new 在 [0, 1] 范围内
        % x_new = max(0, min(1, x_new));
        x_new = max(0, min(1, x_new));

        % 检查收敛条件
        if norm(x_new - x) < tol
            break;
        end

        % 更新参数
        x = x_new;
        iter = iter + 1;
    end


    % 输出结果
    disp('优化解:');
    disp(x);
    disp('目标函数值:');
    disp(norm(A * x - y, 2) + beta1 * norm(x, 1) + beta2 * norm(x, 2) + beta3 * sqrt(sum(diff(x) .^ 2)));
    disp('迭代次数:');
    disp(iter);
end
%% 
function [amps, freq_detected, volt_div, v_min, v_max, signal] = read_rigol_wfm(filename, fs, duration)
% READ_RIGOL_WFM 读取Rigol示波器WFM文件并提取FFT幅值
%
% 输入:
%   filename - WFM文件路径
%   fs       - 目标采样率 (默认 1e9，即不降采样)
%   duration - 截取时长 (默认 inf)
%
% 输出:
%   amps         - 12个LED基频的FFT幅值
%   freq_detected - 检测到的实际频率
%   volt_div     - 示波器V/div设置
%   v_min        - 信号最小电压
%   v_max        - 信号最大电压
%   signal       - 时域信号（已去DC）

    % 原始采样率（Rigol示波器固定1GHz）
    fs_original = 1e9;
    
    if nargin < 2 || isempty(fs), fs = fs_original; end
    if nargin < 3 || isempty(duration), duration = inf; end
    
    led_freqs = [30, 50, 70, 110, 130, 170, 190, 230, 290, 310, 370, 410];
    n_leds = length(led_freqs);
    
    fid = fopen(filename, 'rb');
    if fid == -1, error('无法打开文件: %s', filename); end
    
    % 读取真实V/div (0x84)
    fseek(fid, hex2dec('84'), 'bof');
    volt_div = fread(fid, 1, 'float32');
    
    % 读取电压刻度因子 (0xA0)
    fseek(fid, hex2dec('A0'), 'bof');
    volt_scale = fread(fid, 1, 'float32');
    
    % 读取数据
    fseek(fid, 3334, 'bof');
    raw_data = fread(fid, inf, 'uint8');
    fclose(fid);
    
    % 转换为电压（修正：乘以 volt_scale * volt_div）
    signal = (double(raw_data) - 128) * volt_scale * volt_div;
    
    % 截取指定时长（基于原始采样率）
    if isfinite(duration)
        n_use = min(round(duration * fs_original), length(signal));
        signal = signal(1:n_use);
    end
    
    % 降采样（如果目标采样率低于原始采样率）
    if fs < fs_original
        downsample_factor = round(fs_original / fs);
        signal = signal(1:downsample_factor:end);
    end
    
    % 去除DC
    signal = signal - mean(signal);
    
    % 输出电压范围
    v_min = min(signal);
    v_max = max(signal);
    
    % FFT（使用目标采样率计算频率轴）
    n_fft = 2^nextpow2(length(signal));
    fft_result = fft(signal, n_fft);
    fft_mag = abs(fft_result(1:n_fft/2));
    freq_axis = (0:n_fft/2-1) * fs / n_fft / 1e3;  % kHz
    freq_resolution = fs / n_fft / 1e3;
    
    % 提取幅度
    amps = zeros(n_leds, 1);
    freq_detected = zeros(n_leds, 1);
    search_width = max(5, freq_resolution * 2);
    
    % 奈奎斯特频率
    nyquist = fs / 2 / 1e3;  % kHz
    
    for i = 1:n_leds
        f_target = led_freqs(i);
        
        % 检查是否超过奈奎斯特频率
        if f_target >= nyquist
            amps(i) = NaN;
            freq_detected(i) = NaN;
            continue;
        end
        
        mask = (freq_axis >= f_target - search_width) & (freq_axis <= f_target + search_width);
        [max_val, max_idx] = max(fft_mag .* mask');
        amps(i) = max_val;
        freq_detected(i) = freq_axis(max_idx);
    end
end
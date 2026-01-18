function fft_data = plot_rigol_fft(filename, fs, duration, freq_max)
% PLOT_RIGOL_FFT 读取Rigol示波器wfm文件并绘制FFT频谱图
%
% 输入参数:
%   filename - wfm文件路径
%   fs       - 采样率 (默认 1e9 Hz)
%   duration - 截取时长 (默认 inf，即全部数据)
%   freq_max - 频谱显示的最大频率，单位kHz (默认 500 kHz)
%
% 输出参数:
%   fft_data - Nx2矩阵，第一列是频率(kHz)，第二列是幅值
%
% 示例:
%   data = plot_rigol_fft("./data/test.wfm", 1e9, 100e-5, 500);
%   freq = data(:,1);  % 频率
%   mag = data(:,2);   % 幅值

    if nargin < 2 || isempty(fs), fs = 1e9; end
    if nargin < 3 || isempty(duration), duration = inf; end
    if nargin < 4 || isempty(freq_max), freq_max = 500; end  % 默认500 kHz

    % 打开文件
    fid = fopen(filename, 'rb');
    if fid == -1, error('无法打开文件: %s', filename); end

    % 读取真实V/div (0x84)
    fseek(fid, hex2dec('84'), 'bof');
    volt_div = fread(fid, 1, 'float32');
    
    % 读取电压刻度因子 (0xA0)
    fseek(fid, hex2dec('A0'), 'bof');
    volt_scale = fread(fid, 1, 'float32');
    
    % 读取电压偏移 (0xA4)
    volt_offset = fread(fid, 1, 'float32');

    % 读取数据
    fseek(fid, 3334, 'bof');
    raw_data = fread(fid, inf, 'uint8');
    fclose(fid);

    % 转换为电压
    signal = (double(raw_data) - 128) * volt_scale + volt_offset;
    
    % 截取指定时长
    if isfinite(duration)
        n_use = min(round(duration * fs), length(signal));
        signal = signal(1:n_use);
    end

    % FFT
    signal_ac = signal - mean(signal);
    n_fft = 2^nextpow2(length(signal_ac));
    fft_result = fft(signal_ac, n_fft);
    fft_mag = abs(fft_result(1:n_fft/2));
    freq_axis = (0:n_fft/2-1) * fs / n_fft / 1e3;  % 转换为kHz

    % 乘以V/div得到绝对强度
    fft_mag = fft_mag * volt_div;

    % 截取0到freq_max kHz的范围
    valid_idx = freq_axis <= freq_max;
    freq_plot = freq_axis(valid_idx);
    mag_plot = fft_mag(valid_idx);

    % 输出结果：第一列频率，第二列幅值
    fft_data = [freq_plot(:), mag_plot(:)];

    % 绘图
    figure;
    plot(freq_plot, mag_plot, 'LineWidth', 1);
    xlabel('频率 (kHz)');
    ylabel('幅值');
    title(sprintf('FFT频谱 (0-%d kHz)', freq_max));
    xlim([0, freq_max]);
    grid on;

    % 标注LED频率位置
    led_freqs = [30, 50, 70, 110, 130, 170, 190, 230, 290, 310, 370, 410];
    hold on;
    for i = 1:length(led_freqs)
        if led_freqs(i) <= freq_max
            xline(led_freqs(i), '--r', sprintf('%d', led_freqs(i)), ...
                'LabelHorizontalAlignment', 'center', ...
                'LabelVerticalAlignment', 'bottom', ...
                'FontSize', 8, 'Alpha', 0.5);
        end
    end
    hold off;

    % 打印信息
    fprintf('文件: %s\n', filename);
    fprintf('V/div: %.4f V\n', volt_div);
    fprintf('信号长度: %d 点\n', length(signal));
    fprintf('FFT点数: %d\n', n_fft);
    fprintf('频率分辨率: %.3f kHz\n', fs / n_fft / 1e3);
    fprintf('输出数据: %d x 2 矩阵 [频率(kHz), 幅值]\n', size(fft_data, 1));
end
% ================== 科研绘图参数 ==================
lineWidth = 5.0;    % 线宽：已设为 5
% =================================================

lambda = 400:700;
figure('Color', 'w', 'Position', [100, 100, 1500, 350]);

% 中等饱和度学术色板 (清晰且稳重)
colors = {
    [0.12, 0.47, 0.71], ... % 深钢蓝 (Sample A)
    [0.20, 0.63, 0.17], ... % 森林绿 (Sample B)
    [0.89, 0.10, 0.11], ... % 砖红   (Sample C)
    [1.00, 0.50, 0.00], ... % 琥珀橘 (Sample D)
    [0.42, 0.24, 0.60]      % 皇家紫 (Sample E)
};

% 重新设计的配置 [幅度A, 中心mu, 宽度sig]
% 确保前三个双峰形态各异
configs = {
    % 1. 双峰：极端远距离 (420nm & 680nm) - 跨度最大，视觉最空
    [1.0, 420, 20;  0.9, 680, 25],           
    
    % 2. 双峰：标准中距离 (480nm & 620nm) - 修正：确保峰谷深度可见
    [0.9, 480, 25;  0.8, 620, 25],           
    
    % 3. 双峰：极度非对称 (450nm 窄高峰 & 580nm 宽矮峰)
    [1.0, 450, 15;  0.5, 580, 60],           
    
    % 4. 三峰：RGB 均衡分布
    [0.8, 450, 20;  0.9, 540, 25;  0.7, 640, 20], 
    
    % 5. 三峰：紧凑型连续起伏 (波浪感强)
    [0.7, 430, 30;  0.7, 510, 25;  1.0, 600, 40]  
};

titles = {'Sample A (Wide)', 'Sample B (Split)', 'Sample C (Asym)', ...
          'Sample D (Triple)', 'Sample E (Triple)'};

for i = 1:5
    cfg = configs{i};
    spec = zeros(size(lambda));
    
    for j = 1:size(cfg, 1)
        A   = cfg(j, 1);
        mu  = cfg(j, 2);
        sig = cfg(j, 3);
        spec = spec + A * exp(-(lambda - mu).^2 / (2 * sig^2));
    end
    
    subplot(1, 5, i);
    % 绘图：线宽为 5
    plot(lambda, spec, 'Color', colors{i}, 'LineWidth', lineWidth);
    
    % 标题
    title(titles{i}, 'FontName', 'Arial', 'FontSize', 11, 'FontWeight', 'bold');
    
    % 限制与隐藏
    ylim([0 max(spec)*1.3]); 
    axis off; 
end
%% 
% ================== 绘图参数 ==================
lineWidth = 5.0;    % 保持线宽为 5
% =============================================

% 定义时间轴
t = linspace(0, 2*pi, 1000);

figure('Color', 'w', 'Position', [100, 100, 1500, 350]);

% --- 新的低饱和度 (莫兰迪/粉灰调) 色板 ---
colors = {
    [0.50, 0.60, 0.70], ... % 灰蓝 (Dusty Blue)
    [0.55, 0.65, 0.55], ... % 鼠尾草绿 (Sage Green)
    [0.75, 0.55, 0.55], ... % 烟粉色 (Dusty Rose)
    [0.70, 0.65, 0.50], ... % 砂金 (Muted Gold)
    [0.65, 0.55, 0.70]      % 藕荷紫 (Muted Mauve)
};

titles = {'Low Sat A', 'Low Sat B', 'Low Sat C', ...
          'Low Sat D', 'Low Sat E'};

for i = 1:5
    subplot(1, 5, i);
    
    % 生成不同频率的正弦波
    freq = i + 1; 
    y = sin(freq * t);
    
    % 绘图：使用低饱和度颜色和线宽 5
    plot(t, y, 'Color', colors{i}, 'LineWidth', lineWidth);
    
    % 标题使用深灰色，避免纯黑突兀
    title(titles{i}, 'FontName', 'Arial', 'FontSize', 11, ...
          'FontWeight', 'bold', 'Color', [0.3 0.3 0.3]);
    
    % 设置范围并隐藏坐标轴
    ylim([-1.2 1.2]); 
    axis off; 
end
%% 
% ================== 科研绘图参数 ==================
lineWidth = 3.0;    % 线宽调整为 3
displayTime = 0.3;  % 保持 0.3 秒，波形更舒展
% =================================================

% 定义时间轴
fs = 2000;                      
t = 0:1/fs:displayTime;         

figure('Color', 'w', 'Position', [100, 100, 800, 500]);
hold on;

% 3 种低饱和度科研配色 (莫兰迪色系)
colors = [
    0.50, 0.60, 0.70; % 灰蓝
    0.55, 0.65, 0.55; % 鼠尾草绿
    0.75, 0.55, 0.55  % 烟粉
];

% 定义 3 个频率 (Hz)
frequencies = [3, 8, 15]; 

for i = 1:3
    f = frequencies(i);
    y = sin(2 * pi * f * t);
    
    % 叠加绘图：线宽为 3
    plot(t, y, 'Color', colors(i,:), 'LineWidth', lineWidth);
end

% 装饰与去坐标轴
title('Refined Sine Signals (LW=3)', 'FontName', 'Arial', 'FontSize', 13, ...
      'FontWeight', 'bold', 'Color', [0.3 0.3 0.3]);
      
ylim([-1.3 1.3]); 
axis off;        % 彻底隐藏坐标轴
hold off;
%% 
% ================== 绘图参数 ==================
lineWidth = 1.5;    % 线宽：1.5 (精细科研风格)
displayTime = 0.3;  % 时间范围：0.3 秒
% =============================================

% 定义时间轴
fs = 500;                      
t = 0:1/fs:displayTime;         
n = length(t);

% 生成随机高斯噪声
noise = randn(1, n);

figure('Color', 'w', 'Position', [100, 100, 800, 400]);

% 绘制深灰色噪声
% 使用中性灰色 [0.5, 0.5, 0.5]
plot(t, noise, 'Color', [0.5, 0.5, 0.5], 'LineWidth', lineWidth);

% 标题与格式化
title('Random Gray Noise (LW=1.5)', 'FontName', 'Arial', 'FontSize', 12, ...
      'FontWeight', 'normal', 'Color', [0.3, 0.3, 0.3]);

% 保持纯净：不要坐标轴
ylim([-4 4]); 
axis off;
%% 
% ================== 科研绘图参数 ==================
lwMain = 3.0;       % 主峰顶点线宽：3
lwNoise = 2.5;      % 噪声背景线宽：1.5
fs = 2000;          % 采样频率
T = 2.0;            % 信号时长
t = 0:1/fs:T-1/fs;  
% =================================================

% 1. 定义更高、更突出的主峰参数
main_freqs = [35, 85, 135];
main_amps  = [2.7, 3.2, 3.2]; 
morandi_colors = [
    0.45, 0.55, 0.70; % 莫兰迪蓝
    0.55, 0.65, 0.55; % 莫兰迪绿
    0.75, 0.55, 0.55  % 莫兰迪粉
];

% 2. 构建极密集的噪声环境 (约 1/4 幅度)
sig_main = main_amps(1)*sin(2*pi*main_freqs(1)*t) + ...
           main_amps(2)*sin(2*pi*main_freqs(2)*t) + ...
           main_amps(3)*sin(2*pi*main_freqs(3)*t);

% 极密集随机小峰 (180个，模拟繁琐干扰)
num_spurs = 180; 
spur_sig = zeros(size(t));
for k = 1:num_spurs
    rf = rand * 200; 
    ra = 0.5 + rand*0.3; 
    spur_sig = spur_sig + ra * sin(2*pi*rf*t + rand*2*pi);
end

% 叠加信号与细微白噪声
sig_total = sig_main + spur_sig + 0.15*randn(size(t));

% 3. 计算 FFT
L = length(sig_total);
Y = fft(sig_total);
P2 = abs(Y/L);
P = P2(1:L/2+1);
P(2:end-1) = 2*P(2:end-1);
f = fs*(0:(L/2))/L;

% --- 绘图 ---
figure('Color', 'w', 'Position', [100, 100, 1000, 480]);
hold on;

% 步骤 A: 绘制背景噪声 (线宽 1.5, 浅灰色)
plot(f, P, 'Color', [0.75, 0.75, 0.75], 'LineWidth', lwNoise);

% 步骤 B: 仅对主峰顶点着色并加粗 (线宽 3.0)
vertex_span = 1.2; % 顶点着色的频率宽度
for i = 1:3
    % 定位主峰极大值
    search_mask = (f > main_freqs(i)-3) & (f < main_freqs(i)+3);
    [~, local_max_idx] = max(P .* search_mask);
    
    % 确定顶点着色区间索引
    v_mask = (f > f(local_max_idx) - vertex_span) & (f < f(local_max_idx) + vertex_span);
    
    % 绘制加粗的彩色主峰顶点
    plot(f(v_mask), P(v_mask), 'Color', morandi_colors(i,:), 'LineWidth', lwMain);
end

% 4. 细节微调
title('Spectrum Hierarchy: Thick Vertices & Dense Noise', 'FontName', 'Arial', ...
      'FontSize', 12, 'Color', [0.3, 0.3, 0.3]);

xlim([30 150]); % 密集显示区域
ylim([0 4.0]); % 适应高耸主峰
axis off;      % 彻底隐藏坐标轴
hold off;
%% 
% ================== 1. 参数设置与数据生成 ==================
lambda = linspace(380, 780, 2000); % 波长范围：380nm - 780nm
lineWidth = 10.0;

% 随机生成 5-8 个高斯峰
numPeaks = randi([5, 8]);
spectrum = zeros(size(lambda));
for i = 1:numPeaks
    mu = 420 + rand() * 320;      % 随机中心点
    sigma = 10 + rand() * 30;     % 随机宽度
    A = 0.3 + rand() * 0.7;       % 随机幅度
    spectrum = spectrum + A * exp(-(lambda - mu).^2 / (2 * sigma^2));
end
spectrum = spectrum / max(spectrum); % 归一化

% ================== 2. 计算真彩色 RGB 映射 ==================
colors = zeros(length(lambda), 3);
for i = 1:length(lambda)
    colors(i, :) = wavelengthToRGB(lambda(i));
end

% ================== 3. 极简绘图 (无坐标) ==================
figure('Color', 'w', 'Position', [100, 100, 1000, 400]);
hold on;

% 使用 surface 技巧实现线条颜色渐变
% 构造 2xN 的矩阵来模拟线条
XX = [lambda; lambda];
YY = [spectrum; spectrum];
ZZ = zeros(size(XX));
CData = zeros(2, length(lambda), 3);
CData(1,:,:) = colors;
CData(2,:,:) = colors;

surface(XX, YY, ZZ, CData, ...
    'FaceColor', 'none', ...
    'EdgeColor', 'interp', ...
    'LineWidth', lineWidth);

% --- 核心：去掉所有坐标干扰 ---
axis off; 
ylim([-0.1 1.1]); % 留出上下边距，防止线条贴边
hold off;
%% 

% ==========================================================
% 辅助函数：波长转 RGB (简易物理模型)
% ==========================================================
function rgb = wavelengthToRGB(l)
    if (l>=380 && l<440), r=-(l-440)/(440-380); g=0; b=1;
    elseif (l>=440 && l<490), r=0; g=(l-440)/(490-440); b=1;
    elseif (l>=490 && l<510), r=0; g=1; b=-(l-510)/(510-490);
    elseif (l>=510 && l<580), r=(l-510)/(580-510); g=1; b=0;
    elseif (l>=580 && l<645), r=1; g=-(l-645)/(645-580); b=0;
    elseif (l>=645 && l<=780), r=1; g=0; b=0;
    else, r=0; g=0; b=0; end
    % 两端强度微调
    if (l<420), f=0.3+0.7*(l-380)/(420-380);
    elseif (l>700), f=0.3+0.7*(780-l)/(780-700);
    else, f=1.0; end
    rgb = ([r,g,b]*f).^0.8; % 伽马修正
end
%% 
function spectral_gradient_plot()
    % 主函数：生成数据并绘图
    
    % ================== 1. 参数设置与数据生成 ==================
    % 定义波长范围 (可见光 380nm - 780nm)
    lambda = linspace(380, 780, 2000); % 使用高分辨率以保证渐变平滑
    
    % 随机生成多峰光谱 (叠加 4-8 个随机高斯峰)
    numPeaks = randi([4, 8]);
    spectrum = zeros(size(lambda));
    
    rng('shuffle'); % 确保每次随机结果不同
    fprintf('正在生成 %d 个随机峰的光谱...\n', numPeaks);
    
    for i = 1:numPeaks
        % 随机中心波长 (Center)
        mu = 400 + rand() * 350;  
        % 随机宽度 (Sigma, 控制峰的尖锐程度)
        sigma = 15 + rand() * 40; 
        % 随机幅度 (Amplitude)
        A = 0.4 + rand() * 0.8;
        
        % 高斯函数叠加
        spectrum = spectrum + A * exp(-(lambda - mu).^2 / (2 * sigma^2));
    end
    
    % 归一化光谱强度到 [0, 1] 之间
    spectrum = spectrum / max(spectrum);
    
    % ================== 2. 计算波长对应的真彩色 RGB ==================
    nPoints = length(lambda);
    trueColors = zeros(nPoints, 3);
    
    % 遍历每个波长点，计算其对应的 RGB 值
    for i = 1:nPoints
        trueColors(i, :) = wavelength2rgb(lambda(i));
    end
    
    % ================== 3. 使用 Surface 绘制渐变线条 ==================
    % --- 核心技巧 ---
    % 为了让 surface 画出一条线，我们需要构造一个 2行的矩阵。
    % 第一行和第二行的数据是完全一样的。
    % 这样 surface 就会绘制一条极窄的"带子"，看起来就像一条线。
    
    XX = [lambda; lambda];
    YY = [spectrum; spectrum];
    ZZ = zeros(size(XX)); % Z 轴为 0，使其位于平面上
    
    % 构造 3D 颜色数组 [2 x N点 x 3通道]，用于直接指定 RGB 颜色
    CData3D = zeros(2, nPoints, 3);
    CData3D(1, :, :) = trueColors;
    CData3D(2, :, :) = trueColors;
    
    % 创建图形窗口，使用深色背景以突出光谱色
    figure('Color', 'k', 'Position', [100, 100, 1000, 500], 'InvertHardcopy', 'off');
    axes('Color', 'k', 'XColor', 'w', 'YColor', 'w', 'LineWidth', 1.2, ...
         'NextPlot', 'add', 'Box', 'on');
     
    % 绘制曲面
    % FaceColor = 'none' 表示不填充曲面内部
    % EdgeColor = 'interp' 是关键，表示边缘颜色进行插值渐变
    s = surface(XX, YY, ZZ, CData3D, ...
        'FaceColor', 'none', ...
        'EdgeColor', 'interp', ...
        'LineWidth', 4); % 线宽设置得粗一些效果更好

    % ================== 4. 图形装饰 ==================
    title('随机生成的多峰光谱 (真彩色波长渐变)', 'Color', 'w', 'FontSize', 16, 'FontWeight', 'bold');
    xlabel('波长 Wavelength (nm)', 'Color', 'w', 'FontSize', 12);
    ylabel('归一化强度 Normalized Intensity', 'Color', 'w', 'FontSize', 12);
    
    xlim([380, 780]);
    ylim([0, 1.05]);
    grid on;
    set(gca, 'GridColor', [0.3 0.3 0.3], 'GridAlpha', 0.6);
    
    % 添加一个颜色条作为参考（可选）
    colormap(gca, trueColors); % 使用生成的颜色作为当前坐标轴的色图
    c = colorbar('SouthOutside');
    c.Label.String = '光谱颜色参考';
    c.Color = 'w';
    c.Ticks = []; % 移除颜色条刻度，只看颜色
    
    view(2); % 确保是 2D 视图

end

% ========================================================================
% 辅助函数：将波长 (nm) 转换为近似的 RGB 值
% 基于 Dan Bruton 的算法实现
% ========================================================================
function rgb = wavelength2rgb(lambda)
    r = 0; g = 0; b = 0;
    
    if (lambda >= 380 && lambda < 440)
        r = -(lambda - 440) / (440 - 380);
        g = 0;
        b = 1;
    elseif (lambda >= 440 && lambda < 490)
        r = 0;
        g = (lambda - 440) / (490 - 440);
        b = 1;
    elseif (lambda >= 490 && lambda < 510)
        r = 0;
        g = 1;
        b = -(lambda - 510) / (510 - 490);
    elseif (lambda >= 510 && lambda < 580)
        r = (lambda - 510) / (580 - 510);
        g = 1;
        b = 0;
    elseif (lambda >= 580 && lambda < 645)
        r = 1;
        g = -(lambda - 645) / (645 - 580);
        b = 0;
    elseif (lambda >= 645 && lambda <= 780)
        r = 1;
        g = 0;
        b = 0;
    else
        r = 0; g = 0; b = 0; % 超出可见光范围显示黑色
    end
    
    % 强度衰减修正 (让光谱两端自然变暗)
    factor = 1.0;
    if (lambda >= 380 && lambda < 420)
        factor = 0.3 + 0.7 * (lambda - 380) / (420 - 380);
    elseif (lambda >= 380 && lambda <= 700)
        factor = 1.0;
    elseif (lambda > 700 && lambda <= 780)
        factor = 0.3 + 0.7 * (780 - lambda) / (780 - 700);
    else
        factor = 0;
    end
    
    % 应用伽马校正并输出
    gamma = 0.8;
    rgb = [r, g, b] * factor;
    rgb = rgb .^ gamma;
    % 确保范围在 [0, 1]
    rgb(rgb < 0) = 0;
    rgb(rgb > 1) = 1;
end
"""
FDM E2E 网络模型
时域信号 -> 光谱重建
"""

import torch
import torch.nn as nn
import torch.nn.functional as F


class ConvBlock(nn.Module):
    """卷积块：Conv1d + BN + ReLU"""
    def __init__(self, in_channels, out_channels, kernel_size=3, stride=1, padding=1):
        super().__init__()
        self.conv = nn.Conv1d(in_channels, out_channels, kernel_size, stride, padding)
        self.bn = nn.BatchNorm1d(out_channels)
        self.relu = nn.ReLU(inplace=True)
        
    def forward(self, x):
        return self.relu(self.bn(self.conv(x)))


class ResBlock(nn.Module):
    """残差块"""
    def __init__(self, channels, kernel_size=3):
        super().__init__()
        self.conv1 = nn.Conv1d(channels, channels, kernel_size, padding=kernel_size//2)
        self.bn1 = nn.BatchNorm1d(channels)
        self.conv2 = nn.Conv1d(channels, channels, kernel_size, padding=kernel_size//2)
        self.bn2 = nn.BatchNorm1d(channels)
        self.relu = nn.ReLU(inplace=True)
        
    def forward(self, x):
        residual = x
        out = self.relu(self.bn1(self.conv1(x)))
        out = self.bn2(self.conv2(out))
        out += residual
        return self.relu(out)


class FDME2ENet(nn.Module):
    """
    FDM端到端网络
    输入: [B, seq_len] 时域信号
    输出: [B, n_channels] 光谱
    """
    
    def __init__(self, seq_len=10000, n_channels=31, hidden_dim=128, n_res_blocks=4):
        super().__init__()
        
        self.seq_len = seq_len
        self.n_channels = n_channels
        
        # 编码器：逐步降采样
        self.encoder = nn.Sequential(
            # [B, 1, 10000] -> [B, 32, 2500]
            ConvBlock(1, 32, kernel_size=7, stride=4, padding=3),
            # [B, 32, 2500] -> [B, 64, 625]
            ConvBlock(32, 64, kernel_size=5, stride=4, padding=2),
            # [B, 64, 625] -> [B, 128, 125]
            ConvBlock(64, 128, kernel_size=5, stride=5, padding=2),
            # [B, 128, 125] -> [B, 128, 25]
            ConvBlock(128, hidden_dim, kernel_size=5, stride=5, padding=2),
        )
        
        # 残差块
        self.res_blocks = nn.Sequential(
            *[ResBlock(hidden_dim) for _ in range(n_res_blocks)]
        )
        
        # 全局池化 + 全连接
        self.global_pool = nn.AdaptiveAvgPool1d(1)
        
        self.decoder = nn.Sequential(
            nn.Linear(hidden_dim, hidden_dim),
            nn.ReLU(inplace=True),
            nn.Dropout(0.2),
            nn.Linear(hidden_dim, hidden_dim),
            nn.ReLU(inplace=True),
            nn.Dropout(0.2),
            nn.Linear(hidden_dim, n_channels),
            nn.Sigmoid()  # 输出范围 [0, 1]
        )
        
        self._init_weights()
        
    def _init_weights(self):
        for m in self.modules():
            if isinstance(m, nn.Conv1d):
                nn.init.kaiming_normal_(m.weight, mode='fan_out', nonlinearity='relu')
            elif isinstance(m, nn.BatchNorm1d):
                nn.init.constant_(m.weight, 1)
                nn.init.constant_(m.bias, 0)
            elif isinstance(m, nn.Linear):
                nn.init.xavier_normal_(m.weight)
                nn.init.constant_(m.bias, 0)
                
    def forward(self, x):
        # x: [B, seq_len]
        x = x.unsqueeze(1)  # [B, 1, seq_len]
        
        # 编码
        x = self.encoder(x)  # [B, hidden_dim, L]
        x = self.res_blocks(x)
        
        # 全局池化
        x = self.global_pool(x)  # [B, hidden_dim, 1]
        x = x.squeeze(-1)  # [B, hidden_dim]
        
        # 解码为光谱
        x = self.decoder(x)  # [B, n_channels]
        
        return x


class FDME2ENetLarge(nn.Module):
    """
    更大的网络版本
    """
    
    def __init__(self, seq_len=10000, n_channels=31, hidden_dim=256, n_res_blocks=6):
        super().__init__()
        
        self.seq_len = seq_len
        self.n_channels = n_channels
        
        # 编码器
        self.encoder = nn.Sequential(
            ConvBlock(1, 64, kernel_size=7, stride=4, padding=3),
            ConvBlock(64, 128, kernel_size=5, stride=4, padding=2),
            ConvBlock(128, 256, kernel_size=5, stride=5, padding=2),
            ConvBlock(256, hidden_dim, kernel_size=5, stride=5, padding=2),
        )
        
        # 残差块
        self.res_blocks = nn.Sequential(
            *[ResBlock(hidden_dim) for _ in range(n_res_blocks)]
        )
        
        # 全局池化
        self.global_pool = nn.AdaptiveAvgPool1d(1)
        
        # 解码器
        self.decoder = nn.Sequential(
            nn.Linear(hidden_dim, 512),
            nn.ReLU(inplace=True),
            nn.Dropout(0.3),
            nn.Linear(512, 256),
            nn.ReLU(inplace=True),
            nn.Dropout(0.3),
            nn.Linear(256, n_channels),
            nn.Sigmoid()
        )
        
        self._init_weights()
        
    def _init_weights(self):
        for m in self.modules():
            if isinstance(m, nn.Conv1d):
                nn.init.kaiming_normal_(m.weight, mode='fan_out', nonlinearity='relu')
            elif isinstance(m, nn.BatchNorm1d):
                nn.init.constant_(m.weight, 1)
                nn.init.constant_(m.bias, 0)
            elif isinstance(m, nn.Linear):
                nn.init.xavier_normal_(m.weight)
                nn.init.constant_(m.bias, 0)
                
    def forward(self, x):
        x = x.unsqueeze(1)
        x = self.encoder(x)
        x = self.res_blocks(x)
        x = self.global_pool(x)
        x = x.squeeze(-1)
        x = self.decoder(x)
        return x


class FDME2ENetTransformer(nn.Module):
    """
    基于Transformer的版本
    """
    
    def __init__(self, seq_len=10000, n_channels=31, d_model=128, nhead=4, num_layers=4):
        super().__init__()
        
        self.seq_len = seq_len
        self.n_channels = n_channels
        
        # 下采样到可处理的长度
        self.downsample = nn.Sequential(
            ConvBlock(1, 32, kernel_size=7, stride=4, padding=3),
            ConvBlock(32, 64, kernel_size=5, stride=5, padding=2),
            ConvBlock(64, d_model, kernel_size=5, stride=5, padding=2),
        )  # 10000 -> 100
        
        # Transformer编码器
        encoder_layer = nn.TransformerEncoderLayer(
            d_model=d_model, 
            nhead=nhead, 
            dim_feedforward=d_model*4,
            dropout=0.1,
            batch_first=True
        )
        self.transformer = nn.TransformerEncoder(encoder_layer, num_layers=num_layers)
        
        # 位置编码
        self.pos_encoding = nn.Parameter(torch.randn(1, 100, d_model) * 0.02)
        
        # 解码器
        self.decoder = nn.Sequential(
            nn.Linear(d_model, d_model),
            nn.ReLU(inplace=True),
            nn.Linear(d_model, n_channels),
            nn.Sigmoid()
        )
        
    def forward(self, x):
        x = x.unsqueeze(1)  # [B, 1, seq_len]
        x = self.downsample(x)  # [B, d_model, L]
        x = x.permute(0, 2, 1)  # [B, L, d_model]
        
        # 加位置编码
        x = x + self.pos_encoding[:, :x.size(1), :]
        
        # Transformer
        x = self.transformer(x)  # [B, L, d_model]
        
        # 全局平均池化
        x = x.mean(dim=1)  # [B, d_model]
        
        # 解码
        x = self.decoder(x)  # [B, n_channels]
        
        return x


def count_parameters(model):
    """计算模型参数量"""
    return sum(p.numel() for p in model.parameters() if p.requires_grad)


if __name__ == "__main__":
    # 测试模型
    batch_size = 4
    seq_len = 10000
    n_channels = 31
    
    x = torch.randn(batch_size, seq_len)
    
    print("=" * 50)
    print("模型测试")
    print("=" * 50)
    
    # 标准模型
    model = FDME2ENet(seq_len=seq_len, n_channels=n_channels)
    y = model(x)
    print(f"\nFDME2ENet:")
    print(f"  输入: {x.shape}")
    print(f"  输出: {y.shape}")
    print(f"  参数量: {count_parameters(model):,}")
    
    # 大模型
    model_large = FDME2ENetLarge(seq_len=seq_len, n_channels=n_channels)
    y = model_large(x)
    print(f"\nFDME2ENetLarge:")
    print(f"  输入: {x.shape}")
    print(f"  输出: {y.shape}")
    print(f"  参数量: {count_parameters(model_large):,}")
    
    # Transformer模型
    model_trans = FDME2ENetTransformer(seq_len=seq_len, n_channels=n_channels)
    y = model_trans(x)
    print(f"\nFDME2ENetTransformer:")
    print(f"  输入: {x.shape}")
    print(f"  输出: {y.shape}")
    print(f"  参数量: {count_parameters(model_trans):,}")

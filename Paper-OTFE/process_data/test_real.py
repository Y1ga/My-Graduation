"""
FDM E2E 测试脚本
使用真实wfm文件（色卡1-24）进行测试
直接在VSCode中点击运行即可
"""

import os
import numpy as np
import torch
import torch.nn as nn
import matplotlib.pyplot as plt
from scipy import io as sio
import h5py

# ==================== 配置参数（在这里修改）====================
CONFIG = {
    # 模型
    'checkpoint': './checkpoints/best_model.pth',
    
    # 数据
    'wfm_dir': './data/PD-01-04/',
    'gt_path': './data/gt/mat/colorchecker_gt.mat',
    
    # 预处理参数（与训练保持一致）
    'fs': 1e9,
    'duration': 350e-6,  # 350μs
    'downsample_factor': 70,  # 降采样70x
    'normalize_method': 'zscore',
    'seq_len': 5000,  # 5000点
    
    # 保存
    'save_dir': './test_results',
}


# ==================== 模型定义（与train.py一致）====================
class ConvBlock(nn.Module):
    def __init__(self, in_ch, out_ch, kernel_size=3, stride=1, padding=1):
        super().__init__()
        self.conv = nn.Conv1d(in_ch, out_ch, kernel_size, stride, padding)
        self.bn = nn.BatchNorm1d(out_ch)
        self.relu = nn.ReLU(inplace=True)
        
    def forward(self, x):
        return self.relu(self.bn(self.conv(x)))


class ResBlock(nn.Module):
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
        return self.relu(out + residual)


class FDME2ENet(nn.Module):
    def __init__(self, seq_len=10000, n_channels=31, hidden_dim=128, n_res_blocks=4):
        super().__init__()
        self.encoder = nn.Sequential(
            ConvBlock(1, 32, kernel_size=7, stride=4, padding=3),
            ConvBlock(32, 64, kernel_size=5, stride=4, padding=2),
            ConvBlock(64, 128, kernel_size=5, stride=5, padding=2),
            ConvBlock(128, hidden_dim, kernel_size=5, stride=5, padding=2),
        )
        self.res_blocks = nn.Sequential(*[ResBlock(hidden_dim) for _ in range(n_res_blocks)])
        self.global_pool = nn.AdaptiveAvgPool1d(1)
        self.decoder = nn.Sequential(
            nn.Linear(hidden_dim, hidden_dim),
            nn.ReLU(inplace=True),
            nn.Dropout(0.2),
            nn.Linear(hidden_dim, hidden_dim),
            nn.ReLU(inplace=True),
            nn.Dropout(0.2),
            nn.Linear(hidden_dim, n_channels),
            nn.Sigmoid()
        )
        
    def forward(self, x):
        x = x.unsqueeze(1)
        x = self.encoder(x)
        x = self.res_blocks(x)
        x = self.global_pool(x).squeeze(-1)
        return self.decoder(x)


class FDME2ENetLarge(nn.Module):
    def __init__(self, seq_len=10000, n_channels=31, hidden_dim=256, n_res_blocks=6):
        super().__init__()
        self.encoder = nn.Sequential(
            ConvBlock(1, 64, kernel_size=7, stride=4, padding=3),
            ConvBlock(64, 128, kernel_size=5, stride=4, padding=2),
            ConvBlock(128, 256, kernel_size=5, stride=5, padding=2),
            ConvBlock(256, hidden_dim, kernel_size=5, stride=5, padding=2),
        )
        self.res_blocks = nn.Sequential(*[ResBlock(hidden_dim) for _ in range(n_res_blocks)])
        self.global_pool = nn.AdaptiveAvgPool1d(1)
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
        
    def forward(self, x):
        x = x.unsqueeze(1)
        x = self.encoder(x)
        x = self.res_blocks(x)
        x = self.global_pool(x).squeeze(-1)
        return self.decoder(x)


class FDME2ENetTransformer(nn.Module):
    def __init__(self, seq_len=10000, n_channels=31, d_model=128, nhead=4, num_layers=4):
        super().__init__()
        self.downsample = nn.Sequential(
            ConvBlock(1, 32, kernel_size=7, stride=4, padding=3),
            ConvBlock(32, 64, kernel_size=5, stride=5, padding=2),
            ConvBlock(64, d_model, kernel_size=5, stride=5, padding=2),
        )
        encoder_layer = nn.TransformerEncoderLayer(d_model=d_model, nhead=nhead, 
                                                    dim_feedforward=d_model*4, dropout=0.1, batch_first=True)
        self.transformer = nn.TransformerEncoder(encoder_layer, num_layers=num_layers)
        self.pos_encoding = nn.Parameter(torch.randn(1, 100, d_model) * 0.02)
        self.decoder = nn.Sequential(
            nn.Linear(d_model, d_model),
            nn.ReLU(inplace=True),
            nn.Linear(d_model, n_channels),
            nn.Sigmoid()
        )
        
    def forward(self, x):
        x = x.unsqueeze(1)
        x = self.downsample(x)
        x = x.permute(0, 2, 1)
        x = x + self.pos_encoding[:, :x.size(1), :]
        x = self.transformer(x)
        x = x.mean(dim=1)
        return self.decoder(x)


# ==================== 工具函数 ====================
def load_mat_variable(filepath, varname):
    """加载.mat文件中的变量"""
    try:
        with h5py.File(filepath, 'r') as f:
            data = np.array(f[varname])
            if data.ndim == 2:
                data = data.T
        return data
    except:
        mat = sio.loadmat(filepath)
        return mat[varname]


def read_rigol_wfm(filepath, fs=1e9, duration=100e-5):
    """读取Rigol示波器wfm文件"""
    with open(filepath, 'rb') as f:
        f.seek(0x84)
        volt_div = np.frombuffer(f.read(4), dtype=np.float32)[0]
        f.seek(0xA0)
        volt_scale = np.frombuffer(f.read(4), dtype=np.float32)[0]
        f.seek(0xA4)
        volt_offset = np.frombuffer(f.read(4), dtype=np.float32)[0]
        f.seek(3334)
        raw_data = np.frombuffer(f.read(), dtype=np.uint8)
    
    signal = (raw_data.astype(np.float64) - 128) * volt_scale + volt_offset
    n_use = min(int(duration * fs), len(signal))
    return signal[:n_use]


def preprocess_wfm_signal(signal, normalize_method='zscore', downsample_factor=100):
    """预处理wfm信号"""
    signal_ds = signal[::downsample_factor]
    
    if normalize_method == 'zscore':
        mean, std = np.mean(signal_ds), np.std(signal_ds)
        if std > 0:
            signal_ds = (signal_ds - mean) / std
    elif normalize_method == 'minmax':
        min_val, max_val = np.min(signal_ds), np.max(signal_ds)
        if max_val > min_val:
            signal_ds = (signal_ds - min_val) / (max_val - min_val)
    
    return signal_ds.astype(np.float32)


def compute_metrics(pred, gt):
    """计算评估指标"""
    mse = np.mean((pred - gt) ** 2)
    rmse = np.sqrt(mse)
    mae = np.mean(np.abs(pred - gt))
    
    pred_norm = pred / (np.linalg.norm(pred) + 1e-8)
    gt_norm = gt / (np.linalg.norm(gt) + 1e-8)
    cos_sim = np.clip(np.dot(pred_norm, gt_norm), -1, 1)
    sam = np.arccos(cos_sim) * 180 / np.pi
    
    mrae = np.mean(np.abs(pred - gt) / (gt + 1e-6))
    corr = np.corrcoef(pred, gt)[0, 1]
    
    return {'mse': mse, 'rmse': rmse, 'mae': mae, 'sam': sam, 'mrae': mrae, 'corr': corr}


def plot_results(pred, gt, results, wavelengths, save_dir):
    """绘制测试结果"""
    os.makedirs(save_dir, exist_ok=True)
    n_samples = len(pred)
    
    # 1. 所有色卡光谱对比
    fig, axes = plt.subplots(4, 6, figsize=(18, 12))
    axes = axes.flatten()
    
    for i in range(min(24, n_samples)):
        ax = axes[i]
        ax.plot(wavelengths, gt[i], 'b-', label='GT', linewidth=1.5)
        ax.plot(wavelengths, pred[i], 'r--', label='Pred', linewidth=1.5)
        ax.set_title(f"#{i+1} SAM={results[i]['sam']:.1f}°", fontsize=10)
        ax.set_xlim([400, 700])
        ax.set_ylim([0, 1])
        ax.grid(True, alpha=0.3)
        if i == 0:
            ax.legend(fontsize=8)
    
    plt.tight_layout()
    plt.savefig(os.path.join(save_dir, 'all_spectra.png'), dpi=150)
    plt.show()
    
    # 2. 误差分析
    fig, axes = plt.subplots(2, 2, figsize=(12, 10))
    
    rmse_values = [r['rmse'] for r in results]
    axes[0, 0].bar(range(1, len(rmse_values)+1), rmse_values, color='steelblue')
    axes[0, 0].axhline(np.mean(rmse_values), color='red', linestyle='--', label=f'Mean={np.mean(rmse_values):.4f}')
    axes[0, 0].set_xlabel('Color Card #')
    axes[0, 0].set_ylabel('RMSE')
    axes[0, 0].set_title('RMSE per Color Card')
    axes[0, 0].legend()
    axes[0, 0].grid(True, alpha=0.3)
    
    sam_values = [r['sam'] for r in results]
    axes[0, 1].bar(range(1, len(sam_values)+1), sam_values, color='coral')
    axes[0, 1].axhline(np.mean(sam_values), color='red', linestyle='--', label=f'Mean={np.mean(sam_values):.1f}°')
    axes[0, 1].set_xlabel('Color Card #')
    axes[0, 1].set_ylabel('SAM (°)')
    axes[0, 1].set_title('SAM per Color Card')
    axes[0, 1].legend()
    axes[0, 1].grid(True, alpha=0.3)
    
    axes[1, 0].scatter(gt.flatten(), pred.flatten(), alpha=0.3, s=5)
    axes[1, 0].plot([0, 1], [0, 1], 'r--', linewidth=1.5)
    axes[1, 0].set_xlabel('Ground Truth')
    axes[1, 0].set_ylabel('Prediction')
    axes[1, 0].set_title('Prediction vs Ground Truth')
    axes[1, 0].set_xlim([0, 1])
    axes[1, 0].set_ylim([0, 1])
    axes[1, 0].grid(True, alpha=0.3)
    
    errors = (pred - gt).flatten()
    axes[1, 1].hist(errors, bins=50, color='gray', edgecolor='black', alpha=0.7)
    axes[1, 1].axvline(0, color='red', linestyle='--')
    axes[1, 1].set_xlabel('Error')
    axes[1, 1].set_ylabel('Count')
    axes[1, 1].set_title(f'Error Distribution (std={np.std(errors):.4f})')
    axes[1, 1].grid(True, alpha=0.3)
    
    plt.tight_layout()
    plt.savefig(os.path.join(save_dir, 'error_analysis.png'), dpi=150)
    plt.show()
    
    # 3. 选择典型样本
    fig, axes = plt.subplots(2, 3, figsize=(15, 8))
    axes = axes.flatten()
    
    sam_sorted_idx = np.argsort([r['sam'] for r in results])
    show_indices = [
        sam_sorted_idx[0],
        sam_sorted_idx[len(sam_sorted_idx)//4],
        sam_sorted_idx[len(sam_sorted_idx)//2],
        sam_sorted_idx[3*len(sam_sorted_idx)//4],
        sam_sorted_idx[-2] if len(sam_sorted_idx) > 1 else sam_sorted_idx[-1],
        sam_sorted_idx[-1],
    ]
    
    for i, idx in enumerate(show_indices):
        ax = axes[i]
        ax.fill_between(wavelengths, 0, gt[idx], alpha=0.3, color='blue', label='GT')
        ax.plot(wavelengths, gt[idx], 'b-', linewidth=2)
        ax.plot(wavelengths, pred[idx], 'r-', linewidth=2, label='Pred')
        ax.set_title(f"Color #{idx+1}\nSAM={results[idx]['sam']:.2f}°, RMSE={results[idx]['rmse']:.4f}")
        ax.set_xlabel('Wavelength (nm)')
        ax.set_ylabel('Reflectance')
        ax.set_xlim([400, 700])
        ax.set_ylim([0, 1])
        ax.grid(True, alpha=0.3)
        if i == 0:
            ax.legend()
    
    plt.tight_layout()
    plt.savefig(os.path.join(save_dir, 'selected_spectra.png'), dpi=150)
    plt.show()


# ==================== 主函数 ====================
def main():
    print("=" * 60)
    print("FDM E2E 真实数据测试")
    print("=" * 60)
    
    cfg = CONFIG
    
    # 设备
    device = torch.device('cuda' if torch.cuda.is_available() else 'cpu')
    print(f"设备: {device}")
    
    # 加载模型
    checkpoint = torch.load(cfg['checkpoint'], map_location=device)
    model_cfg = checkpoint.get('config', {})
    model_type = model_cfg.get('model', 'base')
    
    seq_len = cfg['seq_len']
    n_channels = 31
    
    if model_type == 'base':
        model = FDME2ENet(seq_len=seq_len, n_channels=n_channels)
    elif model_type == 'large':
        model = FDME2ENetLarge(seq_len=seq_len, n_channels=n_channels)
    elif model_type == 'transformer':
        model = FDME2ENetTransformer(seq_len=seq_len, n_channels=n_channels)
    else:
        model = FDME2ENet(seq_len=seq_len, n_channels=n_channels)
    
    model.load_state_dict(checkpoint['model_state_dict'])
    model = model.to(device)
    model.eval()
    print(f"加载模型: {cfg['checkpoint']}")
    print(f"模型类型: {model_type}")
    
    # 加载ColorChecker真值
    colorchecker_gt = load_mat_variable(cfg['gt_path'], 'gt')
    if colorchecker_gt.shape[0] == 31:
        colorchecker_gt = colorchecker_gt.T
    print(f"ColorChecker真值: {colorchecker_gt.shape}")
    
    wavelengths = np.linspace(400, 700, n_channels)
    
    # 测试每个色卡
    results = []
    all_pred = []
    all_gt = []
    
    print("\n测试中...")
    print("-" * 60)
    
    for idx in range(1, 25):
        wfm_path = os.path.join(cfg['wfm_dir'], f"新建文件{idx}.wfm")
        
        if not os.path.exists(wfm_path):
            print(f"色卡 #{idx}: 文件不存在，跳过")
            continue
        
        # 读取并预处理
        signal = read_rigol_wfm(wfm_path, fs=cfg['fs'], duration=cfg['duration'])
        signal_processed = preprocess_wfm_signal(signal, cfg['normalize_method'], cfg['downsample_factor'])
        
        # 确保长度正确
        if len(signal_processed) < seq_len:
            signal_processed = np.pad(signal_processed, (0, seq_len - len(signal_processed)))
        elif len(signal_processed) > seq_len:
            signal_processed = signal_processed[:seq_len]
        
        # 推理
        with torch.no_grad():
            x = torch.FloatTensor(signal_processed).unsqueeze(0).to(device)
            pred = model(x)
            pred = pred.cpu().numpy().squeeze()
        
        gt = colorchecker_gt[idx - 1]
        metrics = compute_metrics(pred, gt)
        metrics['idx'] = idx
        results.append(metrics)
        
        all_pred.append(pred)
        all_gt.append(gt)
        
        print(f"色卡 #{idx:2d}: RMSE={metrics['rmse']:.4f}, SAM={metrics['sam']:.2f}°, Corr={metrics['corr']:.4f}")
    
    all_pred = np.array(all_pred)
    all_gt = np.array(all_gt)
    
    # 汇总统计
    print("\n" + "=" * 60)
    print("总体统计")
    print("=" * 60)
    
    avg_metrics = {
        'rmse': np.mean([r['rmse'] for r in results]),
        'mae': np.mean([r['mae'] for r in results]),
        'sam': np.mean([r['sam'] for r in results]),
        'mrae': np.mean([r['mrae'] for r in results]),
        'corr': np.mean([r['corr'] for r in results])
    }
    
    print(f"平均 RMSE: {avg_metrics['rmse']:.4f}")
    print(f"平均 MAE:  {avg_metrics['mae']:.4f}")
    print(f"平均 SAM:  {avg_metrics['sam']:.2f}°")
    print(f"平均 MRAE: {avg_metrics['mrae']:.4f}")
    print(f"平均 Corr: {avg_metrics['corr']:.4f}")
    
    # 可视化
    plot_results(all_pred, all_gt, results, wavelengths, cfg['save_dir'])
    
    # 保存结果
    os.makedirs(cfg['save_dir'], exist_ok=True)
    np.savez(
        os.path.join(cfg['save_dir'], 'test_results.npz'),
        pred=all_pred,
        gt=all_gt,
        results=results,
        avg_metrics=avg_metrics,
        wavelengths=wavelengths
    )
    
    print(f"\n结果保存至: {cfg['save_dir']}")


# ==================== 直接运行 ====================
if __name__ == "__main__":
    main()
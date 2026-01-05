"""
FDM E2E 真实数据测试
读取示波器 WFM 文件，用训练好的模型预测光谱
"""

import torch
import numpy as np
import matplotlib.pyplot as plt
from pathlib import Path
import struct

# ==================== 配置 ====================
class Config:
    # 模型路径
    model_path = r".\checkpoints\best_model.pth"
    
    # 数据路径
    wfm_dir = r"./data/PD-01-04/"
    colorchecker_path = r"./data/gt/mat/colorchecker.mat"  # 真值
    
    # 信号参数
    fs = 1e9           # 采样率 1 GHz
    duration = 300e-6  # 300 μs
    downsample_factor = 100
    
    # 归一化方式：使用标准差归一化，使范围约为 [-1, 1]
    # 训练数据: std ≈ 26708, 归一化后 std ≈ 0.2
    # 真实数据: std ≈ 0.5, 需要缩放到同样的分布
    normalize_method = 'std'  # 'std' 或 'max'
    target_std = 0.2  # 目标标准差（与训练数据归一化后一致）
    
    # 网络参数
    input_dim = 3000
    output_dim = 31
    
    device = torch.device("cuda" if torch.cuda.is_available() else "cpu")

# ==================== 模型定义 (与训练一致) ====================
import torch.nn as nn

class FDM_CNN(nn.Module):
    def __init__(self, input_dim=3000, output_dim=31):
        super(FDM_CNN, self).__init__()
        
        self.features = nn.Sequential(
            nn.Conv1d(1, 32, kernel_size=7, stride=1, padding=3),
            nn.BatchNorm1d(32),
            nn.ReLU(inplace=True),
            nn.MaxPool1d(2),
            
            nn.Conv1d(32, 64, kernel_size=5, stride=1, padding=2),
            nn.BatchNorm1d(64),
            nn.ReLU(inplace=True),
            nn.MaxPool1d(2),
            
            nn.Conv1d(64, 128, kernel_size=5, stride=1, padding=2),
            nn.BatchNorm1d(128),
            nn.ReLU(inplace=True),
            nn.MaxPool1d(2),
            
            nn.Conv1d(128, 256, kernel_size=3, stride=1, padding=1),
            nn.BatchNorm1d(256),
            nn.ReLU(inplace=True),
            nn.MaxPool1d(2),
            
            nn.Conv1d(256, 256, kernel_size=3, stride=1, padding=1),
            nn.BatchNorm1d(256),
            nn.ReLU(inplace=True),
            nn.MaxPool1d(2),
            
            nn.Conv1d(256, 512, kernel_size=3, stride=1, padding=1),
            nn.BatchNorm1d(512),
            nn.ReLU(inplace=True),
            nn.MaxPool1d(2),
        )
        
        self._flat_dim = self._get_flat_dim(input_dim)
        
        self.regressor = nn.Sequential(
            nn.Linear(self._flat_dim, 512),
            nn.ReLU(inplace=True),
            nn.Dropout(0.3),
            
            nn.Linear(512, 256),
            nn.ReLU(inplace=True),
            nn.Dropout(0.3),
            
            nn.Linear(256, output_dim),
            nn.Sigmoid()
        )
    
    def _get_flat_dim(self, input_dim):
        x = torch.zeros(1, 1, input_dim)
        x = self.features(x)
        return x.view(1, -1).size(1)
    
    def forward(self, x):
        if x.dim() == 2:
            x = x.unsqueeze(1)
        x = self.features(x)
        x = x.view(x.size(0), -1)
        x = self.regressor(x)
        return x

# ==================== WFM 读取函数 ====================
def read_rigol_wfm(filename, fs=1e9, duration=300e-6, downsample_factor=100):
    """
    读取 Rigol WFM 文件并返回降采样后的时域信号
    
    返回:
        signal_ds: 降采样后的信号 [N_points_ds]
    """
    with open(filename, 'rb') as f:
        # 读取电压刻度 (偏移 0xA0)
        f.seek(0xA0)
        volt_scale = struct.unpack('<f', f.read(4))[0]
        
        # 读取数据 (跳过 3334 字节头部)
        f.seek(3334)
        raw_data = np.frombuffer(f.read(), dtype=np.uint8)
    
    # 转换为电压
    signal = (raw_data.astype(np.float32) - 128) * volt_scale
    
    # 截取指定时长
    n_use = min(int(duration * fs), len(signal))
    signal = signal[:n_use]
    
    # 去除直流分量（关键！）
    signal = signal - np.mean(signal)
    
    # 降采样
    signal_ds = signal[::downsample_factor]
    
    return signal_ds

# ==================== 加载真值 ====================
def load_colorchecker(path):
    """加载 ColorChecker 真值"""
    try:
        import scipy.io as sio
        data = sio.loadmat(path)
        for key in data:
            if not key.startswith('_') and data[key].size > 100:
                cc = data[key].astype(np.float32)
                break
    except:
        import h5py
        with h5py.File(path, 'r') as f:
            for key in f.keys():
                if f[key].size > 100:
                    cc = np.array(f[key]).T.astype(np.float32)
                    break
    
    # 确保是 [24 × 31]
    if cc.shape[0] == 31:
        cc = cc.T
    
    return cc

# ==================== 评估指标 ====================
def compute_metrics(pred, target):
    """计算单个样本的指标"""
    # MRAE
    mrae = np.mean(np.abs(pred - target) / (target + 1e-6))
    
    # RMSE
    rmse = np.sqrt(np.mean((pred - target) ** 2))
    
    # SAM
    dot = np.sum(pred * target)
    norm_pred = np.linalg.norm(pred)
    norm_target = np.linalg.norm(target)
    cos_sim = dot / (norm_pred * norm_target + 1e-6)
    cos_sim = np.clip(cos_sim, -1, 1)
    sam = np.arccos(cos_sim) * 180 / np.pi
    
    return mrae, rmse, sam

# ==================== 主测试函数 ====================
def test_real_data(cfg):
    print("=" * 60)
    print("FDM E2E 真实数据测试")
    print("=" * 60)
    
    # 加载模型
    print(f"\n加载模型: {cfg.model_path}")
    model = FDM_CNN(cfg.input_dim, cfg.output_dim).to(cfg.device)
    checkpoint = torch.load(cfg.model_path, map_location=cfg.device)
    model.load_state_dict(checkpoint['model_state_dict'])
    model.eval()
    print(f"  模型加载成功 (epoch {checkpoint['epoch']})")
    
    # 加载 ColorChecker 真值
    print(f"\n加载真值: {cfg.colorchecker_path}")
    colorchecker = load_colorchecker(cfg.colorchecker_path)
    print(f"  ColorChecker: {colorchecker.shape}")
    
    # 测试 24 个色块
    n_colors = 24
    wavelengths = np.linspace(400, 700, 31)
    
    all_pred = []
    all_gt = []
    all_mrae = []
    all_rmse = []
    all_sam = []
    
    print(f"\n{'='*60}")
    print(f"{'色块':^6} {'MRAE':^10} {'RMSE':^10} {'SAM(°)':^10}")
    print(f"{'='*60}")
    
    for idx in range(1, n_colors + 1):
        # 读取 WFM 文件
        wfm_file = Path(cfg.wfm_dir) / f"新建文件{idx}.wfm"
        if not wfm_file.exists():
            print(f"  跳过: {wfm_file} 不存在")
            continue
        
        signal = read_rigol_wfm(str(wfm_file), cfg.fs, cfg.duration, cfg.downsample_factor)
        
        # 归一化：按最大绝对值缩放到 [-1, 1]（与训练数据一致）
        signal = signal / np.max(np.abs(signal))
        
        # 转为 tensor
        x = torch.from_numpy(signal).float().unsqueeze(0).to(cfg.device)
        
        # 预测
        with torch.no_grad():
            pred = model(x).cpu().numpy().squeeze()
        
        # 真值
        gt = colorchecker[idx - 1, :]
        
        # 计算指标
        mrae, rmse, sam = compute_metrics(pred, gt)
        
        all_pred.append(pred)
        all_gt.append(gt)
        all_mrae.append(mrae)
        all_rmse.append(rmse)
        all_sam.append(sam)
        
        print(f"{idx:^6} {mrae:^10.4f} {rmse:^10.4f} {sam:^10.2f}")
    
    print(f"{'='*60}")
    print(f"{'平均':^6} {np.mean(all_mrae):^10.4f} {np.mean(all_rmse):^10.4f} {np.mean(all_sam):^10.2f}")
    print(f"{'='*60}")
    
    # 可视化
    visualize_results(all_pred, all_gt, wavelengths, all_mrae, cfg)
    
    return all_pred, all_gt

def visualize_results(all_pred, all_gt, wavelengths, all_mrae, cfg):
    """可视化预测结果"""
    n_colors = len(all_pred)
    
    # 选择 6 个样本可视化 (最好、最差、中间)
    mrae_sorted_idx = np.argsort(all_mrae)
    show_idx = [
        mrae_sorted_idx[0],      # 最好
        mrae_sorted_idx[1],
        mrae_sorted_idx[n_colors//3],
        mrae_sorted_idx[n_colors//2],
        mrae_sorted_idx[-2],
        mrae_sorted_idx[-1],     # 最差
    ]
    
    fig, axes = plt.subplots(2, 3, figsize=(15, 10))
    axes = axes.flatten()
    
    for i, idx in enumerate(show_idx):
        ax = axes[i]
        ax.plot(wavelengths, all_gt[idx], 'b-', linewidth=2, label='Ground Truth')
        ax.plot(wavelengths, all_pred[idx], 'r--', linewidth=2, label='Prediction')
        ax.set_xlabel('Wavelength (nm)')
        ax.set_ylabel('Reflectance')
        ax.set_title(f'Color #{idx+1} (MRAE={all_mrae[idx]:.4f})')
        ax.legend()
        ax.grid(True)
        ax.set_ylim([0, 1])
    
    plt.suptitle(f'Real Data Test - ColorChecker 24 Colors\nMean MRAE: {np.mean(all_mrae):.4f}', fontsize=14)
    plt.tight_layout()
    
    save_path = Path(cfg.model_path).parent / 'real_data_test.png'
    plt.savefig(save_path, dpi=150)
    plt.show()
    print(f"\n已保存: {save_path}")
    
    # 绘制所有 24 色
    fig, axes = plt.subplots(4, 6, figsize=(20, 14))
    axes = axes.flatten()
    
    for i in range(min(24, len(all_pred))):
        ax = axes[i]
        ax.plot(wavelengths, all_gt[i], 'b-', linewidth=1.5, label='GT')
        ax.plot(wavelengths, all_pred[i], 'r--', linewidth=1.5, label='Pred')
        ax.set_title(f'#{i+1} (MRAE={all_mrae[i]:.3f})', fontsize=10)
        ax.set_ylim([0, 1])
        ax.grid(True, alpha=0.3)
        if i >= 18:
            ax.set_xlabel('λ (nm)')
        if i % 6 == 0:
            ax.set_ylabel('Reflectance')
    
    plt.suptitle(f'ColorChecker 24 Colors - Mean MRAE: {np.mean(all_mrae):.4f}, SAM: {np.mean([compute_metrics(p, g)[2] for p, g in zip(all_pred, all_gt)]):.2f}°', fontsize=14)
    plt.tight_layout()
    
    save_path = Path(cfg.model_path).parent / 'real_data_test_all24.png'
    plt.savefig(save_path, dpi=150)
    plt.show()
    print(f"已保存: {save_path}")

# ==================== 入口 ====================
if __name__ == '__main__':
    cfg = Config()
    
    # 检查文件
    if not Path(cfg.model_path).exists():
        print(f"错误: 模型文件不存在 {cfg.model_path}")
        print("请先运行 train_fdm_e2e.py 训练模型")
        exit(1)
    
    all_pred, all_gt = test_real_data(cfg)
"""
FDM End-to-End 1D CNN 训练代码
输入: 5000 点时域信号 (350μs, 降采样70x)
输出: 31 维光谱

直接在VSCode中点击运行
"""

import torch
import torch.nn as nn
import torch.optim as optim
from torch.utils.data import DataLoader, TensorDataset
import numpy as np
import matplotlib.pyplot as plt
from pathlib import Path
import time
import h5py

# ==================== 配置（在这里修改）====================
class Config:
    # 数据路径
    data_path = r"./dataset/fdm_e2e_5000pts_zscore_fast.mat"
    save_dir = r"./checkpoints"
    
    # 网络参数
    input_dim = 5000
    output_dim = 31
    
    # 训练参数
    batch_size = 256
    epochs = 100
    lr = 1e-3
    weight_decay = 1e-5
    
    # 设备
    device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
    
    # 随机种子
    seed = 42


# ==================== 1D CNN 模型 ====================
class FDM_CNN(nn.Module):
    """
    1D CNN for FDM spectral reconstruction
    Input: [batch, 1, 5000]
    Output: [batch, 31]
    """
    def __init__(self, input_dim=5000, output_dim=31):
        super(FDM_CNN, self).__init__()
        
        # 特征提取层
        self.features = nn.Sequential(
            # Block 1: 5000 -> 2500
            nn.Conv1d(1, 32, kernel_size=7, stride=1, padding=3),
            nn.BatchNorm1d(32),
            nn.ReLU(inplace=True),
            nn.MaxPool1d(2),
            
            # Block 2: 2500 -> 1250
            nn.Conv1d(32, 64, kernel_size=5, stride=1, padding=2),
            nn.BatchNorm1d(64),
            nn.ReLU(inplace=True),
            nn.MaxPool1d(2),
            
            # Block 3: 1250 -> 625
            nn.Conv1d(64, 128, kernel_size=5, stride=1, padding=2),
            nn.BatchNorm1d(128),
            nn.ReLU(inplace=True),
            nn.MaxPool1d(2),
            
            # Block 4: 625 -> 312
            nn.Conv1d(128, 256, kernel_size=3, stride=1, padding=1),
            nn.BatchNorm1d(256),
            nn.ReLU(inplace=True),
            nn.MaxPool1d(2),
            
            # Block 5: 312 -> 156
            nn.Conv1d(256, 256, kernel_size=3, stride=1, padding=1),
            nn.BatchNorm1d(256),
            nn.ReLU(inplace=True),
            nn.MaxPool1d(2),
            
            # Block 6: 156 -> 78
            nn.Conv1d(256, 512, kernel_size=3, stride=1, padding=1),
            nn.BatchNorm1d(512),
            nn.ReLU(inplace=True),
            nn.MaxPool1d(2),
        )
        
        # 计算展平后的维度
        self._flat_dim = self._get_flat_dim(input_dim)
        
        # 全连接层
        self.regressor = nn.Sequential(
            nn.Linear(self._flat_dim, 512),
            nn.ReLU(inplace=True),
            nn.Dropout(0.3),
            
            nn.Linear(512, 256),
            nn.ReLU(inplace=True),
            nn.Dropout(0.3),
            
            nn.Linear(256, output_dim),
            nn.Sigmoid()  # 输出 [0, 1]
        )
    
    def _get_flat_dim(self, input_dim):
        x = torch.zeros(1, 1, input_dim)
        x = self.features(x)
        return x.view(1, -1).size(1)
    
    def forward(self, x):
        # x: [batch, 5000] -> [batch, 1, 5000]
        if x.dim() == 2:
            x = x.unsqueeze(1)
        
        x = self.features(x)
        x = x.view(x.size(0), -1)
        x = self.regressor(x)
        return x


# ==================== 数据加载 ====================
def load_data(data_path):
    print(f"加载数据: {data_path}")
    
    try:
        # 尝试 scipy (v7.2 及以下)
        import scipy.io as sio
        data = sio.loadmat(data_path)
        X_train = data['X_train'].astype(np.float32)
        Y_train = data['Y_train'].astype(np.float32)
        X_val = data['X_val'].astype(np.float32)
        Y_val = data['Y_val'].astype(np.float32)
        X_test = data['X_test'].astype(np.float32)
        Y_test = data['Y_test'].astype(np.float32)
    except:
        # v7.3 格式，用 h5py
        with h5py.File(data_path, 'r') as f:
            X_train = np.array(f['X_train']).T.astype(np.float32)
            Y_train = np.array(f['Y_train']).T.astype(np.float32)
            X_val = np.array(f['X_val']).T.astype(np.float32)
            Y_val = np.array(f['Y_val']).T.astype(np.float32)
            X_test = np.array(f['X_test']).T.astype(np.float32)
            Y_test = np.array(f['Y_test']).T.astype(np.float32)
    
    print(f"  训练集: X={X_train.shape}, Y={Y_train.shape}")
    print(f"  验证集: X={X_val.shape}, Y={Y_val.shape}")
    print(f"  测试集: X={X_test.shape}, Y={Y_test.shape}")
    
    # 数据范围检查
    print(f"\n  数据范围:")
    print(f"    X_train: [{X_train.min():.4f}, {X_train.max():.4f}], mean={X_train.mean():.4f}, std={X_train.std():.4f}")
    print(f"    Y_train: [{Y_train.min():.4f}, {Y_train.max():.4f}], mean={Y_train.mean():.4f}, std={Y_train.std():.4f}")
    
    X_train = torch.from_numpy(X_train)
    Y_train = torch.from_numpy(Y_train)
    X_val = torch.from_numpy(X_val)
    Y_val = torch.from_numpy(Y_val)
    X_test = torch.from_numpy(X_test)
    Y_test = torch.from_numpy(Y_test)
    
    return X_train, Y_train, X_val, Y_val, X_test, Y_test


# ==================== 评估指标 ====================
def compute_metrics(pred, target):
    """计算 MRAE, RMSE, SAM"""
    # MRAE: Mean Relative Absolute Error
    mrae = torch.mean(torch.abs(pred - target) / (target + 1e-6)).item()
    
    # RMSE: Root Mean Square Error
    rmse = torch.sqrt(torch.mean((pred - target) ** 2)).item()
    
    # SAM: Spectral Angle Mapper (degrees)
    dot = torch.sum(pred * target, dim=1)
    norm_pred = torch.norm(pred, dim=1)
    norm_target = torch.norm(target, dim=1)
    cos_sim = dot / (norm_pred * norm_target + 1e-6)
    cos_sim = torch.clamp(cos_sim, -1, 1)
    sam = torch.mean(torch.acos(cos_sim) * 180 / np.pi).item()
    
    return mrae, rmse, sam


# ==================== 训练函数 ====================
def train_epoch(model, loader, criterion, optimizer, device):
    model.train()
    total_loss = 0
    for X, Y in loader:
        X, Y = X.to(device), Y.to(device)
        
        optimizer.zero_grad()
        pred = model(X)
        loss = criterion(pred, Y)
        loss.backward()
        optimizer.step()
        
        total_loss += loss.item() * X.size(0)
    
    return total_loss / len(loader.dataset)


def validate(model, loader, criterion, device):
    model.eval()
    total_loss = 0
    all_pred, all_target = [], []
    
    with torch.no_grad():
        for X, Y in loader:
            X, Y = X.to(device), Y.to(device)
            pred = model(X)
            loss = criterion(pred, Y)
            
            total_loss += loss.item() * X.size(0)
            all_pred.append(pred.cpu())
            all_target.append(Y.cpu())
    
    all_pred = torch.cat(all_pred, dim=0)
    all_target = torch.cat(all_target, dim=0)
    mrae, rmse, sam = compute_metrics(all_pred, all_target)
    
    return total_loss / len(loader.dataset), mrae, rmse, sam


# ==================== 可视化 ====================
def plot_history(history, save_dir):
    fig, axes = plt.subplots(2, 2, figsize=(12, 10))
    
    # Loss
    axes[0, 0].plot(history['train_loss'], label='Train')
    axes[0, 0].plot(history['val_loss'], label='Val')
    axes[0, 0].set_xlabel('Epoch')
    axes[0, 0].set_ylabel('Loss')
    axes[0, 0].set_title('Loss Curve')
    axes[0, 0].legend()
    axes[0, 0].grid(True)
    
    # MRAE
    axes[0, 1].plot(history['val_mrae'])
    axes[0, 1].set_xlabel('Epoch')
    axes[0, 1].set_ylabel('MRAE')
    axes[0, 1].set_title('Validation MRAE')
    axes[0, 1].grid(True)
    
    # RMSE
    axes[1, 0].plot(history['val_rmse'])
    axes[1, 0].set_xlabel('Epoch')
    axes[1, 0].set_ylabel('RMSE')
    axes[1, 0].set_title('Validation RMSE')
    axes[1, 0].grid(True)
    
    # SAM
    axes[1, 1].plot(history['val_sam'])
    axes[1, 1].set_xlabel('Epoch')
    axes[1, 1].set_ylabel('SAM (°)')
    axes[1, 1].set_title('Validation SAM')
    axes[1, 1].grid(True)
    
    plt.tight_layout()
    plt.savefig(Path(save_dir) / 'training_history.png', dpi=150)
    plt.show()
    print(f"已保存训练曲线: {Path(save_dir) / 'training_history.png'}")


def visualize_predictions(model, loader, device, save_dir, n_samples=6):
    model.eval()
    wavelengths = np.linspace(400, 700, 31)
    
    # 获取一些样本
    X, Y = next(iter(loader))
    X, Y = X[:n_samples].to(device), Y[:n_samples]
    
    with torch.no_grad():
        pred = model(X).cpu()
    
    fig, axes = plt.subplots(2, 3, figsize=(15, 10))
    axes = axes.flatten()
    
    for i in range(n_samples):
        axes[i].plot(wavelengths, Y[i].numpy(), 'b-', linewidth=2, label='Ground Truth')
        axes[i].plot(wavelengths, pred[i].numpy(), 'r--', linewidth=2, label='Prediction')
        axes[i].set_xlabel('Wavelength (nm)')
        axes[i].set_ylabel('Reflectance')
        axes[i].set_title(f'Sample {i+1}')
        axes[i].legend()
        axes[i].grid(True)
        axes[i].set_ylim([0, 1])
    
    plt.tight_layout()
    plt.savefig(Path(save_dir) / 'predictions.png', dpi=150)
    plt.show()
    print(f"已保存预测可视化: {Path(save_dir) / 'predictions.png'}")


# ==================== 主训练流程 ====================
def train_model(cfg):
    # 设置随机种子
    torch.manual_seed(cfg.seed)
    np.random.seed(cfg.seed)
    
    # 创建保存目录
    Path(cfg.save_dir).mkdir(parents=True, exist_ok=True)
    
    # 加载数据
    X_train, Y_train, X_val, Y_val, X_test, Y_test = load_data(cfg.data_path)
    
    train_loader = DataLoader(
        TensorDataset(X_train, Y_train),
        batch_size=cfg.batch_size, shuffle=True, num_workers=4, pin_memory=True
    )
    val_loader = DataLoader(
        TensorDataset(X_val, Y_val),
        batch_size=cfg.batch_size, shuffle=False, num_workers=4, pin_memory=True
    )
    test_loader = DataLoader(
        TensorDataset(X_test, Y_test),
        batch_size=cfg.batch_size, shuffle=False, num_workers=4, pin_memory=True
    )
    
    # 创建模型
    model = FDM_CNN(cfg.input_dim, cfg.output_dim).to(cfg.device)
    print(f"\n模型参数量: {sum(p.numel() for p in model.parameters()):,}")
    print(f"设备: {cfg.device}")
    
    # 损失函数和优化器
    criterion = nn.MSELoss()
    optimizer = optim.AdamW(model.parameters(), lr=cfg.lr, weight_decay=cfg.weight_decay)
    scheduler = optim.lr_scheduler.CosineAnnealingLR(optimizer, T_max=cfg.epochs)
    
    # 训练记录
    history = {
        'train_loss': [], 'val_loss': [],
        'val_mrae': [], 'val_rmse': [], 'val_sam': []
    }
    best_val_loss = float('inf')
    
    print(f"\n开始训练 ({cfg.epochs} epochs)...")
    print("-" * 80)
    
    for epoch in range(1, cfg.epochs + 1):
        t0 = time.time()
        
        # 训练
        train_loss = train_epoch(model, train_loader, criterion, optimizer, cfg.device)
        
        # 验证
        val_loss, val_mrae, val_rmse, val_sam = validate(model, val_loader, criterion, cfg.device)
        
        # 学习率调度
        scheduler.step()
        
        # 记录
        history['train_loss'].append(train_loss)
        history['val_loss'].append(val_loss)
        history['val_mrae'].append(val_mrae)
        history['val_rmse'].append(val_rmse)
        history['val_sam'].append(val_sam)
        
        # 保存最优模型
        if val_loss < best_val_loss:
            best_val_loss = val_loss
            torch.save({
                'epoch': epoch,
                'model_state_dict': model.state_dict(),
                'optimizer_state_dict': optimizer.state_dict(),
                'val_loss': val_loss,
            }, Path(cfg.save_dir) / 'best_model.pth')
        
        # 打印进度
        elapsed = time.time() - t0
        print(f"Epoch {epoch:3d}/{cfg.epochs} | "
              f"Train: {train_loss:.6f} | Val: {val_loss:.6f} | "
              f"MRAE: {val_mrae:.4f} | RMSE: {val_rmse:.4f} | SAM: {val_sam:.2f}° | "
              f"Time: {elapsed:.1f}s")
    
    print("-" * 80)
    
    # 加载最优模型测试
    checkpoint = torch.load(Path(cfg.save_dir) / 'best_model.pth')
    model.load_state_dict(checkpoint['model_state_dict'])
    
    test_loss, test_mrae, test_rmse, test_sam = validate(model, test_loader, criterion, cfg.device)
    print(f"\n测试集结果:")
    print(f"  Loss: {test_loss:.6f}")
    print(f"  MRAE: {test_mrae:.4f}")
    print(f"  RMSE: {test_rmse:.4f}")
    print(f"  SAM:  {test_sam:.2f}°")
    
    # 保存训练曲线
    plot_history(history, cfg.save_dir)
    
    # 可视化预测结果
    visualize_predictions(model, test_loader, cfg.device, cfg.save_dir)
    
    return model, history


# ==================== 直接运行 ====================
if __name__ == '__main__':
    cfg = Config()
    model, history = train_model(cfg)
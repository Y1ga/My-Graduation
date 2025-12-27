"""
FDM 端到端光谱重建网络训练
输入: 时域信号 [batch, 1000]
输出: 光谱 [batch, 31]
"""

import torch
import torch.nn as nn
import torch.optim as optim
from torch.utils.data import Dataset, DataLoader
import h5py
import numpy as np
import matplotlib.pyplot as plt
from pathlib import Path
import time


# ==================== 数据集 ====================
class FDMDataset(Dataset):
    def __init__(self, mat_file, split='train'):
        print(f"加载 {split} 数据集...")
        
        with h5py.File(mat_file, 'r') as f:
            X = np.array(f[f'X_{split}']).T.astype(np.float32)
            Y = np.array(f[f'Y_{split}']).T.astype(np.float32)
        
        self.X = torch.from_numpy(X)
        self.Y = torch.from_numpy(Y)
        
        if self.X.dim() == 2:
            self.X = self.X.unsqueeze(1)
        
        print(f"  X_{split}: {self.X.shape}")
        print(f"  Y_{split}: {self.Y.shape}")
    
    def __len__(self):
        return len(self.X)
    
    def __getitem__(self, idx):
        return self.X[idx], self.Y[idx]


# ==================== 评估指标 ====================
def compute_rmse(pred, target):
    mse = torch.mean((pred - target) ** 2, dim=1)
    rmse = torch.sqrt(mse)
    return torch.mean(rmse).item()


def compute_psnr(pred, target, max_val=1.0):
    mse = torch.mean((pred - target) ** 2, dim=1)
    psnr = 10 * torch.log10(max_val ** 2 / (mse + 1e-10))
    return torch.mean(psnr).item()


# ==================== 网络模型 ====================
class FDMNet(nn.Module):
    def __init__(self, input_size=1000, output_size=31, dropout=0.5):
        super().__init__()
        
        self.encoder = nn.Sequential(
            nn.Conv1d(1, 64, kernel_size=7, stride=2, padding=3),
            nn.BatchNorm1d(64),
            nn.ReLU(inplace=True),
            nn.Dropout(dropout),
            
            nn.Conv1d(64, 128, kernel_size=5, stride=2, padding=2),
            nn.BatchNorm1d(128),
            nn.ReLU(inplace=True),
            nn.Dropout(dropout),
            
            nn.Conv1d(128, 256, kernel_size=5, stride=2, padding=2),
            nn.BatchNorm1d(256),
            nn.ReLU(inplace=True),
            nn.Dropout(dropout),
            
            nn.Conv1d(256, 512, kernel_size=3, stride=2, padding=1),
            nn.BatchNorm1d(512),
            nn.ReLU(inplace=True),
            
            nn.AdaptiveAvgPool1d(1),
        )
        
        self.decoder = nn.Sequential(
            nn.Flatten(),
            nn.Linear(512, 256),
            nn.ReLU(inplace=True),
            nn.Dropout(dropout),
            nn.Linear(256, 128),
            nn.ReLU(inplace=True),
            nn.Dropout(dropout),
            nn.Linear(128, output_size),
            nn.Sigmoid(),
        )
    
    def forward(self, x):
        x = self.encoder(x)
        x = self.decoder(x)
        return x


# ==================== 早停类 ====================
class EarlyStopping:
    def __init__(self, patience=10, min_delta=0, mode='max'):
        """
        Args:
            patience: 多少个 epoch 没有改善就停止
            min_delta: 最小改善量
            mode: 'max' 表示指标越大越好 (如 PSNR), 'min' 表示越小越好 (如 Loss)
        """
        self.patience = patience
        self.min_delta = min_delta
        self.mode = mode
        self.counter = 0
        self.best_score = None
        self.early_stop = False
    
    def __call__(self, score):
        if self.best_score is None:
            self.best_score = score
            return True  # 第一次，保存模型
        
        if self.mode == 'max':
            improved = score > self.best_score + self.min_delta
        else:
            improved = score < self.best_score - self.min_delta
        
        if improved:
            self.best_score = score
            self.counter = 0
            return True  # 有改善，保存模型
        else:
            self.counter += 1
            if self.counter >= self.patience:
                self.early_stop = True
            return False  # 没改善，不保存


# ==================== 训练函数 ====================
def train_epoch(model, loader, criterion, optimizer, device):
    model.train()
    total_loss = 0
    total_rmse = 0
    total_psnr = 0
    n_batches = 0
    
    for X, Y in loader:
        X, Y = X.to(device), Y.to(device)
        
        optimizer.zero_grad()
        pred = model(X)
        loss = criterion(pred, Y)
        loss.backward()
        optimizer.step()
        
        total_loss += loss.item()
        total_rmse += compute_rmse(pred, Y)
        total_psnr += compute_psnr(pred, Y)
        n_batches += 1
    
    return {
        'loss': total_loss / n_batches,
        'rmse': total_rmse / n_batches,
        'psnr': total_psnr / n_batches,
    }


def validate(model, loader, criterion, device):
    model.eval()
    total_loss = 0
    total_rmse = 0
    total_psnr = 0
    n_batches = 0
    
    with torch.no_grad():
        for X, Y in loader:
            X, Y = X.to(device), Y.to(device)
            pred = model(X)
            loss = criterion(pred, Y)
            
            total_loss += loss.item()
            total_rmse += compute_rmse(pred, Y)
            total_psnr += compute_psnr(pred, Y)
            n_batches += 1
    
    return {
        'loss': total_loss / n_batches,
        'rmse': total_rmse / n_batches,
        'psnr': total_psnr / n_batches,
    }


# ==================== 可视化 ====================
def plot_results(model, test_loader, device, save_path='results.png'):
    model.eval()
    
    X_batch, Y_batch = next(iter(test_loader))
    X_batch, Y_batch = X_batch.to(device), Y_batch.to(device)
    
    with torch.no_grad():
        pred = model(X_batch)
    
    pred = pred.cpu().numpy()
    target = Y_batch.cpu().numpy()
    
    wav = np.linspace(400, 700, 31)
    
    fig, axes = plt.subplots(3, 4, figsize=(16, 12))
    
    for i in range(12):
        ax = axes[i // 4, i % 4]
        ax.plot(wav, target[i], 'b-', linewidth=2, label='GT')
        ax.plot(wav, pred[i], 'r--', linewidth=2, label='Pred')
        
        rmse = np.sqrt(np.mean((pred[i] - target[i]) ** 2))
        mse = np.mean((pred[i] - target[i]) ** 2)
        psnr = 10 * np.log10(1.0 / (mse + 1e-10))
        
        ax.set_title(f'RMSE={rmse:.4f}, PSNR={psnr:.1f}dB')
        ax.set_xlabel('Wavelength (nm)')
        ax.set_ylabel('Reflectance')
        ax.legend(loc='best', fontsize=8)
        ax.grid(True, alpha=0.3)
    
    plt.tight_layout()
    plt.savefig(save_path, dpi=150)
    plt.close()
    print(f"结果图已保存: {save_path}")


def plot_training_history(history, save_path='training_history.png'):
    fig, axes = plt.subplots(1, 3, figsize=(15, 4))
    
    ax = axes[0]
    ax.plot(history['train_loss'], label='Train')
    ax.plot(history['val_loss'], label='Val')
    ax.set_xlabel('Epoch')
    ax.set_ylabel('Loss')
    ax.set_title('Loss')
    ax.legend()
    ax.grid(True)
    
    ax = axes[1]
    ax.plot(history['train_rmse'], label='Train')
    ax.plot(history['val_rmse'], label='Val')
    ax.set_xlabel('Epoch')
    ax.set_ylabel('RMSE')
    ax.set_title('RMSE')
    ax.legend()
    ax.grid(True)
    
    ax = axes[2]
    ax.plot(history['train_psnr'], label='Train')
    ax.plot(history['val_psnr'], label='Val')
    ax.set_xlabel('Epoch')
    ax.set_ylabel('PSNR (dB)')
    ax.set_title('PSNR')
    ax.legend()
    ax.grid(True)
    
    plt.tight_layout()
    plt.savefig(save_path, dpi=150)
    plt.close()
    print(f"训练曲线已保存: {save_path}")


# ==================== 主函数 ====================
def main():
    # 配置
    config = {
        'data_path': r'W:\Github\My-Repository\My-Graduation\paper-02\generate_dataset\fdm_e2e_cave100k_kaist50k_noise5pct_aug.mat',
        'batch_size': 128,
        'learning_rate': 1e-3,
        'epochs': 100,
        'patience': 5,         # 早停耐心值
        'dropout': 0.5,         # Dropout 比例
        'weight_decay': 1e-3,   # L2 正则化
        'device': 'cuda' if torch.cuda.is_available() else 'cpu',
        'save_dir': 'checkpoints',
    }
    
    print("=" * 60)
    print("FDM 端到端光谱重建训练")
    print("=" * 60)
    print(f"设备: {config['device']}")
    print(f"数据: {config['data_path']}")
    print(f"Batch Size: {config['batch_size']}")
    print(f"Learning Rate: {config['learning_rate']}")
    print(f"Weight Decay: {config['weight_decay']}")
    print(f"Dropout: {config['dropout']}")
    print(f"Early Stopping Patience: {config['patience']}")
    print(f"Max Epochs: {config['epochs']}")
    print("=" * 60)
    
    save_dir = Path(config['save_dir'])
    save_dir.mkdir(exist_ok=True)
    
    # 加载数据
    train_dataset = FDMDataset(config['data_path'], 'train')
    val_dataset = FDMDataset(config['data_path'], 'val')
    test_dataset = FDMDataset(config['data_path'], 'test')
    
    train_loader = DataLoader(train_dataset, batch_size=config['batch_size'], 
                              shuffle=True, num_workers=4, pin_memory=True)
    val_loader = DataLoader(val_dataset, batch_size=config['batch_size'], 
                            shuffle=False, num_workers=4, pin_memory=True)
    test_loader = DataLoader(test_dataset, batch_size=config['batch_size'], 
                             shuffle=False, num_workers=4, pin_memory=True)
    
    # 创建模型
    device = torch.device(config['device'])
    model = FDMNet(input_size=1000, output_size=31, dropout=config['dropout']).to(device)
    
    total_params = sum(p.numel() for p in model.parameters())
    print(f"模型参数量: {total_params:,}")
    
    # 损失函数和优化器
    criterion = nn.MSELoss()
    optimizer = optim.AdamW(model.parameters(), lr=config['learning_rate'], 
                            weight_decay=config['weight_decay'])
    scheduler = optim.lr_scheduler.ReduceLROnPlateau(optimizer, mode='max', 
                                                      factor=0.5, patience=5, verbose=True)
    
    # 早停
    early_stopping = EarlyStopping(patience=config['patience'], mode='max')
    
    # 训练历史
    history = {
        'train_loss': [], 'val_loss': [],
        'train_rmse': [], 'val_rmse': [],
        'train_psnr': [], 'val_psnr': [],
    }
    
    # 训练循环
    print("\n" + "=" * 90)
    print(f"{'Epoch':>5} | {'Train Loss':>10} {'RMSE':>8} {'PSNR':>8} | "
          f"{'Val Loss':>10} {'RMSE':>8} {'PSNR':>8} | {'LR':>9} | {'Time':>6}")
    print("=" * 90)
    
    for epoch in range(config['epochs']):
        start_time = time.time()
        
        train_metrics = train_epoch(model, train_loader, criterion, optimizer, device)
        val_metrics = validate(model, val_loader, criterion, device)
        
        # 更新学习率
        scheduler.step(val_metrics['psnr'])
        
        # 记录历史
        history['train_loss'].append(train_metrics['loss'])
        history['train_rmse'].append(train_metrics['rmse'])
        history['train_psnr'].append(train_metrics['psnr'])
        history['val_loss'].append(val_metrics['loss'])
        history['val_rmse'].append(val_metrics['rmse'])
        history['val_psnr'].append(val_metrics['psnr'])
        
        # 早停检查
        if early_stopping(val_metrics['psnr']):
            torch.save({
                'epoch': epoch,
                'model_state_dict': model.state_dict(),
                'optimizer_state_dict': optimizer.state_dict(),
                'psnr': val_metrics['psnr'],
                'rmse': val_metrics['rmse'],
                'config': config,
            }, save_dir / 'best_model.pth')
            marker = ' *'
        else:
            marker = f' ({early_stopping.counter}/{config["patience"]})'
        
        elapsed = time.time() - start_time
        lr = optimizer.param_groups[0]['lr']
        
        print(f"{epoch+1:5d} | "
              f"{train_metrics['loss']:10.6f} {train_metrics['rmse']:8.4f} {train_metrics['psnr']:7.2f}dB | "
              f"{val_metrics['loss']:10.6f} {val_metrics['rmse']:8.4f} {val_metrics['psnr']:7.2f}dB | "
              f"{lr:9.2e} | {elapsed:5.1f}s{marker}")
        
        # 早停
        if early_stopping.early_stop:
            print(f"\n早停触发! 在 Epoch {epoch+1} 停止训练")
            break
    
    print("=" * 90)
    
    # 加载最佳模型
    checkpoint = torch.load(save_dir / 'best_model.pth')
    model.load_state_dict(checkpoint['model_state_dict'])
    print(f"\n最佳模型: Epoch {checkpoint['epoch']+1}, PSNR={checkpoint['psnr']:.2f}dB, RMSE={checkpoint['rmse']:.4f}")
    
    # 测试
    print("\n" + "=" * 40)
    print("测试集评估 (KAIST)")
    print("=" * 40)
    test_metrics = validate(model, test_loader, criterion, device)
    print(f"  Loss: {test_metrics['loss']:.6f}")
    print(f"  RMSE: {test_metrics['rmse']:.4f}")
    print(f"  PSNR: {test_metrics['psnr']:.2f} dB")
    print("=" * 40)
    
    # 可视化
    plot_training_history(history, save_dir / 'training_history.png')
    plot_results(model, test_loader, device, save_dir / 'test_results.png')
    
    print("\n训练完成!")


if __name__ == '__main__':
    main()


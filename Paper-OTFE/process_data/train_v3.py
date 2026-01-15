"""
FDM光谱重建神经网络训练脚本
输入: 50MHz采样的时域信号 (17500点)
输出: 12个LED的归一化幅值
"""

import torch
import torch.nn as nn
import torch.optim as optim
from torch.utils.data import Dataset, DataLoader
import numpy as np
import h5py
import matplotlib.pyplot as plt
from pathlib import Path
import time


# ==================== 数据集 ====================
class FDMDataset(Dataset):
    """FDM时域信号数据集"""

    def __init__(self, mat_file, normalize_x=True):
        """
        Args:
            mat_file: .mat文件路径 (v7.3格式，用h5py读取)
            normalize_x: 是否对输入信号归一化
        """
        with h5py.File(mat_file, "r") as f:
            # 获取数据键名
            keys = list(f.keys())
            x_key = [k for k in keys if k.startswith("X_")][0]
            y_key = [k for k in keys if k.startswith("Y_")][0]

            # h5py读取的数据是转置的，需要.T
            self.X = np.array(f[x_key]).T.astype(np.float32)
            self.Y = np.array(f[y_key]).T.astype(np.float32)

        self.normalize_x = normalize_x
        if normalize_x:
            # 每个样本独立归一化 (除以std)
            self.X_std = np.std(self.X, axis=1, keepdims=True)
            self.X_std[self.X_std == 0] = 1  # 避免除零
            self.X = self.X / self.X_std

    def __len__(self):
        return len(self.X)

    def __getitem__(self, idx):
        return torch.from_numpy(self.X[idx].copy()), torch.from_numpy(
            self.Y[idx].copy()
        )


# ==================== 模型 ====================
class Conv1DNet(nn.Module):
    """1D卷积网络"""

    def __init__(self, input_length=17500, output_dim=12):
        super().__init__()

        self.conv_layers = nn.Sequential(
            # Block 1: 17500 -> 4375
            nn.Conv1d(1, 32, kernel_size=7, stride=1, padding=3),
            nn.BatchNorm1d(32),
            nn.ReLU(),
            nn.MaxPool1d(4),
            # Block 2: 4375 -> 1093
            nn.Conv1d(32, 64, kernel_size=5, stride=1, padding=2),
            nn.BatchNorm1d(64),
            nn.ReLU(),
            nn.MaxPool1d(4),
            # Block 3: 1093 -> 273
            nn.Conv1d(64, 128, kernel_size=5, stride=1, padding=2),
            nn.BatchNorm1d(128),
            nn.ReLU(),
            nn.MaxPool1d(4),
            # Block 4: 273 -> 68
            nn.Conv1d(128, 256, kernel_size=3, stride=1, padding=1),
            nn.BatchNorm1d(256),
            nn.ReLU(),
            nn.MaxPool1d(4),
            # Block 5: 68 -> 17
            nn.Conv1d(256, 256, kernel_size=3, stride=1, padding=1),
            nn.BatchNorm1d(256),
            nn.ReLU(),
            nn.MaxPool1d(4),
        )

        # 计算展平后的尺寸
        self._flat_size = self._get_flat_size(input_length)

        self.fc_layers = nn.Sequential(
            nn.Linear(self._flat_size, 512),
            nn.ReLU(),
            nn.Dropout(0.3),
            nn.Linear(512, 128),
            nn.ReLU(),
            nn.Dropout(0.3),
            nn.Linear(128, output_dim),
        )

    def _get_flat_size(self, input_length):
        with torch.no_grad():
            x = torch.zeros(1, 1, input_length)
            x = self.conv_layers(x)
            return x.view(1, -1).size(1)

    def forward(self, x):
        # x: (batch, seq_len) -> (batch, 1, seq_len)
        x = x.unsqueeze(1)
        x = self.conv_layers(x)
        x = x.view(x.size(0), -1)
        x = self.fc_layers(x)
        return x


class FFTNet(nn.Module):
    """FFT特征 + MLP"""

    def __init__(self, n_fft=32768, fs=50e6, output_dim=12):
        super().__init__()

        self.n_fft = n_fft
        self.fs = fs

        # LED频率
        self.led_freqs = (
            torch.tensor([30, 50, 70, 110, 130, 170, 190, 230, 290, 310, 370, 410])
            * 1e3
        )

        # 计算频率bin索引 (±3kHz范围)
        self.freq_indices = []
        freq_resolution = fs / n_fft
        for f in self.led_freqs:
            center_bin = int(f / freq_resolution)
            half_width = int(3e3 / freq_resolution) + 1
            self.freq_indices.append(
                (center_bin - half_width, center_bin + half_width + 1)
            )

        # MLP处理提取的FFT特征
        self.mlp = nn.Sequential(
            nn.Linear(12, 64),
            nn.ReLU(),
            nn.Linear(64, 64),
            nn.ReLU(),
            nn.Linear(64, output_dim),
        )

    def forward(self, x):
        # FFT
        fft_result = torch.fft.rfft(x, n=self.n_fft)
        fft_mag = torch.abs(fft_result)

        # 提取12个频率的峰值
        features = []
        for start, end in self.freq_indices:
            peak = torch.max(fft_mag[:, start:end], dim=1)[0]
            features.append(peak)

        features = torch.stack(features, dim=1)  # (batch, 12)

        # MLP
        out = self.mlp(features)
        return out


class HybridNet(nn.Module):
    """混合网络: FFT特征 + 时域卷积"""

    def __init__(self, input_length=17500, n_fft=32768, fs=50e6, output_dim=12):
        super().__init__()

        self.n_fft = n_fft
        self.led_freqs = (
            torch.tensor([30, 50, 70, 110, 130, 170, 190, 230, 290, 310, 370, 410])
            * 1e3
        )

        # FFT频率索引
        self.freq_indices = []
        freq_resolution = fs / n_fft
        for f in self.led_freqs:
            center_bin = int(f / freq_resolution)
            half_width = int(3e3 / freq_resolution) + 1
            self.freq_indices.append(
                (center_bin - half_width, center_bin + half_width + 1)
            )

        # 时域卷积分支 (轻量版)
        self.conv_branch = nn.Sequential(
            nn.Conv1d(1, 16, kernel_size=7, stride=4, padding=3),
            nn.BatchNorm1d(16),
            nn.ReLU(),
            nn.Conv1d(16, 32, kernel_size=5, stride=4, padding=2),
            nn.BatchNorm1d(32),
            nn.ReLU(),
            nn.AdaptiveAvgPool1d(32),
        )

        # 融合层
        self.fusion = nn.Sequential(
            nn.Linear(12 + 32 * 32, 256),
            nn.ReLU(),
            nn.Dropout(0.3),
            nn.Linear(256, 64),
            nn.ReLU(),
            nn.Linear(64, output_dim),
        )

    def forward(self, x):
        # FFT分支
        fft_result = torch.fft.rfft(x, n=self.n_fft)
        fft_mag = torch.abs(fft_result)

        fft_features = []
        for start, end in self.freq_indices:
            peak = torch.max(fft_mag[:, start:end], dim=1)[0]
            fft_features.append(peak)
        fft_features = torch.stack(fft_features, dim=1)  # (batch, 12)

        # 时域分支
        x_conv = x.unsqueeze(1)
        conv_features = self.conv_branch(x_conv)
        conv_features = conv_features.view(conv_features.size(0), -1)  # (batch, 32*32)

        # 融合
        combined = torch.cat([fft_features, conv_features], dim=1)
        out = self.fusion(combined)
        return out


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


def evaluate(model, loader, criterion, device):
    model.eval()
    total_loss = 0
    all_preds = []
    all_labels = []

    with torch.no_grad():
        for X, Y in loader:
            X, Y = X.to(device), Y.to(device)
            pred = model(X)
            loss = criterion(pred, Y)
            total_loss += loss.item() * X.size(0)

            all_preds.append(pred.cpu().numpy())
            all_labels.append(Y.cpu().numpy())

    all_preds = np.concatenate(all_preds, axis=0)
    all_labels = np.concatenate(all_labels, axis=0)

    # 计算RMSE
    rmse = np.sqrt(np.mean((all_preds - all_labels) ** 2))

    # 计算相对误差
    rel_error = np.mean(np.abs(all_preds - all_labels) / (all_labels + 1e-8)) * 100

    return total_loss / len(loader.dataset), rmse, rel_error


# ==================== 主函数 ====================
def main():
    # 配置
    data_dir = Path(".")
    device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
    print(f"Device: {device}")

    # 超参数
    batch_size = 64
    learning_rate = 1e-3
    num_epochs = 100
    model_type = "conv1d"  # 'conv1d', 'fft', 'hybrid'

    # 加载数据
    print("\n加载数据...")
    train_dataset = FDMDataset(data_dir / "dataset_50MHz_train.mat", normalize_x=True)
    val_dataset = FDMDataset(data_dir / "dataset_50MHz_val.mat", normalize_x=True)
    test_dataset = FDMDataset(data_dir / "dataset_50MHz_test.mat", normalize_x=True)
    real_dataset = FDMDataset(data_dir / "dataset_50MHz_real.mat", normalize_x=True)

    train_loader = DataLoader(
        train_dataset, batch_size=batch_size, shuffle=True, num_workers=0
    )
    val_loader = DataLoader(val_dataset, batch_size=batch_size, shuffle=False)
    test_loader = DataLoader(test_dataset, batch_size=batch_size, shuffle=False)
    real_loader = DataLoader(real_dataset, batch_size=24, shuffle=False)

    print(
        f"训练集: {len(train_dataset)}, 验证集: {len(val_dataset)}, 测试集: {len(test_dataset)}, 真实: {len(real_dataset)}"
    )

    # 模型
    print(f"\n创建模型: {model_type}")
    if model_type == "conv1d":
        model = Conv1DNet(input_length=17500, output_dim=12)
    elif model_type == "fft":
        model = FFTNet(n_fft=32768, fs=50e6, output_dim=12)
    elif model_type == "hybrid":
        model = HybridNet(input_length=17500, n_fft=32768, fs=50e6, output_dim=12)
    else:
        raise ValueError(f"Unknown model type: {model_type}")

    model = model.to(device)
    print(f"参数量: {sum(p.numel() for p in model.parameters()):,}")

    # 损失函数和优化器
    criterion = nn.MSELoss()
    optimizer = optim.Adam(model.parameters(), lr=learning_rate)
    scheduler = optim.lr_scheduler.ReduceLROnPlateau(
        optimizer, mode="min", factor=0.5, patience=10, verbose=True
    )

    # 训练
    print("\n开始训练...")
    best_val_loss = float("inf")
    train_losses = []
    val_losses = []

    for epoch in range(num_epochs):
        start_time = time.time()

        train_loss = train_epoch(model, train_loader, criterion, optimizer, device)
        val_loss, val_rmse, val_rel_error = evaluate(
            model, val_loader, criterion, device
        )

        train_losses.append(train_loss)
        val_losses.append(val_loss)

        scheduler.step(val_loss)

        elapsed = time.time() - start_time

        if val_loss < best_val_loss:
            best_val_loss = val_loss
            torch.save(model.state_dict(), "best_model.pth")
            marker = " *"
        else:
            marker = ""

        if (epoch + 1) % 10 == 0 or epoch == 0:
            print(
                f"Epoch {epoch+1:3d}/{num_epochs} | "
                f"Train Loss: {train_loss:.6f} | "
                f"Val Loss: {val_loss:.6f} | "
                f"Val RMSE: {val_rmse:.4f} | "
                f"Val RelErr: {val_rel_error:.2f}% | "
                f"Time: {elapsed:.1f}s{marker}"
            )

    # 加载最佳模型
    model.load_state_dict(torch.load("best_model.pth"))

    # 测试集评估
    print("\n===== 测试集评估 =====")
    test_loss, test_rmse, test_rel_error = evaluate(
        model, test_loader, criterion, device
    )
    print(f"Test Loss: {test_loss:.6f}")
    print(f"Test RMSE: {test_rmse:.4f}")
    print(f"Test RelErr: {test_rel_error:.2f}%")

    # 真实数据评估
    print("\n===== 真实数据评估 =====")
    real_loss, real_rmse, real_rel_error = evaluate(
        model, real_loader, criterion, device
    )
    print(f"Real Loss: {real_loss:.6f}")
    print(f"Real RMSE: {real_rmse:.4f}")
    print(f"Real RelErr: {real_rel_error:.2f}%")

    # 详细查看真实数据预测
    model.eval()
    with torch.no_grad():
        X_real, Y_real = next(iter(real_loader))
        X_real = X_real.to(device)
        pred_real = model(X_real).cpu().numpy()
        Y_real = Y_real.numpy()

    print("\n24色卡预测结果:")
    print("色卡\t预测值(平均)\t真实值(平均)\t相对误差")
    print("-" * 50)
    for i in range(24):
        pred_mean = np.mean(pred_real[i])
        true_mean = np.mean(Y_real[i])
        rel_err = np.mean(np.abs(pred_real[i] - Y_real[i]) / (Y_real[i] + 1e-8)) * 100
        print(f"{i+1}\t{pred_mean:.4f}\t\t{true_mean:.4f}\t\t{rel_err:.2f}%")

    # 绘图
    fig, axes = plt.subplots(2, 2, figsize=(12, 10))

    # 训练曲线
    axes[0, 0].plot(train_losses, label="Train")
    axes[0, 0].plot(val_losses, label="Val")
    axes[0, 0].set_xlabel("Epoch")
    axes[0, 0].set_ylabel("Loss")
    axes[0, 0].set_title("Training Curve")
    axes[0, 0].legend()
    axes[0, 0].grid(True)

    # 预测 vs 真实 (测试集)
    model.eval()
    with torch.no_grad():
        all_preds = []
        all_labels = []
        for X, Y in test_loader:
            X = X.to(device)
            pred = model(X).cpu().numpy()
            all_preds.append(pred)
            all_labels.append(Y.numpy())
        all_preds = np.concatenate(all_preds, axis=0).flatten()
        all_labels = np.concatenate(all_labels, axis=0).flatten()

    axes[0, 1].scatter(all_labels, all_preds, alpha=0.3, s=5)
    axes[0, 1].plot([0, 1.2], [0, 1.2], "r--")
    axes[0, 1].set_xlabel("True")
    axes[0, 1].set_ylabel("Predicted")
    axes[0, 1].set_title("Test Set: Pred vs True")
    axes[0, 1].grid(True)

    # 真实数据预测
    axes[1, 0].scatter(Y_real.flatten(), pred_real.flatten(), alpha=0.7)
    axes[1, 0].plot([0, 1.2], [0, 1.2], "r--")
    axes[1, 0].set_xlabel("True")
    axes[1, 0].set_ylabel("Predicted")
    axes[1, 0].set_title("Real Data: Pred vs True")
    axes[1, 0].grid(True)

    # 各频率误差
    freq_errors = np.abs(pred_real - Y_real) / (Y_real + 1e-8) * 100
    freq_mean_errors = np.mean(freq_errors, axis=0)
    led_freqs_khz = [30, 50, 70, 110, 130, 170, 190, 230, 290, 310, 370, 410]
    axes[1, 1].bar(range(12), freq_mean_errors)
    axes[1, 1].set_xticks(range(12))
    axes[1, 1].set_xticklabels([f"{f}k" for f in led_freqs_khz], rotation=45)
    axes[1, 1].set_xlabel("Frequency")
    axes[1, 1].set_ylabel("Relative Error (%)")
    axes[1, 1].set_title("Real Data: Error by Frequency")
    axes[1, 1].grid(True)

    plt.tight_layout()
    plt.savefig("training_results.png", dpi=150)
    plt.close()

    print("\n图像已保存: training_results.png")
    print("模型已保存: best_model.pth")


if __name__ == "__main__":
    main()

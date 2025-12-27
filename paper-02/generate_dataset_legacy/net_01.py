"""
E2E FDM Spectroscopy Neural Network Training
端到端频分复用光谱重建网络

输入: 时域信号 (batch, 1000)
输出: 光谱 (batch, 31)
"""

import os
import numpy as np
import torch
import torch.nn as nn
import torch.optim as optim
from torch.utils.data import DataLoader, TensorDataset
import matplotlib.pyplot as plt
from scipy.io import loadmat
from tqdm import tqdm
import argparse
from datetime import datetime


# ===================== 网络定义 =====================


class FDMNet_CNN(nn.Module):
    """1D CNN 网络"""

    def __init__(self, input_dim=1000, output_dim=31):
        super().__init__()

        # 1D卷积层: 提取时域特征
        self.conv_layers = nn.Sequential(
            # (batch, 1, 1000) -> (batch, 32, 500)
            nn.Conv1d(1, 32, kernel_size=7, stride=2, padding=3),
            nn.BatchNorm1d(32),
            nn.ReLU(),
            # (batch, 32, 500) -> (batch, 64, 250)
            nn.Conv1d(32, 64, kernel_size=5, stride=2, padding=2),
            nn.BatchNorm1d(64),
            nn.ReLU(),
            # (batch, 64, 250) -> (batch, 128, 125)
            nn.Conv1d(64, 128, kernel_size=5, stride=2, padding=2),
            nn.BatchNorm1d(128),
            nn.ReLU(),
            # (batch, 128, 125) -> (batch, 256, 62)
            nn.Conv1d(128, 256, kernel_size=5, stride=2, padding=2),
            nn.BatchNorm1d(256),
            nn.ReLU(),
            # (batch, 256, 62) -> (batch, 256, 31)
            nn.Conv1d(256, 256, kernel_size=4, stride=2, padding=1),
            nn.BatchNorm1d(256),
            nn.ReLU(),
        )

        # 全连接层: 输出光谱
        self.fc_layers = nn.Sequential(
            nn.Flatten(),  # (batch, 256*31) = (batch, 7936)
            nn.Linear(256 * 31, 512),
            nn.ReLU(),
            nn.Dropout(0.3),
            nn.Linear(512, 128),
            nn.ReLU(),
            nn.Linear(128, output_dim),
        )

    def forward(self, x):
        # x: (batch, 1000)
        x = x.unsqueeze(1)  # (batch, 1, 1000)
        x = self.conv_layers(x)  # (batch, 256, 31)
        x = self.fc_layers(x)  # (batch, 31)
        return x


class FDMNet_MLP(nn.Module):
    """MLP Baseline"""

    def __init__(self, input_dim=1000, output_dim=31):
        super().__init__()

        self.layers = nn.Sequential(
            nn.Linear(input_dim, 512),
            nn.ReLU(),
            nn.BatchNorm1d(512),
            nn.Dropout(0.3),
            nn.Linear(512, 256),
            nn.ReLU(),
            nn.BatchNorm1d(256),
            nn.Dropout(0.3),
            nn.Linear(256, 128),
            nn.ReLU(),
            nn.BatchNorm1d(128),
            nn.Linear(128, 64),
            nn.ReLU(),
            nn.Linear(64, output_dim),
        )

    def forward(self, x):
        return self.layers(x)


class FDMNet_ResCNN(nn.Module):
    """带残差连接的1D CNN"""

    def __init__(self, input_dim=1000, output_dim=31):
        super().__init__()

        # 初始卷积
        self.conv_in = nn.Sequential(
            nn.Conv1d(1, 64, kernel_size=7, stride=2, padding=3),
            nn.BatchNorm1d(64),
            nn.ReLU(),
        )

        # 残差块
        self.res_block1 = self._make_res_block(64, 64)
        self.res_block2 = self._make_res_block(64, 128, stride=2)
        self.res_block3 = self._make_res_block(128, 256, stride=2)
        self.res_block4 = self._make_res_block(256, 256, stride=2)

        # 全局平均池化 + 全连接
        self.global_pool = nn.AdaptiveAvgPool1d(1)
        self.fc = nn.Sequential(
            nn.Linear(256, 128),
            nn.ReLU(),
            nn.Linear(128, output_dim),
        )

    def _make_res_block(self, in_ch, out_ch, stride=1):
        """创建残差块"""
        downsample = None
        if stride != 1 or in_ch != out_ch:
            downsample = nn.Sequential(
                nn.Conv1d(in_ch, out_ch, kernel_size=1, stride=stride),
                nn.BatchNorm1d(out_ch),
            )

        return ResBlock(in_ch, out_ch, stride, downsample)

    def forward(self, x):
        x = x.unsqueeze(1)  # (batch, 1, 1000)
        x = self.conv_in(x)  # (batch, 64, 500)
        x = self.res_block1(x)  # (batch, 64, 500)
        x = self.res_block2(x)  # (batch, 128, 250)
        x = self.res_block3(x)  # (batch, 256, 125)
        x = self.res_block4(x)  # (batch, 256, 63)
        x = self.global_pool(x)  # (batch, 256, 1)
        x = x.squeeze(-1)  # (batch, 256)
        x = self.fc(x)  # (batch, 31)
        return x


class ResBlock(nn.Module):
    """残差块"""

    def __init__(self, in_ch, out_ch, stride=1, downsample=None):
        super().__init__()
        self.conv1 = nn.Conv1d(in_ch, out_ch, kernel_size=3, stride=stride, padding=1)
        self.bn1 = nn.BatchNorm1d(out_ch)
        self.conv2 = nn.Conv1d(out_ch, out_ch, kernel_size=3, stride=1, padding=1)
        self.bn2 = nn.BatchNorm1d(out_ch)
        self.relu = nn.ReLU()
        self.downsample = downsample

    def forward(self, x):
        identity = x
        out = self.relu(self.bn1(self.conv1(x)))
        out = self.bn2(self.conv2(out))
        if self.downsample is not None:
            identity = self.downsample(x)
        out += identity
        out = self.relu(out)
        return out


# ===================== 数据加载 =====================


def load_data(data_path, batch_size=64):
    """加载数据"""
    print(f"Loading data from: {data_path}")

    if data_path.endswith(".mat"):
        # 尝试用scipy读取（v7.2及以下）
        try:
            data = loadmat(data_path)
            X_train = data["X_train"].astype(np.float32)
            Y_train = data["Y_train"].astype(np.float32)
            X_val = data["X_val"].astype(np.float32)
            Y_val = data["Y_val"].astype(np.float32)
            X_test = data["X_test"].astype(np.float32)
            Y_test = data["Y_test"].astype(np.float32)
        except NotImplementedError:
            # v7.3格式，用h5py读取
            import h5py

            print("  Detected v7.3 format, using h5py...")
            with h5py.File(data_path, "r") as f:
                # h5py读取的数据是转置的，需要.T
                X_train = np.array(f["X_train"]).T.astype(np.float32)
                Y_train = np.array(f["Y_train"]).T.astype(np.float32)
                X_val = np.array(f["X_val"]).T.astype(np.float32)
                Y_val = np.array(f["Y_val"]).T.astype(np.float32)
                X_test = np.array(f["X_test"]).T.astype(np.float32)
                Y_test = np.array(f["Y_test"]).T.astype(np.float32)
    else:
        # NPY格式
        X_train = np.load(os.path.join(data_path, "X_train.npy")).astype(np.float32)
        Y_train = np.load(os.path.join(data_path, "Y_train.npy")).astype(np.float32)
        X_val = np.load(os.path.join(data_path, "X_val.npy")).astype(np.float32)
        Y_val = np.load(os.path.join(data_path, "Y_val.npy")).astype(np.float32)
        X_test = np.load(os.path.join(data_path, "X_test.npy")).astype(np.float32)
        Y_test = np.load(os.path.join(data_path, "Y_test.npy")).astype(np.float32)

    print(f"  Train: X={X_train.shape}, Y={Y_train.shape}")
    print(f"  Val:   X={X_val.shape}, Y={Y_val.shape}")
    print(f"  Test:  X={X_test.shape}, Y={Y_test.shape}")

    # 转换为PyTorch张量
    train_dataset = TensorDataset(torch.from_numpy(X_train), torch.from_numpy(Y_train))
    val_dataset = TensorDataset(torch.from_numpy(X_val), torch.from_numpy(Y_val))
    test_dataset = TensorDataset(torch.from_numpy(X_test), torch.from_numpy(Y_test))

    train_loader = DataLoader(
        train_dataset, batch_size=batch_size, shuffle=True, num_workers=0
    )
    val_loader = DataLoader(
        val_dataset, batch_size=batch_size, shuffle=False, num_workers=0
    )
    test_loader = DataLoader(
        test_dataset, batch_size=batch_size, shuffle=False, num_workers=0
    )

    return train_loader, val_loader, test_loader


# ===================== 评估指标 =====================


def compute_metrics(pred, target):
    """计算评估指标"""
    # MSE
    mse = torch.mean((pred - target) ** 2).item()

    # RMSE
    rmse = np.sqrt(mse)

    # MAE
    mae = torch.mean(torch.abs(pred - target)).item()

    # MRAE (Mean Relative Absolute Error)
    mrae = torch.mean(torch.abs(pred - target) / (torch.abs(target) + 1e-6)).item()

    # SAM (Spectral Angle Mapper) - 平均光谱角
    dot_product = torch.sum(pred * target, dim=1)
    norm_pred = torch.norm(pred, dim=1)
    norm_target = torch.norm(target, dim=1)
    cos_sim = dot_product / (norm_pred * norm_target + 1e-6)
    cos_sim = torch.clamp(cos_sim, -1, 1)
    sam = torch.mean(torch.acos(cos_sim)).item() * 180 / np.pi  # 转换为度

    return {"mse": mse, "rmse": rmse, "mae": mae, "mrae": mrae, "sam": sam}


# ===================== 训练函数 =====================


def train_one_epoch(model, train_loader, criterion, optimizer, device):
    """训练一个epoch"""
    model.train()
    total_loss = 0

    for batch_x, batch_y in train_loader:
        batch_x = batch_x.to(device)
        batch_y = batch_y.to(device)

        optimizer.zero_grad()
        pred = model(batch_x)
        loss = criterion(pred, batch_y)
        loss.backward()
        optimizer.step()

        total_loss += loss.item() * batch_x.size(0)

    return total_loss / len(train_loader.dataset)


def evaluate(model, data_loader, criterion, device):
    """评估模型"""
    model.eval()
    total_loss = 0
    all_preds = []
    all_targets = []

    with torch.no_grad():
        for batch_x, batch_y in data_loader:
            batch_x = batch_x.to(device)
            batch_y = batch_y.to(device)

            pred = model(batch_x)
            loss = criterion(pred, batch_y)

            total_loss += loss.item() * batch_x.size(0)
            all_preds.append(pred.cpu())
            all_targets.append(batch_y.cpu())

    all_preds = torch.cat(all_preds, dim=0)
    all_targets = torch.cat(all_targets, dim=0)

    avg_loss = total_loss / len(data_loader.dataset)
    metrics = compute_metrics(all_preds, all_targets)

    return avg_loss, metrics, all_preds, all_targets


# ===================== 可视化 =====================


def plot_training_curves(train_losses, val_losses, save_path):
    """绘制训练曲线"""
    plt.figure(figsize=(10, 4))

    plt.subplot(1, 2, 1)
    plt.plot(train_losses, label="Train Loss")
    plt.plot(val_losses, label="Val Loss")
    plt.xlabel("Epoch")
    plt.ylabel("Loss")
    plt.title("Training Curves")
    plt.legend()
    plt.grid(True)

    plt.subplot(1, 2, 2)
    plt.semilogy(train_losses, label="Train Loss")
    plt.semilogy(val_losses, label="Val Loss")
    plt.xlabel("Epoch")
    plt.ylabel("Loss (log)")
    plt.title("Training Curves (Log Scale)")
    plt.legend()
    plt.grid(True)

    plt.tight_layout()
    plt.savefig(save_path, dpi=150)
    plt.close()


def plot_predictions(preds, targets, save_path, num_samples=8):
    """绘制预测结果对比"""
    fig, axes = plt.subplots(2, 4, figsize=(14, 6))
    axes = axes.flatten()

    indices = np.random.choice(len(preds), num_samples, replace=False)

    for i, idx in enumerate(indices):
        ax = axes[i]
        ax.plot(targets[idx].numpy(), "b-", label="GT", linewidth=2)
        ax.plot(preds[idx].numpy(), "r--", label="Pred", linewidth=2)
        ax.set_xlabel("Wavelength Channel")
        ax.set_ylabel("Intensity")
        ax.set_title(f"Sample {idx}")
        ax.legend(fontsize=8)
        ax.grid(True, alpha=0.3)

    plt.tight_layout()
    plt.savefig(save_path, dpi=150)
    plt.close()


def plot_error_distribution(preds, targets, save_path):
    """绘制误差分布"""
    errors = (preds - targets).numpy()

    fig, axes = plt.subplots(1, 3, figsize=(14, 4))

    # 误差直方图
    axes[0].hist(errors.flatten(), bins=50, edgecolor="black", alpha=0.7)
    axes[0].set_xlabel("Error")
    axes[0].set_ylabel("Count")
    axes[0].set_title("Error Distribution")
    axes[0].axvline(x=0, color="r", linestyle="--")

    # 每个波长通道的RMSE
    rmse_per_channel = np.sqrt(np.mean(errors**2, axis=0))
    axes[1].bar(range(31), rmse_per_channel)
    axes[1].set_xlabel("Wavelength Channel")
    axes[1].set_ylabel("RMSE")
    axes[1].set_title("RMSE per Channel")

    # 误差热图
    im = axes[2].imshow(
        errors[:100, :],
        aspect="auto",
        cmap="RdBu_r",
        vmin=-np.percentile(np.abs(errors), 95),
        vmax=np.percentile(np.abs(errors), 95),
    )
    axes[2].set_xlabel("Wavelength Channel")
    axes[2].set_ylabel("Sample")
    axes[2].set_title("Error Heatmap (first 100 samples)")
    plt.colorbar(im, ax=axes[2])

    plt.tight_layout()
    plt.savefig(save_path, dpi=150)
    plt.close()


# ===================== 主训练函数 =====================


def train(args):
    """主训练函数"""
    # 设置设备
    device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
    print(f"Using device: {device}")

    # 创建输出目录
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    output_dir = os.path.join(args.output_dir, f"{args.model}_{timestamp}")
    os.makedirs(output_dir, exist_ok=True)
    print(f"Output directory: {output_dir}")

    # 加载数据
    train_loader, val_loader, test_loader = load_data(args.data_path, args.batch_size)

    # 创建模型
    if args.model == "cnn":
        model = FDMNet_CNN(input_dim=1000, output_dim=31)
    elif args.model == "mlp":
        model = FDMNet_MLP(input_dim=1000, output_dim=31)
    elif args.model == "rescnn":
        model = FDMNet_ResCNN(input_dim=1000, output_dim=31)
    else:
        raise ValueError(f"Unknown model: {args.model}")

    model = model.to(device)
    print(f"\nModel: {args.model}")
    print(f"Parameters: {sum(p.numel() for p in model.parameters()):,}")

    # 损失函数和优化器
    criterion = nn.MSELoss()
    optimizer = optim.Adam(
        model.parameters(), lr=args.lr, weight_decay=args.weight_decay
    )
    scheduler = optim.lr_scheduler.ReduceLROnPlateau(
        optimizer, mode="min", factor=0.5, patience=10, verbose=True
    )

    # 训练循环
    train_losses = []
    val_losses = []
    best_val_loss = float("inf")
    patience_counter = 0

    print(f"\nStarting training for {args.epochs} epochs...")
    print("-" * 60)

    for epoch in range(1, args.epochs + 1):
        # 训练
        train_loss = train_one_epoch(model, train_loader, criterion, optimizer, device)
        train_losses.append(train_loss)

        # 验证
        val_loss, val_metrics, _, _ = evaluate(model, val_loader, criterion, device)
        val_losses.append(val_loss)

        # 学习率调整
        scheduler.step(val_loss)

        # 打印进度
        if epoch % 10 == 0 or epoch == 1:
            print(
                f"Epoch {epoch:3d}/{args.epochs} | "
                f"Train Loss: {train_loss:.6f} | "
                f"Val Loss: {val_loss:.6f} | "
                f"Val RMSE: {val_metrics['rmse']:.6f} | "
                f"Val SAM: {val_metrics['sam']:.2f}°"
            )

        # 保存最佳模型
        if val_loss < best_val_loss:
            best_val_loss = val_loss
            patience_counter = 0
            torch.save(
                {
                    "epoch": epoch,
                    "model_state_dict": model.state_dict(),
                    "optimizer_state_dict": optimizer.state_dict(),
                    "val_loss": val_loss,
                    "val_metrics": val_metrics,
                },
                os.path.join(output_dir, "best_model.pth"),
            )
        else:
            patience_counter += 1

        # 早停
        if patience_counter >= args.patience:
            print(f"\nEarly stopping at epoch {epoch}")
            break

    print("-" * 60)
    print(f"Training completed. Best val loss: {best_val_loss:.6f}")

    # 绘制训练曲线
    plot_training_curves(
        train_losses, val_losses, os.path.join(output_dir, "training_curves.png")
    )

    # 加载最佳模型进行测试
    checkpoint = torch.load(
        os.path.join(output_dir, "best_model.pth"), weights_only=False
    )
    model.load_state_dict(checkpoint["model_state_dict"])

    # 测试集评估
    test_loss, test_metrics, test_preds, test_targets = evaluate(
        model, test_loader, criterion, device
    )

    print(f"\n{'='*60}")
    print("Test Results:")
    print(f"  Loss: {test_loss:.6f}")
    print(f"  RMSE: {test_metrics['rmse']:.6f}")
    print(f"  MAE:  {test_metrics['mae']:.6f}")
    print(f"  MRAE: {test_metrics['mrae']:.4f}")
    print(f"  SAM:  {test_metrics['sam']:.2f}°")
    print(f"{'='*60}")

    # 绘制预测结果
    plot_predictions(
        test_preds, test_targets, os.path.join(output_dir, "predictions.png")
    )

    # 绘制误差分布
    plot_error_distribution(
        test_preds, test_targets, os.path.join(output_dir, "error_distribution.png")
    )

    # 保存测试结果
    results = {
        "test_loss": test_loss,
        "test_metrics": test_metrics,
        "train_losses": train_losses,
        "val_losses": val_losses,
        "args": vars(args),
    }
    torch.save(results, os.path.join(output_dir, "results.pth"))

    print(f"\nResults saved to: {output_dir}")

    return model, results


# ===================== 主函数 =====================

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Train E2E FDM Spectroscopy Network")

    # 数据参数
    parser.add_argument(
        "--data_path",
        type=str,
        default="fdm_dataset.mat",
        help="Path to dataset (.mat or folder with .npy files)",
    )

    # 模型参数
    parser.add_argument(
        "--model",
        type=str,
        default="cnn",
        choices=["cnn", "mlp", "rescnn"],
        help="Model architecture",
    )

    # 训练参数
    parser.add_argument(
        "--epochs", type=int, default=200, help="Number of training epochs"
    )
    parser.add_argument("--batch_size", type=int, default=64, help="Batch size")
    parser.add_argument("--lr", type=float, default=1e-3, help="Learning rate")
    parser.add_argument("--weight_decay", type=float, default=1e-5, help="Weight decay")
    parser.add_argument(
        "--patience", type=int, default=30, help="Early stopping patience"
    )

    # 输出参数
    parser.add_argument(
        "--output_dir", type=str, default="./outputs", help="Output directory"
    )

    args = parser.parse_args()

    train(args)

"""
FDM Spectroscopy Results Visualization
可视化光谱重建效果
"""

import os
import numpy as np
import torch
import matplotlib.pyplot as plt
from scipy.io import loadmat
import h5py

# 设置中文字体
plt.rcParams["font.sans-serif"] = ["SimHei", "Microsoft YaHei", "DejaVu Sans"]
plt.rcParams["axes.unicode_minus"] = False


def load_mat_data(data_path):
    """加载.mat数据"""
    try:
        data = loadmat(data_path)
        X_test = data["X_test"].astype(np.float32)
        Y_test = data["Y_test"].astype(np.float32)
        wav = data.get("wav", None)
        if wav is not None:
            wav = wav.flatten()
    except NotImplementedError:
        with h5py.File(data_path, "r") as f:
            X_test = np.array(f["X_test"]).T.astype(np.float32)
            Y_test = np.array(f["Y_test"]).T.astype(np.float32)
            if "wav" in f:
                wav = np.array(f["wav"]).flatten()
            else:
                wav = None

    if wav is None:
        wav = np.linspace(400, 700, 31)  # 默认波长范围

    return X_test, Y_test, wav


def load_model_and_predict(model_path, X_test, device="cuda"):
    """加载模型并预测"""
    # 直接在这里定义网络，避免导入问题
    import torch.nn as nn

    class FDMNet_CNN(nn.Module):
        """1D CNN 网络"""

        def __init__(self, input_dim=1000, output_dim=31):
            super().__init__()

            self.conv_layers = nn.Sequential(
                nn.Conv1d(1, 32, kernel_size=7, stride=2, padding=3),
                nn.BatchNorm1d(32),
                nn.ReLU(),
                nn.Conv1d(32, 64, kernel_size=5, stride=2, padding=2),
                nn.BatchNorm1d(64),
                nn.ReLU(),
                nn.Conv1d(64, 128, kernel_size=5, stride=2, padding=2),
                nn.BatchNorm1d(128),
                nn.ReLU(),
                nn.Conv1d(128, 256, kernel_size=5, stride=2, padding=2),
                nn.BatchNorm1d(256),
                nn.ReLU(),
                nn.Conv1d(256, 256, kernel_size=4, stride=2, padding=1),
                nn.BatchNorm1d(256),
                nn.ReLU(),
            )

            self.fc_layers = nn.Sequential(
                nn.Flatten(),
                nn.Linear(256 * 31, 512),
                nn.ReLU(),
                nn.Dropout(0.3),
                nn.Linear(512, 128),
                nn.ReLU(),
                nn.Linear(128, output_dim),
            )

        def forward(self, x):
            x = x.unsqueeze(1)
            x = self.conv_layers(x)
            x = self.fc_layers(x)
            return x

    model = FDMNet_CNN(input_dim=1000, output_dim=31)
    checkpoint = torch.load(model_path, weights_only=False)
    model.load_state_dict(checkpoint["model_state_dict"])
    model = model.to(device)
    model.eval()

    with torch.no_grad():
        X_tensor = torch.from_numpy(X_test).to(device)
        predictions = model(X_tensor).cpu().numpy()

    return predictions


def visualize_results(predictions, Y_test, wav, save_dir="./visualization"):
    """生成可视化结果"""
    os.makedirs(save_dir, exist_ok=True)

    # ==================== 图1: 多样本对比 ====================
    fig, axes = plt.subplots(3, 4, figsize=(16, 10))
    axes = axes.flatten()

    # 随机选12个样本
    np.random.seed(42)
    indices = np.random.choice(len(Y_test), 12, replace=False)

    for i, idx in enumerate(indices):
        ax = axes[i]
        ax.plot(wav, Y_test[idx], "b-", linewidth=2, label="Ground Truth")
        ax.plot(wav, predictions[idx], "r--", linewidth=2, label="Prediction")
        ax.fill_between(wav, Y_test[idx], predictions[idx], alpha=0.3, color="gray")
        ax.set_xlabel("Wavelength (nm)")
        ax.set_ylabel("Intensity")
        ax.set_title(f"Sample #{idx}")
        ax.legend(fontsize=8)
        ax.grid(True, alpha=0.3)

    plt.tight_layout()
    plt.savefig(os.path.join(save_dir, "01_multi_samples.png"), dpi=200)
    plt.close()
    print(f"Saved: 01_multi_samples.png")

    # ==================== 图2: 最好/最差/中等样本 ====================
    # 计算每个样本的RMSE
    rmse_per_sample = np.sqrt(np.mean((predictions - Y_test) ** 2, axis=1))

    best_idx = np.argmin(rmse_per_sample)
    worst_idx = np.argmax(rmse_per_sample)
    median_idx = np.argsort(rmse_per_sample)[len(rmse_per_sample) // 2]

    fig, axes = plt.subplots(1, 3, figsize=(15, 4))

    for ax, idx, title in zip(
        axes, [best_idx, median_idx, worst_idx], ["Best", "Median", "Worst"]
    ):
        ax.plot(wav, Y_test[idx], "b-", linewidth=2.5, label="Ground Truth")
        ax.plot(wav, predictions[idx], "r--", linewidth=2.5, label="Prediction")
        ax.fill_between(wav, Y_test[idx], predictions[idx], alpha=0.3, color="gray")
        ax.set_xlabel("Wavelength (nm)", fontsize=12)
        ax.set_ylabel("Intensity", fontsize=12)
        ax.set_title(f"{title} Case (RMSE={rmse_per_sample[idx]:.4f})", fontsize=14)
        ax.legend(fontsize=10)
        ax.grid(True, alpha=0.3)

    plt.tight_layout()
    plt.savefig(os.path.join(save_dir, "02_best_median_worst.png"), dpi=200)
    plt.close()
    print(f"Saved: 02_best_median_worst.png")

    # ==================== 图3: 误差统计 ====================
    fig, axes = plt.subplots(2, 2, figsize=(12, 10))

    # 3a: RMSE分布直方图
    ax = axes[0, 0]
    ax.hist(rmse_per_sample, bins=50, edgecolor="black", alpha=0.7, color="steelblue")
    ax.axvline(
        np.mean(rmse_per_sample),
        color="r",
        linestyle="--",
        label=f"Mean={np.mean(rmse_per_sample):.4f}",
    )
    ax.axvline(
        np.median(rmse_per_sample),
        color="g",
        linestyle="--",
        label=f"Median={np.median(rmse_per_sample):.4f}",
    )
    ax.set_xlabel("RMSE per Sample")
    ax.set_ylabel("Count")
    ax.set_title("RMSE Distribution")
    ax.legend()
    ax.grid(True, alpha=0.3)

    # 3b: 每个波长通道的RMSE
    ax = axes[0, 1]
    rmse_per_channel = np.sqrt(np.mean((predictions - Y_test) ** 2, axis=0))
    ax.bar(wav, rmse_per_channel, width=8, color="coral", edgecolor="black")
    ax.set_xlabel("Wavelength (nm)")
    ax.set_ylabel("RMSE")
    ax.set_title("RMSE per Wavelength Channel")
    ax.grid(True, alpha=0.3, axis="y")

    # 3c: 预测值 vs 真值散点图
    ax = axes[1, 0]
    ax.scatter(Y_test.flatten(), predictions.flatten(), alpha=0.1, s=1)
    ax.plot([0, 1], [0, 1], "r--", linewidth=2, label="Ideal")
    ax.set_xlabel("Ground Truth")
    ax.set_ylabel("Prediction")
    ax.set_title("Prediction vs Ground Truth")
    ax.set_xlim([0, max(Y_test.max(), predictions.max())])
    ax.set_ylim([0, max(Y_test.max(), predictions.max())])
    ax.legend()
    ax.grid(True, alpha=0.3)
    ax.set_aspect("equal")

    # 3d: 误差热图
    ax = axes[1, 1]
    errors = predictions - Y_test
    # 按RMSE排序显示
    sorted_indices = np.argsort(rmse_per_sample)
    errors_sorted = errors[sorted_indices[:200], :]  # 取前200个样本

    im = ax.imshow(
        errors_sorted,
        aspect="auto",
        cmap="RdBu_r",
        extent=[wav[0], wav[-1], 200, 0],
        vmin=-np.percentile(np.abs(errors), 95),
        vmax=np.percentile(np.abs(errors), 95),
    )
    ax.set_xlabel("Wavelength (nm)")
    ax.set_ylabel("Sample (sorted by RMSE)")
    ax.set_title("Error Heatmap")
    plt.colorbar(im, ax=ax, label="Error")

    plt.tight_layout()
    plt.savefig(os.path.join(save_dir, "03_error_statistics.png"), dpi=200)
    plt.close()
    print(f"Saved: 03_error_statistics.png")

    # ==================== 图4: 光谱角(SAM)分析 ====================
    # 计算每个样本的SAM
    dot_product = np.sum(predictions * Y_test, axis=1)
    norm_pred = np.linalg.norm(predictions, axis=1)
    norm_target = np.linalg.norm(Y_test, axis=1)
    cos_sim = dot_product / (norm_pred * norm_target + 1e-6)
    cos_sim = np.clip(cos_sim, -1, 1)
    sam_per_sample = np.arccos(cos_sim) * 180 / np.pi

    fig, axes = plt.subplots(1, 2, figsize=(12, 4))

    # SAM分布
    ax = axes[0]
    ax.hist(sam_per_sample, bins=50, edgecolor="black", alpha=0.7, color="mediumpurple")
    ax.axvline(
        np.mean(sam_per_sample),
        color="r",
        linestyle="--",
        label=f"Mean={np.mean(sam_per_sample):.2f}°",
    )
    ax.set_xlabel("Spectral Angle (degrees)")
    ax.set_ylabel("Count")
    ax.set_title("Spectral Angle Mapper (SAM) Distribution")
    ax.legend()
    ax.grid(True, alpha=0.3)

    # RMSE vs SAM
    ax = axes[1]
    ax.scatter(rmse_per_sample, sam_per_sample, alpha=0.3, s=10)
    ax.set_xlabel("RMSE")
    ax.set_ylabel("SAM (degrees)")
    ax.set_title("RMSE vs SAM")
    ax.grid(True, alpha=0.3)

    plt.tight_layout()
    plt.savefig(os.path.join(save_dir, "04_sam_analysis.png"), dpi=200)
    plt.close()
    print(f"Saved: 04_sam_analysis.png")

    # ==================== 图5: 大图展示 (适合论文) ====================
    fig = plt.figure(figsize=(14, 8))

    # 选6个有代表性的样本
    percentiles = [0, 20, 40, 60, 80, 99]
    selected_indices = [
        np.argsort(rmse_per_sample)[int(len(rmse_per_sample) * p / 100)]
        for p in percentiles
    ]

    for i, idx in enumerate(selected_indices):
        ax = fig.add_subplot(2, 3, i + 1)
        ax.plot(wav, Y_test[idx], "b-", linewidth=2, label="Ground Truth")
        ax.plot(wav, predictions[idx], "r--", linewidth=2, label="Reconstruction")
        ax.fill_between(wav, Y_test[idx], predictions[idx], alpha=0.2, color="gray")
        ax.set_xlabel("Wavelength (nm)", fontsize=11)
        ax.set_ylabel("Reflectance", fontsize=11)
        ax.set_title(
            f"RMSE={rmse_per_sample[idx]:.4f}, SAM={sam_per_sample[idx]:.2f}°",
            fontsize=11,
        )
        if i == 0:
            ax.legend(fontsize=9)
        ax.grid(True, alpha=0.3)
        ax.set_xlim([wav[0], wav[-1]])

    plt.tight_layout()
    plt.savefig(os.path.join(save_dir, "05_paper_figure.png"), dpi=300)
    plt.close()
    print(f"Saved: 05_paper_figure.png")

    # ==================== 打印统计信息 ====================
    print("\n" + "=" * 50)
    print("Reconstruction Statistics:")
    print("=" * 50)
    print(
        f"RMSE:  Mean={np.mean(rmse_per_sample):.4f}, "
        f"Std={np.std(rmse_per_sample):.4f}, "
        f"Min={np.min(rmse_per_sample):.4f}, "
        f"Max={np.max(rmse_per_sample):.4f}"
    )
    print(
        f"SAM:   Mean={np.mean(sam_per_sample):.2f}°, "
        f"Std={np.std(sam_per_sample):.2f}°, "
        f"Min={np.min(sam_per_sample):.2f}°, "
        f"Max={np.max(sam_per_sample):.2f}°"
    )
    print(
        f"MRAE:  {np.mean(np.abs(predictions - Y_test) / (np.abs(Y_test) + 1e-6)):.4f}"
    )
    print("=" * 50)

    return rmse_per_sample, sam_per_sample


if __name__ == "__main__":
    import argparse

    parser = argparse.ArgumentParser()
    parser.add_argument("--data_path", type=str, default="fdm_dataset.mat")
    parser.add_argument(
        "--model_path", type=str, default="./outputs/cnn_20251210_183425/best_model.pth"
    )
    parser.add_argument("--save_dir", type=str, default="./visualization")
    args = parser.parse_args()

    # 加载数据
    print("Loading test data...")
    X_test, Y_test, wav = load_mat_data(args.data_path)
    print(f"  X_test: {X_test.shape}, Y_test: {Y_test.shape}")
    print(f"  Wavelength range: {wav[0]:.0f} - {wav[-1]:.0f} nm")

    # 加载模型并预测
    print("\nLoading model and predicting...")
    device = "cuda" if torch.cuda.is_available() else "cpu"
    predictions = load_model_and_predict(args.model_path, X_test, device)
    print(f"  Predictions: {predictions.shape}")

    # 可视化
    print("\nGenerating visualizations...")
    visualize_results(predictions, Y_test, wav, args.save_dir)

    print(f"\nAll figures saved to: {args.save_dir}")

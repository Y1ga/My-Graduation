"""
FDM Spectroscopy Results Visualization
可视化光谱重建效果 - 直接运行版本

直接修改下方 CONFIG 区域的参数，然后运行即可
"""

import os
import numpy as np
import torch
import torch.nn as nn
import matplotlib.pyplot as plt
import h5py
from scipy.io import loadmat
from tqdm import tqdm


# ============================================================
#                    CONFIG - 修改这里的参数
# ============================================================

CONFIG = {
    # 模型路径 - 改成你训练好的模型路径
    "model_path": "./outputs/cnn_20251210_183425/best_model.pth",
    # KAIST 2D数据路径
    "kaist_2d_path": "W:/dataset/benchmark/merged_data/KAIST_2D.mat",
    # FDM数据集路径 (包含A矩阵和调制矩阵)
    "fdm_data_path": "fdm_cave100k_kaist50k.mat",
    # 选择KAIST的哪个场景 (0-29)
    "scene_idx": 0,
    # 输出目录
    "output_dir": "./visualization",
    # 设备
    "device": "cuda",  # 'cuda' 或 'cpu'
}

# ============================================================


# ===================== 网络定义 =====================


class FDMNet_CNN(nn.Module):
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


# ===================== 工具函数 =====================


def load_h5mat(path, key):
    """加载v7.3 mat文件"""
    with h5py.File(path, "r") as f:
        return np.array(f[key]).T


def spectrum_to_rgb(spectrum, wavelengths=None):
    """光谱转RGB"""
    if wavelengths is None:
        wavelengths = np.linspace(400, 700, spectrum.shape[-1])

    wav = wavelengths

    # CIE XYZ近似
    x_bar = 1.056 * np.exp(-0.5 * ((wav - 599.8) / 37.9) ** 2) + 0.362 * np.exp(
        -0.5 * ((wav - 442.0) / 16.0) ** 2
    )
    y_bar = 0.821 * np.exp(-0.5 * ((wav - 568.8) / 46.9) ** 2) + 0.286 * np.exp(
        -0.5 * ((wav - 530.9) / 16.3) ** 2
    )
    z_bar = 1.217 * np.exp(-0.5 * ((wav - 437.0) / 11.8) ** 2) + 0.681 * np.exp(
        -0.5 * ((wav - 459.0) / 26.0) ** 2
    )

    x_bar, y_bar, z_bar = (
        np.maximum(x_bar, 0),
        np.maximum(y_bar, 0),
        np.maximum(z_bar, 0),
    )

    X = np.tensordot(spectrum, x_bar, axes=(-1, 0))
    Y = np.tensordot(spectrum, y_bar, axes=(-1, 0))
    Z = np.tensordot(spectrum, z_bar, axes=(-1, 0))

    R = 3.2404542 * X - 1.5371385 * Y - 0.4985314 * Z
    G = -0.9692660 * X + 1.8760108 * Y + 0.0415560 * Z
    B = 0.0556434 * X - 0.2040259 * Y + 1.0572252 * Z

    RGB = np.stack([R, G, B], axis=-1)
    RGB = np.clip(RGB, 0, None)
    RGB = RGB / (np.percentile(RGB, 99) + 1e-6)
    RGB = np.clip(RGB, 0, 1)

    return RGB


def compute_metrics_per_pixel(pred, target):
    """计算每个像素的指标"""
    rmse = np.sqrt(np.mean((pred - target) ** 2, axis=-1))

    dot = np.sum(pred * target, axis=-1)
    norm_p = np.linalg.norm(pred, axis=-1)
    norm_t = np.linalg.norm(target, axis=-1)
    cos_sim = dot / (norm_p * norm_t + 1e-8)
    cos_sim = np.clip(cos_sim, -1, 1)
    sam = np.arccos(cos_sim) * 180 / np.pi

    return rmse, sam


# ===================== 可视化类 =====================


class FDMVisualizer:
    def __init__(self, model_path, device="cuda"):
        self.device = device
        self.model = self._load_model(model_path)
        self.wavelengths = np.linspace(400, 700, 31)

    def _load_model(self, model_path):
        model = FDMNet_CNN(input_dim=1000, output_dim=31)
        checkpoint = torch.load(
            model_path, weights_only=False, map_location=self.device
        )
        model.load_state_dict(checkpoint["model_state_dict"])
        model = model.to(self.device)
        model.eval()
        print(f"Model loaded from: {model_path}")
        return model

    def predict(self, X):
        self.model.eval()
        with torch.no_grad():
            X_tensor = torch.from_numpy(X.astype(np.float32)).to(self.device)
            pred = self.model(X_tensor).cpu().numpy()
        return pred

    def predict_batched(self, X, batch_size=1024):
        n_samples = len(X)
        predictions = []

        for i in tqdm(range(0, n_samples, batch_size), desc="Predicting"):
            batch = X[i : i + batch_size]
            pred = self.predict(batch)
            predictions.append(pred)

        return np.concatenate(predictions, axis=0)

    def reconstruct_2d_image(
        self, kaist_2d_path, A_matrix, modulation_matrix, scene_idx=0, max_signal=1.0
    ):
        """从KAIST 2D数据重建图像"""
        print(f"\n{'='*60}")
        print(f"Reconstructing KAIST scene {scene_idx}")
        print("=" * 60)

        # 加载KAIST 2D数据
        print("Loading KAIST 2D data...")
        if kaist_2d_path.endswith(".npy"):
            kaist_2d = np.load(kaist_2d_path)
        else:
            try:
                data = loadmat(kaist_2d_path)
                for key in data:
                    if not key.startswith("_") and isinstance(data[key], np.ndarray):
                        if data[key].ndim == 4:
                            kaist_2d = data[key]
                            break
            except NotImplementedError:
                with h5py.File(kaist_2d_path, "r") as f:
                    # 找到正确的key
                    for key in f.keys():
                        if f[key].ndim == 4 or (
                            hasattr(f[key], "shape") and len(f[key].shape) == 4
                        ):
                            kaist_2d = np.array(f[key]).T
                            break

        print(f"  KAIST 2D shape: {kaist_2d.shape}")

        # 选择场景
        scene = kaist_2d[scene_idx]
        H, W, C = scene.shape
        print(f"  Scene {scene_idx} shape: {scene.shape}")

        # 展平
        gt_spectra = scene.reshape(-1, C)
        print(f"  Flattened: {gt_spectra.shape}")

        # 生成时域信号
        print("Generating time-domain signals...")
        I_led = (A_matrix.T @ gt_spectra.T).T
        time_signals = (I_led @ modulation_matrix).astype(np.float32)
        time_signals = time_signals / max_signal
        print(f"  Time signals: {time_signals.shape}")

        # 预测
        print("Running model prediction...")
        pred_spectra = self.predict_batched(time_signals, batch_size=2048)
        print(f"  Predictions: {pred_spectra.shape}")

        # 重塑
        gt_image = gt_spectra.reshape(H, W, C)
        pred_image = pred_spectra.reshape(H, W, C)

        return gt_image, pred_image

    # ==================== 可视化函数 ====================

    def plot_spectral_curves(self, gt, pred, save_path, num_samples=12):
        """光谱曲线对比"""
        fig, axes = plt.subplots(3, 4, figsize=(16, 10))
        axes = axes.flatten()

        gt_flat = gt.reshape(-1, 31)
        pred_flat = pred.reshape(-1, 31)

        rmse_all = np.sqrt(np.mean((pred_flat - gt_flat) ** 2, axis=1))

        percentiles = [0, 10, 20, 30, 40, 50, 60, 70, 80, 90, 95, 99]
        indices = [
            np.argsort(rmse_all)[int(len(rmse_all) * p / 100)] for p in percentiles
        ]

        for i, idx in enumerate(indices):
            ax = axes[i]
            ax.plot(
                self.wavelengths, gt_flat[idx], "b-", linewidth=2, label="Ground Truth"
            )
            ax.plot(
                self.wavelengths, pred_flat[idx], "r--", linewidth=2, label="Prediction"
            )
            ax.fill_between(
                self.wavelengths, gt_flat[idx], pred_flat[idx], alpha=0.3, color="gray"
            )
            ax.set_xlabel("Wavelength (nm)")
            ax.set_ylabel("Reflectance")
            ax.set_title(f"RMSE={rmse_all[idx]:.4f} ({percentiles[i]}%)")
            if i == 0:
                ax.legend()
            ax.grid(True, alpha=0.3)
            ax.set_xlim([400, 700])

        plt.tight_layout()
        plt.savefig(save_path, dpi=200, bbox_inches="tight")
        plt.close()
        print(f"Saved: {save_path}")

    def plot_2d_reconstruction(self, gt_image, pred_image, save_path):
        """2D图像重建对比"""
        fig = plt.figure(figsize=(18, 12))

        # RGB
        gt_rgb = spectrum_to_rgb(gt_image, self.wavelengths)
        pred_rgb = spectrum_to_rgb(pred_image, self.wavelengths)

        ax1 = fig.add_subplot(2, 3, 1)
        ax1.imshow(gt_rgb)
        ax1.set_title("Ground Truth RGB", fontsize=14)
        ax1.axis("off")

        ax2 = fig.add_subplot(2, 3, 2)
        ax2.imshow(pred_rgb)
        ax2.set_title("Reconstructed RGB", fontsize=14)
        ax2.axis("off")

        ax3 = fig.add_subplot(2, 3, 3)
        rgb_diff = np.mean(np.abs(gt_rgb - pred_rgb), axis=-1)
        im = ax3.imshow(rgb_diff, cmap="hot")
        ax3.set_title("RGB Difference", fontsize=14)
        ax3.axis("off")
        plt.colorbar(im, ax=ax3, fraction=0.046)

        # RMSE and SAM maps
        rmse_map, sam_map = compute_metrics_per_pixel(pred_image, gt_image)

        ax4 = fig.add_subplot(2, 3, 4)
        im = ax4.imshow(rmse_map, cmap="hot")
        ax4.set_title(f"RMSE Map (mean={rmse_map.mean():.4f})", fontsize=14)
        ax4.axis("off")
        plt.colorbar(im, ax=ax4, fraction=0.046)

        ax5 = fig.add_subplot(2, 3, 5)
        im = ax5.imshow(sam_map, cmap="jet", vmin=0, vmax=np.percentile(sam_map, 95))
        ax5.set_title(f"SAM Map (mean={sam_map.mean():.2f}°)", fontsize=14)
        ax5.axis("off")
        plt.colorbar(im, ax=ax5, fraction=0.046)

        ax6 = fig.add_subplot(2, 3, 6)
        ax6.hist(rmse_map.flatten(), bins=100, color="steelblue", alpha=0.7)
        ax6.axvline(
            rmse_map.mean(),
            color="r",
            linestyle="--",
            label=f"Mean={rmse_map.mean():.4f}",
        )
        ax6.set_xlabel("RMSE")
        ax6.set_ylabel("Count")
        ax6.set_title("RMSE Distribution")
        ax6.legend()

        plt.tight_layout()
        plt.savefig(save_path, dpi=200, bbox_inches="tight")
        plt.close()
        print(f"Saved: {save_path}")

    def plot_band_comparison(
        self, gt_image, pred_image, save_path, bands=[5, 10, 15, 20, 25]
    ):
        """选定波段对比"""
        n_bands = len(bands)
        fig, axes = plt.subplots(3, n_bands, figsize=(4 * n_bands, 10))

        for i, band in enumerate(bands):
            wav = self.wavelengths[band]

            # GT
            axes[0, i].imshow(gt_image[:, :, band], cmap="gray")
            axes[0, i].set_title(f"GT @ {wav:.0f}nm")
            axes[0, i].axis("off")

            # Pred
            axes[1, i].imshow(pred_image[:, :, band], cmap="gray")
            axes[1, i].set_title(f"Pred @ {wav:.0f}nm")
            axes[1, i].axis("off")

            # Diff
            diff = np.abs(gt_image[:, :, band] - pred_image[:, :, band])
            im = axes[2, i].imshow(diff, cmap="hot")
            axes[2, i].set_title(f"Diff @ {wav:.0f}nm")
            axes[2, i].axis("off")

        axes[0, 0].set_ylabel("Ground Truth", fontsize=12)
        axes[1, 0].set_ylabel("Prediction", fontsize=12)
        axes[2, 0].set_ylabel("Difference", fontsize=12)

        plt.tight_layout()
        plt.savefig(save_path, dpi=200, bbox_inches="tight")
        plt.close()
        print(f"Saved: {save_path}")

    def plot_pixel_spectra(self, gt_image, pred_image, save_path):
        """图像上选点显示光谱"""
        H, W, C = gt_image.shape

        pixel_coords = [
            (H // 4, W // 4),
            (H // 4, 3 * W // 4),
            (H // 2, W // 2),
            (3 * H // 4, W // 4),
            (3 * H // 4, 3 * W // 4),
        ]

        fig = plt.figure(figsize=(16, 10))

        # RGB图
        ax_img = fig.add_subplot(2, 3, (1, 4))
        rgb = spectrum_to_rgb(gt_image, self.wavelengths)
        ax_img.imshow(rgb)

        colors = plt.cm.tab10(np.linspace(0, 1, len(pixel_coords)))
        for i, (y, x) in enumerate(pixel_coords):
            ax_img.scatter(
                x, y, c=[colors[i]], s=150, marker="o", edgecolors="white", linewidths=2
            )
            ax_img.text(
                x + 10,
                y,
                f"P{i+1}",
                color="white",
                fontsize=12,
                fontweight="bold",
                bbox=dict(boxstyle="round", facecolor=colors[i], alpha=0.8),
            )

        ax_img.set_title("Selected Pixels on GT Image", fontsize=14)
        ax_img.axis("off")

        # 每个点的光谱
        subplot_positions = [2, 3, 5, 6]
        for i, (y, x) in enumerate(pixel_coords[:4]):
            ax = fig.add_subplot(2, 3, subplot_positions[i])

            gt_spec = gt_image[y, x, :]
            pred_spec = pred_image[y, x, :]
            rmse = np.sqrt(np.mean((pred_spec - gt_spec) ** 2))

            ax.plot(self.wavelengths, gt_spec, "b-", linewidth=2, label="GT")
            ax.plot(self.wavelengths, pred_spec, "r--", linewidth=2, label="Pred")
            ax.fill_between(
                self.wavelengths, gt_spec, pred_spec, alpha=0.3, color="gray"
            )
            ax.set_xlabel("Wavelength (nm)")
            ax.set_ylabel("Reflectance")
            ax.set_title(
                f"P{i+1} ({y},{x}) RMSE={rmse:.4f}", color=colors[i], fontsize=12
            )
            ax.legend(fontsize=9)
            ax.grid(True, alpha=0.3)
            ax.set_xlim([400, 700])

        plt.tight_layout()
        plt.savefig(save_path, dpi=200, bbox_inches="tight")
        plt.close()
        print(f"Saved: {save_path}")

    def compute_statistics(self, gt_image, pred_image):
        """计算并打印统计信息"""
        gt_flat = gt_image.reshape(-1, 31)
        pred_flat = pred_image.reshape(-1, 31)

        mse = np.mean((pred_flat - gt_flat) ** 2)
        rmse = np.sqrt(mse)
        mae = np.mean(np.abs(pred_flat - gt_flat))
        mrae = np.mean(np.abs(pred_flat - gt_flat) / (np.abs(gt_flat) + 1e-6))

        dot = np.sum(pred_flat * gt_flat, axis=1)
        norm_p = np.linalg.norm(pred_flat, axis=1)
        norm_t = np.linalg.norm(gt_flat, axis=1)
        cos_sim = dot / (norm_p * norm_t + 1e-8)
        cos_sim = np.clip(cos_sim, -1, 1)
        sam = np.mean(np.arccos(cos_sim)) * 180 / np.pi

        max_val = max(gt_flat.max(), 1.0)
        psnr = 10 * np.log10(max_val**2 / mse)

        print("\n" + "=" * 50)
        print("Reconstruction Statistics")
        print("=" * 50)
        print(f"  Image shape: {gt_image.shape}")
        print(f"  RMSE: {rmse:.6f}")
        print(f"  MAE:  {mae:.6f}")
        print(f"  MRAE: {mrae:.4f}")
        print(f"  SAM:  {sam:.2f}°")
        print(f"  PSNR: {psnr:.2f} dB")
        print("=" * 50)

        return {"rmse": rmse, "mae": mae, "mrae": mrae, "sam": sam, "psnr": psnr}

    def generate_report(self, gt_image, pred_image, output_dir):
        """生成完整报告"""
        os.makedirs(output_dir, exist_ok=True)
        print(f"\nGenerating report to: {output_dir}")

        self.plot_spectral_curves(
            gt_image, pred_image, os.path.join(output_dir, "01_spectral_curves.png")
        )

        self.plot_2d_reconstruction(
            gt_image, pred_image, os.path.join(output_dir, "02_2d_reconstruction.png")
        )

        self.plot_band_comparison(
            gt_image, pred_image, os.path.join(output_dir, "03_band_comparison.png")
        )

        self.plot_pixel_spectra(
            gt_image, pred_image, os.path.join(output_dir, "04_pixel_spectra.png")
        )

        stats = self.compute_statistics(gt_image, pred_image)

        # 保存数据
        np.savez(
            os.path.join(output_dir, "reconstruction.npz"), gt=gt_image, pred=pred_image
        )

        print(f"\nAll results saved to: {output_dir}")
        return stats


# ===================== 主函数 =====================


def main():
    print("=" * 60)
    print("FDM Spectroscopy Visualization")
    print("=" * 60)

    # 读取配置
    model_path = CONFIG["model_path"]
    kaist_2d_path = CONFIG["kaist_2d_path"]
    fdm_data_path = CONFIG["fdm_data_path"]
    scene_idx = CONFIG["scene_idx"]
    output_dir = CONFIG["output_dir"]
    device = CONFIG["device"]

    print(f"\nConfiguration:")
    print(f"  Model: {model_path}")
    print(f"  KAIST 2D: {kaist_2d_path}")
    print(f"  FDM data: {fdm_data_path}")
    print(f"  Scene: {scene_idx}")
    print(f"  Output: {output_dir}")
    print(f"  Device: {device}")

    # 检查文件
    if not os.path.exists(model_path):
        print(f"\n[ERROR] Model not found: {model_path}")
        print("Please update CONFIG['model_path']")
        return

    if not os.path.exists(fdm_data_path):
        print(f"\n[ERROR] FDM data not found: {fdm_data_path}")
        print("Please update CONFIG['fdm_data_path']")
        return

    if not os.path.exists(kaist_2d_path):
        print(f"\n[ERROR] KAIST 2D not found: {kaist_2d_path}")
        print("Please update CONFIG['kaist_2d_path']")
        return

    # 加载FDM参数
    print("\nLoading FDM parameters...")
    try:
        fdm_data = loadmat(fdm_data_path)
        A = fdm_data["A"]
        modulation_matrix = fdm_data["modulation_matrix"]
        max_signal = fdm_data["max_signal"].item()
    except NotImplementedError:
        with h5py.File(fdm_data_path, "r") as f:
            A = np.array(f["A"]).T
            modulation_matrix = np.array(f["modulation_matrix"]).T
            max_signal = np.array(f["max_signal"]).item()

    print(f"  A matrix: {A.shape}")
    print(f"  Modulation: {modulation_matrix.shape}")
    print(f"  Max signal: {max_signal:.6f}")

    # 创建可视化器
    visualizer = FDMVisualizer(model_path, device=device)

    # 重建图像
    gt_image, pred_image = visualizer.reconstruct_2d_image(
        kaist_2d_path, A, modulation_matrix, scene_idx=scene_idx, max_signal=max_signal
    )

    # 生成报告
    output_subdir = os.path.join(output_dir, f"scene_{scene_idx}")
    visualizer.generate_report(gt_image, pred_image, output_subdir)

    print("\n" + "=" * 60)
    print("Done!")
    print("=" * 60)


if __name__ == "__main__":
    main()

"""
FDM 端到端模型测试与可视化
支持多种测试模式: test_dataset, kaist_2d, colorchecker, custom
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
    # 模型路径
    "model_path": "./checkpoints/best_model.pth",
    
    # FDM 数据集路径 (包含 config 信息)
    "fdm_data_path": r"W:\Github\My-Repository\My-Graduation\paper-02\generate_dataset\fdm_e2e_cave100k_kaist50k_noise5pct_aug.mat",
    
    # ============ 测试模式 ============
    # 可选: "test_dataset", "kaist_2d", "colorchecker", "custom"
    "test_mode": "colorchecker",
    
    # --- test_dataset 模式参数 ---
    # 使用 fdm_data_path 中的 test 集
    
    # --- kaist_2d 模式参数 ---
    "kaist_2d_path": r"W:\dataset\benchmark\merged_data\KAIST_2D.mat",
    "scene_idx": 0,  # 场景索引 (0-29)
    
    # --- colorchecker 模式参数 ---
    "colorchecker_path": r"W:\Github\My-Repository\My-Graduation\paper-02\generate_dataset\colorchecker.mat",
    
    # --- custom 模式参数 ---
    "custom_spectra_path": "",  # 自定义光谱文件路径 (.mat 或 .npy)
    "custom_spectra_key": "spectra",  # mat 文件中的变量名
    
    # ============ 其他参数 ============
    "output_dir": "./visualization",
    "device": "cuda" if torch.cuda.is_available() else "cpu",
    "add_noise": True,  # 是否添加噪声 (与训练一致)
    "noise_level": 0.05,  # 5% 平均相对误差
}

# ============================================================


# ===================== 工具函数 =====================
def load_mat_auto(path, key=None):
    """自动检测 mat 文件格式并加载"""
    try:
        # 尝试 scipy (v7 及以下)
        data = loadmat(path)
        if key and key in data:
            return data[key]
        # 自动找最大的数组
        for k in data:
            if not k.startswith('_') and isinstance(data[k], np.ndarray):
                if data[k].size > 100:
                    return data[k]
        return data
    except NotImplementedError:
        # v7.3 格式用 h5py
        with h5py.File(path, 'r') as f:
            if key and key in f:
                return np.array(f[key]).T
            for k in f.keys():
                if not k.startswith('_'):
                    arr = np.array(f[k])
                    if arr.size > 100:
                        return arr.T if arr.ndim > 1 else arr
        return None


def spectrum_to_rgb(spectrum, wavelengths=None):
    """光谱转RGB"""
    if wavelengths is None:
        wavelengths = np.linspace(400, 700, spectrum.shape[-1])
    
    wav = wavelengths
    
    x_bar = 1.056 * np.exp(-0.5 * ((wav - 599.8) / 37.9) ** 2) + \
            0.362 * np.exp(-0.5 * ((wav - 442.0) / 16.0) ** 2)
    y_bar = 0.821 * np.exp(-0.5 * ((wav - 568.8) / 46.9) ** 2) + \
            0.286 * np.exp(-0.5 * ((wav - 530.9) / 16.3) ** 2)
    z_bar = 1.217 * np.exp(-0.5 * ((wav - 437.0) / 11.8) ** 2) + \
            0.681 * np.exp(-0.5 * ((wav - 459.0) / 26.0) ** 2)
    
    x_bar, y_bar, z_bar = np.maximum(x_bar, 0), np.maximum(y_bar, 0), np.maximum(z_bar, 0)
    
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


def compute_rmse(pred, target):
    mse = np.mean((pred - target) ** 2, axis=-1)
    return np.sqrt(mse)


def compute_psnr(pred, target, max_val=1.0):
    mse = np.mean((pred - target) ** 2, axis=-1)
    psnr = 10 * np.log10(max_val ** 2 / (mse + 1e-10))
    return psnr


# ===================== 网络定义 =====================
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


# ===================== FDM 信号生成器 =====================
class FDMSignalGenerator:
    """FDM 时域信号生成器"""
    
    def __init__(self, fdm_data_path):
        print("加载 FDM 参数...")
        with h5py.File(fdm_data_path, 'r') as f:
            config = f['config']
            self.A0 = np.array(config['A0']).T  # [N_led, 31]
            self.modulation_matrix = np.array(config['modulation_matrix_ds']).T  # [N_led, N_points]
            self.X_max = np.array(config['X_max']).item()
            self.max_spectrum = np.array(config['max_spectrum']).item()
            self.noise_sigma = np.array(config['noise_sigma']).item()
        
        print(f"  A0: {self.A0.shape}")
        print(f"  调制矩阵: {self.modulation_matrix.shape}")
        print(f"  X_max: {self.X_max:.6f}")
        print(f"  max_spectrum: {self.max_spectrum:.6f}")
        print(f"  noise_sigma: {self.noise_sigma:.4f}")
    
    def generate_signal(self, spectra, add_noise=True):
        """
        从光谱生成时域信号
        
        Args:
            spectra: [N, 31] 光谱数据
            add_noise: 是否添加噪声
        
        Returns:
            time_signals: [N, N_points] 归一化后的时域信号
        """
        # 归一化光谱
        if self.max_spectrum > 1.5:
            spectra = spectra / self.max_spectrum
        
        # 计算 LED 响应
        I_led = (self.A0 @ spectra.T).T  # [N, N_led]
        
        # 添加噪声
        if add_noise:
            noise = self.noise_sigma * np.random.randn(*I_led.shape)
            I_led = I_led * (1 + noise)
            I_led = np.maximum(I_led, 0)
        
        # 生成时域信号
        time_signals = (I_led @ self.modulation_matrix).astype(np.float32)
        
        # 归一化
        time_signals = time_signals / self.X_max
        
        return time_signals, spectra


# ===================== 测试器类 =====================
class FDMTester:
    def __init__(self, model_path, fdm_data_path, device="cuda"):
        self.device = device
        self.wavelengths = np.linspace(400, 700, 31)
        
        # 加载模型
        self.model, self.model_config = self._load_model(model_path)
        
        # 加载 FDM 参数
        self.signal_generator = FDMSignalGenerator(fdm_data_path)
    
    def _load_model(self, model_path):
        checkpoint = torch.load(model_path, map_location=self.device, weights_only=False)
        
        config = checkpoint.get('config', {})
        dropout = config.get('dropout', 0.5)
        
        model = FDMNet(input_size=1000, output_size=31, dropout=dropout)
        model.load_state_dict(checkpoint['model_state_dict'])
        model = model.to(self.device)
        model.eval()
        
        print(f"\n模型加载成功: {model_path}")
        print(f"  最佳 Epoch: {checkpoint.get('epoch', 'N/A')}")
        print(f"  验证集 PSNR: {checkpoint.get('psnr', 'N/A'):.2f} dB")
        print(f"  验证集 RMSE: {checkpoint.get('rmse', 'N/A'):.4f}")
        
        return model, config
    
    def predict(self, X):
        self.model.eval()
        with torch.no_grad():
            if X.ndim == 2:
                X = X[:, np.newaxis, :]
            X_tensor = torch.from_numpy(X.astype(np.float32)).to(self.device)
            pred = self.model(X_tensor).cpu().numpy()
        return pred
    
    def predict_batched(self, X, batch_size=1024):
        n_samples = len(X)
        predictions = []
        
        for i in tqdm(range(0, n_samples, batch_size), desc="预测中"):
            batch = X[i:i + batch_size]
            if batch.ndim == 2:
                batch = batch[:, np.newaxis, :]
            pred = self.predict(batch)
            predictions.append(pred)
        
        return np.concatenate(predictions, axis=0)
    
    # ==================== 测试模式 ====================
    
    def test_from_dataset(self, data_path, split='test'):
        """测试 FDM 数据集中的 test 集"""
        print(f"\n{'='*60}")
        print(f"测试模式: test_dataset ({split})")
        print('='*60)
        
        with h5py.File(data_path, 'r') as f:
            X = np.array(f[f'X_{split}']).T.astype(np.float32)
            Y = np.array(f[f'Y_{split}']).T.astype(np.float32)
        
        print(f"  X: {X.shape}")
        print(f"  Y: {Y.shape}")
        
        pred = self.predict_batched(X, batch_size=2048)
        
        return {'gt': Y, 'pred': pred, 'name': f'{split}_dataset'}
    
    def test_from_spectra(self, spectra, name="custom", add_noise=True):
        """从光谱数据测试"""
        print(f"\n{'='*60}")
        print(f"测试模式: {name}")
        print('='*60)
        
        spectra = np.array(spectra).astype(np.float32)
        if spectra.ndim == 1:
            spectra = spectra[np.newaxis, :]
        
        print(f"  输入光谱: {spectra.shape}")
        print(f"  添加噪声: {add_noise}")
        
        # 生成时域信号
        time_signals, gt_spectra = self.signal_generator.generate_signal(spectra, add_noise=add_noise)
        print(f"  时域信号: {time_signals.shape}")
        
        # 预测
        pred = self.predict_batched(time_signals, batch_size=2048)
        
        return {'gt': gt_spectra, 'pred': pred, 'name': name}
    
    def test_kaist_2d(self, kaist_2d_path, scene_idx=0, add_noise=True):
        """测试 KAIST 2D 场景"""
        print(f"\n{'='*60}")
        print(f"测试模式: kaist_2d (场景 {scene_idx})")
        print('='*60)
        
        # 加载 KAIST 2D
        kaist_2d = load_mat_auto(kaist_2d_path)
        print(f"  KAIST 2D shape: {kaist_2d.shape}")
        
        scene = kaist_2d[scene_idx]
        H, W, C = scene.shape
        print(f"  场景 {scene_idx}: {scene.shape}")
        
        # 展平
        spectra = scene.reshape(-1, C)
        
        # 生成信号并预测
        result = self.test_from_spectra(spectra, name=f"kaist_scene_{scene_idx}", add_noise=add_noise)
        
        # 重塑为图像
        result['gt_image'] = result['gt'].reshape(H, W, C)
        result['pred_image'] = result['pred'].reshape(H, W, C)
        result['shape'] = (H, W, C)
        
        return result
    
    def test_colorchecker(self, colorchecker_path, add_noise=True):
        """测试 ColorChecker"""
        print(f"\n{'='*60}")
        print(f"测试模式: colorchecker")
        print('='*60)
        
        # 加载 colorchecker
        spectra = load_mat_auto(colorchecker_path)
        print(f"  ColorChecker shape: {spectra.shape}")
        
        # 确保是 [N, 31]
        if spectra.shape[1] != 31 and spectra.shape[0] == 31:
            spectra = spectra.T
        
        return self.test_from_spectra(spectra, name="colorchecker", add_noise=add_noise)
    
    def test_custom(self, spectra_path, key=None, add_noise=True):
        """测试自定义光谱"""
        print(f"\n{'='*60}")
        print(f"测试模式: custom")
        print('='*60)
        
        if spectra_path.endswith('.npy'):
            spectra = np.load(spectra_path)
        else:
            spectra = load_mat_auto(spectra_path, key=key)
        
        if spectra.shape[1] != 31 and spectra.shape[0] == 31:
            spectra = spectra.T
        
        return self.test_from_spectra(spectra, name="custom", add_noise=add_noise)
    
    # ==================== 可视化 ====================
    
    def plot_spectral_comparison(self, result, save_path, max_plots=24):
        """光谱对比图"""
        gt = result['gt']
        pred = result['pred']
        n_samples = len(gt)
        
        n_plots = min(n_samples, max_plots)
        n_cols = min(6, n_plots)
        n_rows = (n_plots + n_cols - 1) // n_cols
        
        fig, axes = plt.subplots(n_rows, n_cols, figsize=(4 * n_cols, 3 * n_rows))
        if n_rows == 1:
            axes = axes[np.newaxis, :] if n_cols > 1 else np.array([[axes]])
        if n_cols == 1:
            axes = axes[:, np.newaxis]
        
        for i in range(n_plots):
            ax = axes[i // n_cols, i % n_cols]
            ax.plot(self.wavelengths, gt[i], 'b-', linewidth=2, label='GT')
            ax.plot(self.wavelengths, pred[i], 'r--', linewidth=2, label='Pred')
            ax.fill_between(self.wavelengths, gt[i], pred[i], alpha=0.3, color='gray')
            
            rmse = np.sqrt(np.mean((pred[i] - gt[i]) ** 2))
            psnr = 10 * np.log10(1.0 / (np.mean((pred[i] - gt[i]) ** 2) + 1e-10))
            
            ax.set_title(f'#{i+1} RMSE={rmse:.4f}\nPSNR={psnr:.1f}dB', fontsize=10)
            ax.set_xlabel('Wavelength (nm)', fontsize=8)
            ax.set_ylabel('Reflectance', fontsize=8)
            ax.set_xlim([400, 700])
            ax.grid(True, alpha=0.3)
            if i == 0:
                ax.legend(fontsize=8)
        
        # 隐藏多余的子图
        for i in range(n_plots, n_rows * n_cols):
            axes[i // n_cols, i % n_cols].axis('off')
        
        plt.suptitle(f"{result['name']} - Spectral Comparison", fontsize=14)
        plt.tight_layout()
        plt.savefig(save_path, dpi=150, bbox_inches='tight')
        plt.close()
        print(f"已保存: {save_path}")
    
    def plot_colorchecker_grid(self, result, save_path):
        """ColorChecker 网格图"""
        gt = result['gt']
        pred = result['pred']
        n_patches = len(gt)
        
        # 假设是 4x6 或 6x4 的 ColorChecker
        if n_patches == 24:
            rows, cols = 4, 6
        elif n_patches == 140:
            rows, cols = 10, 14
        else:
            cols = int(np.ceil(np.sqrt(n_patches)))
            rows = int(np.ceil(n_patches / cols))
        
        fig, axes = plt.subplots(2, 2, figsize=(14, 12))
        
        # GT RGB
        gt_rgb = spectrum_to_rgb(gt, self.wavelengths)
        gt_rgb_grid = np.zeros((rows, cols, 3))
        for i in range(min(n_patches, rows * cols)):
            gt_rgb_grid[i // cols, i % cols] = gt_rgb[i]
        
        axes[0, 0].imshow(gt_rgb_grid)
        axes[0, 0].set_title('Ground Truth RGB', fontsize=14)
        axes[0, 0].axis('off')
        
        # Pred RGB
        pred_rgb = spectrum_to_rgb(pred, self.wavelengths)
        pred_rgb_grid = np.zeros((rows, cols, 3))
        for i in range(min(n_patches, rows * cols)):
            pred_rgb_grid[i // cols, i % cols] = pred_rgb[i]
        
        axes[0, 1].imshow(pred_rgb_grid)
        axes[0, 1].set_title('Predicted RGB', fontsize=14)
        axes[0, 1].axis('off')
        
        # RMSE per patch
        rmse = compute_rmse(pred, gt)
        rmse_grid = np.zeros((rows, cols))
        for i in range(min(n_patches, rows * cols)):
            rmse_grid[i // cols, i % cols] = rmse[i]
        
        im = axes[1, 0].imshow(rmse_grid, cmap='hot')
        axes[1, 0].set_title(f'RMSE Map (mean={np.mean(rmse):.4f})', fontsize=14)
        axes[1, 0].axis('off')
        plt.colorbar(im, ax=axes[1, 0], fraction=0.046)
        
        # PSNR per patch
        psnr = compute_psnr(pred, gt)
        psnr_grid = np.zeros((rows, cols))
        for i in range(min(n_patches, rows * cols)):
            psnr_grid[i // cols, i % cols] = psnr[i]
        
        im = axes[1, 1].imshow(psnr_grid, cmap='jet')
        axes[1, 1].set_title(f'PSNR Map (mean={np.mean(psnr):.2f}dB)', fontsize=14)
        axes[1, 1].axis('off')
        plt.colorbar(im, ax=axes[1, 1], fraction=0.046)
        
        plt.suptitle(f"ColorChecker Results ({n_patches} patches)", fontsize=16)
        plt.tight_layout()
        plt.savefig(save_path, dpi=150, bbox_inches='tight')
        plt.close()
        print(f"已保存: {save_path}")
    
    def plot_2d_reconstruction(self, result, save_path):
        """2D 图像重建对比"""
        if 'gt_image' not in result:
            print("没有 2D 图像数据")
            return
        
        gt_image = result['gt_image']
        pred_image = result['pred_image']
        
        fig = plt.figure(figsize=(18, 12))
        
        gt_rgb = spectrum_to_rgb(gt_image, self.wavelengths)
        pred_rgb = spectrum_to_rgb(pred_image, self.wavelengths)
        
        ax1 = fig.add_subplot(2, 3, 1)
        ax1.imshow(gt_rgb)
        ax1.set_title('Ground Truth RGB', fontsize=14)
        ax1.axis('off')
        
        ax2 = fig.add_subplot(2, 3, 2)
        ax2.imshow(pred_rgb)
        ax2.set_title('Reconstructed RGB', fontsize=14)
        ax2.axis('off')
        
        ax3 = fig.add_subplot(2, 3, 3)
        rgb_diff = np.mean(np.abs(gt_rgb - pred_rgb), axis=-1)
        im = ax3.imshow(rgb_diff, cmap='hot')
        ax3.set_title('RGB Difference', fontsize=14)
        ax3.axis('off')
        plt.colorbar(im, ax=ax3, fraction=0.046)
        
        rmse_map = compute_rmse(pred_image, gt_image)
        psnr_map = compute_psnr(pred_image, gt_image)
        
        ax4 = fig.add_subplot(2, 3, 4)
        im = ax4.imshow(rmse_map, cmap='hot')
        ax4.set_title(f'RMSE Map (mean={rmse_map.mean():.4f})', fontsize=14)
        ax4.axis('off')
        plt.colorbar(im, ax=ax4, fraction=0.046)
        
        ax5 = fig.add_subplot(2, 3, 5)
        im = ax5.imshow(psnr_map, cmap='jet', vmin=np.percentile(psnr_map, 5))
        ax5.set_title(f'PSNR Map (mean={psnr_map.mean():.2f}dB)', fontsize=14)
        ax5.axis('off')
        plt.colorbar(im, ax=ax5, fraction=0.046)
        
        ax6 = fig.add_subplot(2, 3, 6)
        ax6.hist(psnr_map.flatten(), bins=100, color='steelblue', alpha=0.7)
        ax6.axvline(psnr_map.mean(), color='r', linestyle='--', label=f'Mean={psnr_map.mean():.2f}dB')
        ax6.set_xlabel('PSNR (dB)')
        ax6.set_ylabel('Count')
        ax6.set_title('PSNR Distribution')
        ax6.legend()
        
        plt.tight_layout()
        plt.savefig(save_path, dpi=150, bbox_inches='tight')
        plt.close()
        print(f"已保存: {save_path}")
    
    def plot_error_histogram(self, result, save_path):
        """误差分布直方图"""
        gt = result['gt']
        pred = result['pred']
        
        rmse = compute_rmse(pred, gt)
        psnr = compute_psnr(pred, gt)
        
        fig, axes = plt.subplots(1, 2, figsize=(12, 4))
        
        ax = axes[0]
        ax.hist(rmse, bins=50, color='steelblue', alpha=0.7, edgecolor='black')
        ax.axvline(np.mean(rmse), color='r', linestyle='--', linewidth=2, label=f'Mean={np.mean(rmse):.4f}')
        ax.set_xlabel('RMSE')
        ax.set_ylabel('Count')
        ax.set_title('RMSE Distribution')
        ax.legend()
        ax.grid(True, alpha=0.3)
        
        ax = axes[1]
        ax.hist(psnr, bins=50, color='coral', alpha=0.7, edgecolor='black')
        ax.axvline(np.mean(psnr), color='r', linestyle='--', linewidth=2, label=f'Mean={np.mean(psnr):.2f}dB')
        ax.set_xlabel('PSNR (dB)')
        ax.set_ylabel('Count')
        ax.set_title('PSNR Distribution')
        ax.legend()
        ax.grid(True, alpha=0.3)
        
        plt.suptitle(f"{result['name']} - Error Distribution", fontsize=14)
        plt.tight_layout()
        plt.savefig(save_path, dpi=150, bbox_inches='tight')
        plt.close()
        print(f"已保存: {save_path}")
    
    def print_statistics(self, result):
        """打印统计信息"""
        gt = result['gt']
        pred = result['pred']
        
        rmse = compute_rmse(pred, gt)
        psnr = compute_psnr(pred, gt)
        
        print(f"\n{'='*50}")
        print(f"{result['name']} - 统计结果")
        print('='*50)
        print(f"  样本数: {len(gt)}")
        print(f"  RMSE: {np.mean(rmse):.4f} ± {np.std(rmse):.4f}")
        print(f"  PSNR: {np.mean(psnr):.2f} ± {np.std(psnr):.2f} dB")
        print(f"  RMSE 范围: [{np.min(rmse):.4f}, {np.max(rmse):.4f}]")
        print(f"  PSNR 范围: [{np.min(psnr):.2f}, {np.max(psnr):.2f}] dB")
        print('='*50)
        
        return {'rmse_mean': np.mean(rmse), 'rmse_std': np.std(rmse),
                'psnr_mean': np.mean(psnr), 'psnr_std': np.std(psnr)}
    
    def generate_report(self, result, output_dir):
        """生成完整报告"""
        os.makedirs(output_dir, exist_ok=True)
        print(f"\n生成报告到: {output_dir}")
        
        # 统计信息
        stats = self.print_statistics(result)
        
        # 光谱对比
        self.plot_spectral_comparison(result, os.path.join(output_dir, '01_spectral_comparison.png'))
        
        # 误差分布
        self.plot_error_histogram(result, os.path.join(output_dir, '02_error_histogram.png'))
        
        # ColorChecker 特有
        if 'colorchecker' in result['name']:
            self.plot_colorchecker_grid(result, os.path.join(output_dir, '03_colorchecker_grid.png'))
        
        # 2D 图像
        if 'gt_image' in result:
            self.plot_2d_reconstruction(result, os.path.join(output_dir, '03_2d_reconstruction.png'))
        
        # 保存数据
        np.savez(os.path.join(output_dir, 'results.npz'),
                 gt=result['gt'], pred=result['pred'], **stats)
        
        print(f"\n报告已保存到: {output_dir}")
        return stats


# ===================== 主函数 =====================
def main():
    print('='*60)
    print('FDM 端到端模型测试')
    print('='*60)
    
    # 读取配置
    model_path = CONFIG['model_path']
    fdm_data_path = CONFIG['fdm_data_path']
    test_mode = CONFIG['test_mode']
    output_dir = CONFIG['output_dir']
    device = CONFIG['device']
    add_noise = CONFIG['add_noise']
    
    print(f"\n配置:")
    print(f"  模型: {model_path}")
    print(f"  FDM 数据: {fdm_data_path}")
    print(f"  测试模式: {test_mode}")
    print(f"  添加噪声: {add_noise}")
    print(f"  输出目录: {output_dir}")
    print(f"  设备: {device}")
    
    # 检查文件
    if not os.path.exists(model_path):
        print(f"\n[错误] 模型不存在: {model_path}")
        return
    
    if not os.path.exists(fdm_data_path):
        print(f"\n[错误] FDM 数据不存在: {fdm_data_path}")
        return
    
    # 创建测试器
    tester = FDMTester(model_path, fdm_data_path, device=device)
    
    # 根据模式测试
    if test_mode == "test_dataset":
        result = tester.test_from_dataset(fdm_data_path, split='test')
        report_dir = os.path.join(output_dir, 'test_dataset')
        
    elif test_mode == "kaist_2d":
        kaist_path = CONFIG['kaist_2d_path']
        scene_idx = CONFIG['scene_idx']
        if not os.path.exists(kaist_path):
            print(f"\n[错误] KAIST 2D 不存在: {kaist_path}")
            return
        result = tester.test_kaist_2d(kaist_path, scene_idx=scene_idx, add_noise=add_noise)
        report_dir = os.path.join(output_dir, f'kaist_scene_{scene_idx}')
        
    elif test_mode == "colorchecker":
        cc_path = CONFIG['colorchecker_path']
        if not os.path.exists(cc_path):
            print(f"\n[错误] ColorChecker 不存在: {cc_path}")
            return
        result = tester.test_colorchecker(cc_path, add_noise=add_noise)
        report_dir = os.path.join(output_dir, 'colorchecker')
        
    elif test_mode == "custom":
        custom_path = CONFIG['custom_spectra_path']
        custom_key = CONFIG['custom_spectra_key']
        if not os.path.exists(custom_path):
            print(f"\n[错误] 自定义光谱不存在: {custom_path}")
            return
        result = tester.test_custom(custom_path, key=custom_key, add_noise=add_noise)
        report_dir = os.path.join(output_dir, 'custom')
        
    else:
        print(f"\n[错误] 未知测试模式: {test_mode}")
        print("可选: test_dataset, kaist_2d, colorchecker, custom")
        return
    
    # 生成报告
    tester.generate_report(result, report_dir)
    
    print('\n' + '='*60)
    print('测试完成!')
    print('='*60)


if __name__ == '__main__':
    main()
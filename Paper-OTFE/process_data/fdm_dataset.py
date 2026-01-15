"""
FDM E2E 数据集加载器
"""

import torch
from torch.utils.data import Dataset, DataLoader
import numpy as np
import h5py
import scipy.io as sio


class FDMDataset(Dataset):
    """FDM端到端数据集"""
    
    def __init__(self, X, Y):
        """
        Args:
            X: 时域信号 [N, seq_len]
            Y: 光谱 [N, n_channels]
        """
        self.X = torch.FloatTensor(X)
        self.Y = torch.FloatTensor(Y)
        
    def __len__(self):
        return len(self.X)
    
    def __getitem__(self, idx):
        return self.X[idx], self.Y[idx]


def load_fdm_dataset(mat_path, batch_size=64, num_workers=4):
    """
    加载FDM数据集
    
    Args:
        mat_path: .mat文件路径
        batch_size: 批次大小
        num_workers: 数据加载线程数
        
    Returns:
        train_loader, val_loader, test_loader, config
    """
    print(f"加载数据集: {mat_path}")
    
    # 尝试用h5py加载（v7.3格式）
    try:
        with h5py.File(mat_path, 'r') as f:
            X_train = np.array(f['X_train']).T  # HDF5存储是转置的
            Y_train = np.array(f['Y_train']).T
            X_val = np.array(f['X_val']).T
            Y_val = np.array(f['Y_val']).T
            X_test = np.array(f['X_test']).T
            Y_test = np.array(f['Y_test']).T
            
            # 加载配置
            config = {}
            if 'config' in f:
                config_group = f['config']
                for key in config_group.keys():
                    try:
                        val = config_group[key][()]
                        if isinstance(val, np.ndarray) and val.size == 1:
                            val = val.item()
                        config[key] = val
                    except:
                        pass
    except:
        # 用scipy加载
        data = sio.loadmat(mat_path)
        X_train = data['X_train']
        Y_train = data['Y_train']
        X_val = data['X_val']
        Y_val = data['Y_val']
        X_test = data['X_test']
        Y_test = data['Y_test']
        config = data.get('config', {})
    
    print(f"  训练集: X{X_train.shape} -> Y{Y_train.shape}")
    print(f"  验证集: X{X_val.shape} -> Y{Y_val.shape}")
    print(f"  测试集: X{X_test.shape} -> Y{Y_test.shape}")
    
    # 创建数据集
    train_dataset = FDMDataset(X_train, Y_train)
    val_dataset = FDMDataset(X_val, Y_val)
    test_dataset = FDMDataset(X_test, Y_test)
    
    # 创建DataLoader
    train_loader = DataLoader(
        train_dataset, 
        batch_size=batch_size, 
        shuffle=True, 
        num_workers=num_workers,
        pin_memory=True
    )
    val_loader = DataLoader(
        val_dataset, 
        batch_size=batch_size, 
        shuffle=False, 
        num_workers=num_workers,
        pin_memory=True
    )
    test_loader = DataLoader(
        test_dataset, 
        batch_size=batch_size, 
        shuffle=False, 
        num_workers=num_workers,
        pin_memory=True
    )
    
    return train_loader, val_loader, test_loader, config


if __name__ == "__main__":
    # 测试加载
    mat_path = "./dataset/fdm_e2e_10000pts_zscore_fast.mat"
    train_loader, val_loader, test_loader, config = load_fdm_dataset(mat_path, batch_size=64)
    
    # 查看一个批次
    for X, Y in train_loader:
        print(f"X shape: {X.shape}, Y shape: {Y.shape}")
        print(f"X range: [{X.min():.3f}, {X.max():.3f}]")
        print(f"Y range: [{Y.min():.3f}, {Y.max():.3f}]")
        break

"""
FDM E2E 一键训练和测试脚本
"""

import os
import subprocess
import sys


def main():
    print("=" * 60)
    print("FDM E2E Pipeline")
    print("=" * 60)
    
    # 配置
    data_path = "./dataset/fdm_e2e_10000pts_zscore_fast.mat"
    wfm_dir = "./data/PD-01-04/"
    gt_path = "./colorchecker_gt.mat"
    save_dir = "./checkpoints"
    test_save_dir = "./test_results"
    
    # 检查数据集
    if not os.path.exists(data_path):
        print(f"错误: 数据集不存在: {data_path}")
        print("请先运行 MATLAB 脚本 generate_fdm_dataset_fast.m 生成数据集")
        return
    
    print(f"\n数据集: {data_path}")
    print(f"wfm目录: {wfm_dir}")
    print(f"真值文件: {gt_path}")
    
    # 1. 训练
    print("\n" + "=" * 60)
    print("Step 1: 训练模型")
    print("=" * 60)
    
    train_cmd = [
        sys.executable, "train.py",
        "--data_path", data_path,
        "--model", "base",
        "--batch_size", "64",
        "--epochs", "100",
        "--lr", "1e-3",
        "--patience", "15",
        "--scheduler", "plateau",
        "--save_dir", save_dir
    ]
    
    print(f"命令: {' '.join(train_cmd)}")
    subprocess.run(train_cmd)
    
    # 2. 测试
    print("\n" + "=" * 60)
    print("Step 2: 真实数据测试")
    print("=" * 60)
    
    checkpoint_path = os.path.join(save_dir, "best_model.pth")
    
    if not os.path.exists(checkpoint_path):
        print(f"错误: 模型文件不存在: {checkpoint_path}")
        return
    
    test_cmd = [
        sys.executable, "test_real.py",
        "--checkpoint", checkpoint_path,
        "--wfm_dir", wfm_dir,
        "--gt_path", gt_path,
        "--save_dir", test_save_dir
    ]
    
    print(f"命令: {' '.join(test_cmd)}")
    subprocess.run(test_cmd)
    
    print("\n" + "=" * 60)
    print("完成!")
    print("=" * 60)
    print(f"模型保存: {save_dir}")
    print(f"测试结果: {test_save_dir}")


if __name__ == "__main__":
    main()

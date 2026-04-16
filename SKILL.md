---
name: vllm-ascend-setup
description: 搭建 vllm-ascend 开发环境的技能。当用户提到搭建 vllm-ascend、vllm ascend 开发环境、安装 vllm-ascend 或配置昇腾 NPU 上的 vllm 时使用此技能。
---

# vllm-ascend 开发环境搭建技能

此技能用于自动化搭建 vllm-ascend 开发环境，包括检查驱动、选择 Python 版本、安装 vLLM 和 vLLM Ascend，以及运行测试。

## 步骤概述

1. 检查 NPU 驱动是否安装
2. 检测并选择 Python 解释器
3. 获取官方文档中的 Python 版本要求
4. 克隆并安装 vLLM 和 vLLM Ascend
5. 获取版本对应关系并切换到正确的 vLLM 版本
6. 验证 vllm-ascend 编译是否成功
7. 配置 LD_LIBRARY_PATH 环境变量
8. 运行测试验证安装

## 详细执行步骤

### 步骤 1: 检查 NPU 驱动

首先检查 `npu-smi info` 是否能成功运行：

```bash
npu-smi info
```

- 如果命令成功运行，说明 NPU 驱动已安装，继续下一步
- 如果命令失败，告知用户需要先安装昇腾 NPU 驱动

### 步骤 2: 检测 Python 解释器

检测系统中可用的 Python 解释器：

```bash
which python3 python
python3 --version
python --version 2>/dev/null || true
```

向用户展示可用的 Python 解释器及其版本，并询问使用哪个。

### 步骤 3: 获取 Python 版本要求

使用 WebFetch 工具获取官方文档中的 Python 版本要求：

```
url: https://docs.vllm.ai/projects/vllm-ascend-cn/zh-cn/latest/installation.html#set-up-using-python
prompt: 请提取此页面中关于 Python 版本要求的信息，包括支持的 Python 版本范围
```

将文档中的 Python 版本要求与用户选择的 Python 版本进行对比，确认兼容性。

### 步骤 4: 安装 vLLM 和 vLLM Ascend

创建工作目录并克隆仓库：

```bash
mkdir -p vllm_dev
cd vllm_dev

# Install vLLM
git clone https://github.com/vllm-project/vllm.git
cd vllm
VLLM_TARGET_DEVICE=empty <python-exec> -m pip install -v -e .
cd ..

# Install vLLM Ascend
git clone https://github.com/vllm-project/vllm-ascend.git
cd vllm-ascend
git submodule update --init --recursive
<python-exec> -m pip install --no-build-isolation -v -e .
cd ..
```

注意：将 `<python-exec>` 替换为用户选择的 Python 解释器路径。

### 步骤 5: 获取版本对应关系

使用 WebFetch 工具获取版本策略页面：

```
url: https://docs.vllm.ai/projects/vllm-ascend-cn/zh-cn/latest/community/versioning_policy.html
prompt: 请提取此页面中关于 vllm-ascend main 分支对应的 vLLM 版本信息
```

根据获取到的版本信息，切换 vLLM 仓库到对应的版本：

```bash
cd vllm_dev/vllm
git checkout <compatible-version>
<python-exec> -m pip install -v -e .
cd ..
```

### 步骤 6: 验证 vllm-ascend 编译是否成功

使用技能自带的脚本验证编译：

```bash
cd vllm_dev/vllm-ascend

# 复制并运行验证脚本
cp <skill-path>/scripts/verify_compilation.sh .
chmod +x verify_compilation.sh
./verify_compilation.sh
```

或者手动检查关键文件：
- `vllm_ascend/libvllm_ascend_kernels.so` 存在
- `vllm_ascend/vllm_ascend_C*.so` (Python 扩展模块) 存在
- `build/lib.linux-*/` 目录存在且包含编译产物

### 步骤 7: 配置 LD_LIBRARY_PATH 环境变量

使用技能自带的脚本配置环境变量：

```bash
cd vllm_dev/vllm-ascend

# 复制并运行配置脚本
cp <skill-path>/scripts/setup_ld_library_path.sh .
chmod +x setup_ld_library_path.sh
./setup_ld_library_path.sh . persist
```

脚本会自动：
- 将 `vllm_ascend/` 和 `vllm_ascend/lib64/` 添加到 LD_LIBRARY_PATH
- 可选地持久化到 ~/.bashrc 或 ~/.zshrc

### 步骤 8: 运行测试

使用技能自带的测试脚本：

```bash
cd vllm_dev

# 复制测试脚本
cp <skill-path>/scripts/test_vllm_ascend.py .

# 运行测试
<python-exec> test_vllm_ascend.py
```

## 注意事项

- 确保用户有足够的磁盘空间（至少 10GB）
- 安装过程可能需要较长时间，请告知用户耐心等待
- 如果遇到网络问题，可以建议用户配置镜像源
- 测试时需要下载模型，确保网络连接稳定

## 脚本文件说明

技能包含以下辅助脚本（位于 `scripts/` 目录）：

| 脚本 | 用途 |
|------|------|
| `verify_compilation.sh` | 验证编译是否成功 |
| `setup_ld_library_path.sh` | 配置 LD_LIBRARY_PATH |
| `test_vllm_ascend.py` | vllm-ascend 功能测试脚本 |

---
name: vllm-ascend-setup
description: 搭建、安装、验证和排查 vllm-ascend 开发环境的技能。用户提到 vllm-ascend、vllm ascend、昇腾 NPU 上的 vLLM、Ascend NPU 推理环境、vLLM Ascend pip/source/docker 安装、版本兼容矩阵、CANN/torch-npu/vLLM 版本匹配或安装后 smoke test 时使用。
---

# vllm-ascend 开发环境搭建

按官方文档和版本矩阵先确定兼容组合，再安装。不要先安装 main 再回头切版本；这会浪费时间并污染环境。

## 官方入口

优先读取当前官方文档：

```bash
curl -sL https://docs.vllm.ai/projects/ascend/en/latest/_sources/installation.md
curl -sL https://docs.vllm.ai/projects/ascend/en/latest/_sources/community/versioning_policy.md
```

如需中文页面，可同时查看：

```bash
curl -sL https://docs.vllm.ai/projects/ascend/zh-cn/latest/installation.html
```

默认优先使用 GitCode 镜像，国内网络通常更稳定：

```text
vLLM: https://gitcode.com/GitHub_Trending/vl/vllm.git
vLLM Ascend: https://gitcode.com/gh_mirrors/vl/vllm-ascend.git
```

如果 GitCode 镜像缺少目标 branch/tag/commit、疑似同步滞后，或需要核对上游内容，再使用 GitHub 官方仓库：

```text
vLLM: https://github.com/vllm-project/vllm.git
vLLM Ascend: https://github.com/vllm-project/vllm-ascend.git
```

## 执行流程

1. 检查硬件、驱动和 CANN。
2. 读取版本矩阵，确定 vLLM Ascend、vLLM、Python、CANN、PyTorch/torch-npu、Triton Ascend 的兼容组合。
3. 选择安装方式：优先 pip/wheel，开发场景用 source，隔离或部署场景用 Docker。
4. 创建或选择 Python 环境并确认版本兼容。
5. 执行安装，避免混用不兼容源。
6. 验证编译产物或安装包，并运行 smoke test。
7. 只在用户明确要求时持久化 `LD_LIBRARY_PATH`。

## 1. 环境检查

检查 NPU 驱动：

```bash
npu-smi info
```

如果 `npu-smi` 不存在或失败，先让用户安装/修复昇腾驱动。CPU-only 构建环境可继续，但安装前必须设置目标芯片：

```bash
export SOC_VERSION=ascend910b1      # Atlas A2 示例
export SOC_VERSION=ascend910_9391   # Atlas A3 示例
export SOC_VERSION=ascend310p1      # Atlas 300I 示例
```

检查 CANN、编译器和 Python：

```bash
which python3 python || true
python3 --version
gcc --version
g++ --version
python3 -m pip --version
python3 - <<'PY'
try:
    import torch, torch_npu
    print("torch", torch.__version__)
    print("torch_npu", torch_npu.__version__)
except Exception as exc:
    print("torch/torch_npu check failed:", exc)
PY
```

按版本矩阵确认 Python 和 CANN 兼容。vLLM Ascend 构建自定义算子时通常需要 gcc/g++ 大于 8 且支持 C++17。

## 2. 解析版本矩阵

先读取版本策略页面，再选择目标版本：

```bash
curl -sL https://docs.vllm.ai/projects/ascend/en/latest/_sources/community/versioning_policy.md
```

选择规则：

- 普通用户或可复现环境：使用 release/rc 矩阵中成对的 `vllm-ascend` 和 `vllm` 版本。
- 需要跟进最新开发：使用 main 表中的 vLLM commit/tag，并说明 latest 文档是 developer preview，可能变化。
- 不要把任意 vLLM main 和任意 vllm-ascend 分支混装。

记录选择结果，例如：

```text
vllm-ascend=<version-or-branch>
vllm=<version-or-commit>
python=<required-range>
cann=<required-version>
torch_npu=<required-version>
```

## 3. 安装方式

### Pip/wheel 优先

如果用户只是使用 vLLM Ascend，不需要改源码，优先按官方安装页使用 pip/wheel。安装前确认 Python 环境干净：

```bash
python3 -m venv vllm-ascend-env
source vllm-ascend-env/bin/activate
python -m pip install -U pip
```

然后按官方文档当前给出的 index 和版本安装 `vllm` 与 `vllm-ascend`。不要硬编码旧版本；每次以安装页和版本矩阵为准。

### Source 开发安装

需要改 vLLM 或 vLLM Ascend 源码时使用 source 路线。先把 `<vllm-version>` 和 `<vllm-ascend-version>` 替换为版本矩阵中的值：

```bash
mkdir -p vllm_dev
cd vllm_dev

git clone --depth 1 --branch <vllm-version> https://gitcode.com/GitHub_Trending/vl/vllm.git
cd vllm
VLLM_TARGET_DEVICE=empty <python-exec> -m pip install -v -e .
cd ..

git clone --depth 1 --branch <vllm-ascend-version> https://gitcode.com/gh_mirrors/vl/vllm-ascend.git
cd vllm-ascend
git submodule update --init --recursive
<python-exec> -m pip install -v -e .
cd ..
```

如果 `pip install -e .` 遇到 torch-npu 版本隔离冲突，再改用：

```bash
<python-exec> -m pip install --no-build-isolation -v -e .
```

如果 GitCode 镜像不可用或没有目标版本，改用 GitHub 官方仓库，并保持相同 branch/tag/commit。

### Docker

需要隔离环境、部署或复现官方容器时，优先使用官方镜像 `quay.io/ascend/vllm-ascend:<tag>`。按安装页选择 A2/A3/300I 和 OS 对应 tag，并根据机器实际 `/dev/davinci*` 数量调整 `--device`。

## 4. 验证安装

Source 构建完成后，可运行技能脚本检查编译产物：

```bash
cd vllm_dev/vllm-ascend
<skill-path>/scripts/verify_compilation.sh .
```

如需在当前 shell 临时配置动态库路径，使用：

```bash
eval "$(<skill-path>/scripts/setup_ld_library_path.sh . --print-export)"
```

不要默认持久化到 shell rc。只有用户明确要求时才运行：

```bash
<skill-path>/scripts/setup_ld_library_path.sh . --persist
```

运行 smoke test：

```bash
cd vllm_dev
<python-exec> <skill-path>/scripts/test_vllm_ascend.py --model Qwen/Qwen3-0.6B
```

如果 Hugging Face 下载失败，可切换 ModelScope：

```bash
export VLLM_USE_MODELSCOPE=True
<python-exec> -m pip install modelscope
<python-exec> <skill-path>/scripts/test_vllm_ascend.py --model Qwen/Qwen3-0.6B
```

测试会下载模型；先确认网络和磁盘空间。也可以把 `--model` 指向本地模型目录。

## 排查要点

- `InvalidVersion`：通常是 editable/dev 版 vLLM 版本无法识别；按官方提示设置 `VLLM_VERSION=<matched-version>`。
- 编译失败：检查 gcc/g++、C++17、CANN、torch-npu、`SOC_VERSION`、submodule 是否完整。
- 找不到 `.so`：先用 `verify_compilation.sh` 定位缺失产物，再检查 `LD_LIBRARY_PATH`。
- NPU 不可见：先修复驱动、容器 device mount、`/usr/local/Ascend/driver` mount 和 `npu-smi info`。

## 脚本

| 脚本 | 用途 |
|------|------|
| `scripts/verify_compilation.sh` | 验证 source 构建产物 |
| `scripts/setup_ld_library_path.sh` | 输出/配置 vLLM Ascend 动态库路径，默认不持久化 |
| `scripts/test_vllm_ascend.py` | 可配置模型的 smoke test |

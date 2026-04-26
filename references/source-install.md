# 源码安装流程

创建 Python 环境、clone 布局、constraints、editable 安装以及 Triton Ascend 校正时，使用本参考。

## Python 环境选择

不要默认污染系统 Python。先检查：

```bash
which uv || true
python3 --version
python3 - <<'PY'
import sys
print(sys.executable)
for name in ("torch", "torch_npu", "vllm", "vllm_ascend"):
    try:
        mod = __import__(name)
        print(name, getattr(mod, "__version__", "unknown"))
    except Exception as exc:
        print(name, "missing/error:", exc)
PY
```

决策规则：

- 已安装 `uv`：默认使用 `uv venv` + `uv pip`。
- 未安装 `uv`，用户只要最快的一次性搭建：使用 `python3 -m venv`。
- 用户要长期开发、反复重装，或明确要求 uv：用阿里源安装 uv，然后使用 uv。
- 只有用户在看到包状态和污染风险后明确选择全局 Python，才使用全局 Python。

安装 uv：

```bash
python3 -m pip install -i https://mirrors.aliyun.com/pypi/simple/ -U uv
```

创建 uv 环境：

```bash
mkdir -p /root/vllm_dev
cd /root/vllm_dev
uv venv .venv --python python3
source .venv/bin/activate
uv pip install --python /root/vllm_dev/.venv/bin/python \
  --index-url https://mirrors.aliyun.com/pypi/simple/ \
  -U pip setuptools wheel
```

创建标准 venv：

```bash
mkdir -p /root/vllm_dev
cd /root/vllm_dev
python3 -m venv .venv
source .venv/bin/activate
python -m pip install -i https://mirrors.aliyun.com/pypi/simple/ -U pip setuptools wheel
```

设置辅助变量：

```bash
PY=/root/vllm_dev/.venv/bin/python
PIP="$PY -m pip"
UV_PIP="uv pip install --python /root/vllm_dev/.venv/bin/python --index-url https://mirrors.aliyun.com/pypi/simple/ --index-strategy unsafe-best-match"
```

## 仓库来源

国内优先尝试这些 GitCode 镜像：

```text
vLLM GitCode:        https://gitcode.com/GitHub_Trending/vl/vllm.git
vLLM Ascend GitCode: https://gitcode.com/gh_mirrors/vl/vllm-ascend.git
```

如果镜像缺少所需 ref、同步滞后或失败，回退到官方 GitHub：

```text
vLLM GitHub:         https://github.com/vllm-project/vllm.git
vLLM Ascend GitHub:  https://github.com/vllm-project/vllm-ascend.git
```

## 运行时 Constraints

根据所选版本矩阵创建 constraints 文件。示例形态：

```bash
cat > /root/vllm_dev/vllm-ascend-constraints.txt <<'EOF'
torch==<matched-version>
torchvision==<matched-version-for-torch>
torchaudio==<matched-version>
torch-npu==<matched-version>
numpy<2.0.0
opencv-python-headless<=4.11.0.86
fastapi<0.124.0
setuptools<81
triton-ascend==<matched-version>
EOF
```

当 resolver 可能拉取更新的 torch/numpy/OpenCV 时，预装运行时基础包：

```bash
$PIP install \
  -i https://mirrors.aliyun.com/pypi/simple/ \
  --extra-index-url https://download.pytorch.org/whl/cpu/ \
  --extra-index-url https://mirrors.huaweicloud.com/ascend/repos/pypi \
  -c /root/vllm_dev/vllm-ascend-constraints.txt \
  "torch==<matched-version>" \
  "torchvision==<matched-version-for-torch>" \
  "torchaudio==<matched-version>" \
  "torch-npu==<matched-version>" \
  "numpy<2.0.0" \
  "opencv-python-headless<=4.11.0.86" \
  "fastapi<0.124.0" \
  "setuptools<81"
```

## 从源码安装 vLLM

checkout 版本矩阵指定的 vLLM ref。对于 vLLM Ascend main，当 `main_vllm_commit` 和 `main_vllm_tag` 同时存在时，优先使用 `main_vllm_commit`：

```bash
cd /root/vllm_dev
git clone https://gitcode.com/GitHub_Trending/vl/vllm.git
cd vllm
git checkout <main_vllm_commit-or-release-ref>
VLLM_TARGET_DEVICE=empty $PIP install \
  -i https://mirrors.aliyun.com/pypi/simple/ \
  --extra-index-url https://download.pytorch.org/whl/cpu/ \
  -c /root/vllm_dev/vllm-ascend-constraints.txt \
  -v -e .
```

使用 uv：

```bash
cd /root/vllm_dev/vllm
VLLM_TARGET_DEVICE=empty $UV_PIP \
  --extra-index-url https://download.pytorch.org/whl/cpu/ \
  -c /root/vllm_dev/vllm-ascend-constraints.txt \
  -v -e .
```

如果浅 clone 或镜像中没有精确 commit，从所选 remote 显式 fetch；必要时回退到官方 GitHub：

```bash
git fetch origin <main_vllm_commit> --depth 1
git checkout <main_vllm_commit>
```

立即验证：

```bash
$PIP check
$PY - <<'PY'
import torch, vllm
print("torch", torch.__version__)
print("vllm", getattr(vllm, "__version__", "unknown"))
PY
```

## 从源码安装 vLLM Ascend

checkout 用户要求的 vLLM Ascend ref：

```bash
cd /root/vllm_dev
git clone https://gitcode.com/gh_mirrors/vl/vllm-ascend.git
cd vllm-ascend
git checkout <vllm-ascend-ref>
git submodule update --init --recursive
```

source Ascend 环境并构建：

```bash
source /usr/local/Ascend/ascend-toolkit/set_env.sh
source /usr/local/Ascend/nnal/atb/set_env.sh 2>/dev/null || true
export SOC_VERSION=ascend910b1
export TASK_QUEUE_ENABLE=1
export OMP_NUM_THREADS=1

$PIP install \
  -i https://mirrors.aliyun.com/pypi/simple/ \
  --extra-index-url https://download.pytorch.org/whl/cpu/ \
  --extra-index-url https://mirrors.huaweicloud.com/ascend/repos/pypi \
  -c /root/vllm_dev/vllm-ascend-constraints.txt \
  -v -e .
```

如果 build isolation 安装了不兼容依赖，使用：

```bash
$PIP install --no-build-isolation \
  -i https://mirrors.aliyun.com/pypi/simple/ \
  --extra-index-url https://download.pytorch.org/whl/cpu/ \
  --extra-index-url https://mirrors.huaweicloud.com/ascend/repos/pypi \
  -c /root/vllm_dev/vllm-ascend-constraints.txt \
  -v -e .
```

使用 uv 时，保持同样的 index 选择：

```bash
$UV_PIP \
  --extra-index-url https://download.pytorch.org/whl/cpu/ \
  --extra-index-url https://mirrors.huaweicloud.com/ascend/repos/pypi \
  -c /root/vllm_dev/vllm-ascend-constraints.txt \
  -v -e .
```

## Triton Ascend 校正

vLLM Ascend 安装后，按照目标版本矩阵和 Dockerfile 顺序处理：

```bash
$PIP uninstall -y triton triton-ascend
$PIP install \
  -i https://mirrors.aliyun.com/pypi/simple/ \
  --extra-index-url https://mirrors.huaweicloud.com/ascend/repos/pypi \
  "triton-ascend==<matched-version>"
```

下一步运行验证；见 `validation.md`。

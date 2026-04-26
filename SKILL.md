---
name: vllm-ascend-setup
description: 快速搭建、安装、验证和排查 vllm-ascend 源码开发环境。用户提到 vllm-ascend、vllm ascend、昇腾 NPU 上的 vLLM、vLLM Ascend main 分支、源码安装、开发环境、Ascend NPU 推理环境、CANN/torch-npu/vLLM 版本匹配、uv/venv 环境或安装后 smoke test 时使用。
---

# vLLM Ascend Source Dev Setup

此技能用于快速搭建 **vLLM + vLLM Ascend 源码开发环境**。默认目标是开发环境，不是 wheel-only 用户环境：除非用户明确要求 Docker、现成 wheel 或只做文档解释，否则 vLLM 和 vLLM Ascend 都从源码 clone，并用 editable install。

## Core Rules

- 默认 `vllm-ascend=main`，除非用户指定 release、tag 或 commit。
- 安装前必须读取当前官方版本关系；不要凭记忆安装。`main` 分支以 `vllm-ascend/docs/source/conf.py` 的 `myst_substitutions` 里 `main_*` 字段为准，也可用渲染后的 versioning matrix 交叉验证。
- `main_vllm_commit` 和 `main_vllm_tag` 同时存在时，优先 checkout 精确 commit；tag 只作人类可读版本标签。不要只停在 tag，因为 main 可能要求 tag 后的兼容 commit。
- `conf.py` 中发布版字段、pip 字段、镜像 tag 字段不得覆盖 `main_*`。例如 `cann_image_tag` 可能描述容器镜像，不等于 main 分支要求。
- CANN/NNAL 与目标矩阵不匹配时必须暂停并给出解决路径；不能只记录风险后继续。只有用户明确要求非官方组合时，才继续。
- Python 默认使用隔离环境。用户未指定时，若 `uv` 已安装则优先 `uv venv`；若未安装且只求最快首次搭建，用 `python3 -m venv`；长期开发或用户要求 uv 时先安装 uv。PyPI 默认阿里源。
- 国内源码 clone 默认可先试 GitCode 镜像，缺 branch/tag/commit、同步滞后或失败时回退 GitHub 官方仓库，并保持同一 ref。
- 运行时版本以 vLLM Ascend 版本矩阵为准。vLLM `pyproject.toml [build-system].requires` 中的 torch 是构建隔离依赖，不可误判为目标运行时 torch。
- 安装完成后按矩阵校正 Triton：卸载普通 `triton`/旧 `triton-ascend`，安装矩阵指定的 `triton-ascend`。

## Reference Map

按需读取，不要一次性加载全部 reference：

- 版本选择、`conf.py` 字段优先级、CANN/NNAL gate：读 `references/version-matrix.md`。
- Python 环境、clone、constraints、源码 editable install、Triton 校正：读 `references/source-install.md`。
- import、`pip check`、编译产物、`LD_LIBRARY_PATH`、smoke test：读 `references/validation.md`。
- numpy/OpenCV、全局 `torch-npu` 路径、build isolation、uv index、编译失败等问题：读 `references/troubleshooting.md`。

## Fast Workflow

1. 检查 NPU、CANN/NNAL、Python、编译器和当前 Python 包状态。
2. 读取 `conf.py` 或 versioning matrix，确定：
   - `vllm-ascend=<branch/tag/commit>`
   - `vllm=<tag/commit>`
   - `python=<range>`
   - `cann=<version>`
   - `torch=<version>`
   - `torch_npu=<version>`
   - `triton_ascend=<version>`
3. 对比本机 CANN/NNAL 与矩阵。匹配才继续；不匹配就让用户选择升级 CANN/NNAL 或切换兼容 release。
4. 选择 Python 环境。没有明确选择时，优先隔离环境；`uv` 已存在则用 `uv`，否则按速度和长期维护成本选择 `venv` 或先安装 `uv`。
5. clone vLLM，checkout 矩阵指定 vLLM 精确 commit/ref，用 `VLLM_TARGET_DEVICE=empty` editable 安装。
6. clone vLLM Ascend，checkout 用户目标分支/tag，初始化 submodule，source Ascend env，editable 安装。
7. 校正 `triton-ascend`，运行 import、`pip check`、编译产物检查和 smoke test。
8. 只在用户明确要求时持久化 `LD_LIBRARY_PATH`；默认只输出当前 shell 可用的临时 export。

## Required Checks

环境检查最小集合：

```bash
npu-smi info
find /usr/local/Ascend -maxdepth 4 \( -name set_env.sh -o -name version.info \) -print
python3 --version
which python3 python uv || true
gcc --version
g++ --version
python3 -m pip --version
```

当前 Python 包状态：

```bash
python3 - <<'PY'
for name in ("torch", "torch_npu", "vllm", "vllm_ascend"):
    try:
        mod = __import__(name)
        print(name, getattr(mod, "__version__", "unknown"))
    except Exception as exc:
        print(name, "missing/error:", exc)
PY
```

目标芯片需要显式设置，示例：

```bash
export SOC_VERSION=ascend910b1      # Atlas A2 / 910B
export SOC_VERSION=ascend910_9391   # Atlas A3
export SOC_VERSION=ascend310p1      # Atlas 300I
```

## Source Policy

- vLLM 源码安装时使用 `VLLM_TARGET_DEVICE=empty`，因为 NPU 后端由 vLLM Ascend 插件提供。
- 优先用 constraints 锁定矩阵运行时包，避免 resolver 拉取最新版 torch、numpy 或 OpenCV。
- 若 vLLM 与 vLLM Ascend 的 Python 依赖发生可解析性冲突，优先保持 vLLM Ascend runtime matrix，并对本地源码 checkout 做最小补丁，最终说明中记录补丁。
- 若全局 Python 中存在旧 `torch-npu`，必须确认 vLLM Ascend 构建脚本没有用裸 `python3` 解析 `torch-npu` 路径；应使用当前虚拟环境的 `sys.executable`。

## Bundled Scripts

| Script | Purpose |
| --- | --- |
| `scripts/verify_compilation.sh` | 验证 source 构建产物 |
| `scripts/setup_ld_library_path.sh` | 输出/配置 vLLM Ascend 动态库和自定义 OPP 路径，默认不持久化 |
| `scripts/test_vllm_ascend.py` | 可配置模型的 smoke test |

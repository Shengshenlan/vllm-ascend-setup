# 排障

安装、import、编译或 smoke test 失败时，使用本参考。

## 版本不匹配是停止条件

如果 CANN/NNAL 与所选版本矩阵不同，不要当作正常安装继续。停止并选择升级 CANN/NNAL，或切换到与当前环境兼容的 vLLM Ascend/vLLM ref。只有用户明确接受非官方组合时，才继续。

## 只用 main_vllm_tag 不够

如果 smoke test 因 vLLM Ascend 导入的 vLLM 模块缺失而失败，例如：

```text
ModuleNotFoundError: No module named 'vllm.model_executor.models.qwen3_dflash'
```

检查 vLLM 是否从 `main_vllm_tag` 安装，而不是从 `main_vllm_commit` 安装。对于 main，切换 vLLM 到 `conf.py` 里的精确 commit，然后重新 editable 安装：

```bash
cd /root/vllm_dev/vllm
git fetch origin <main_vllm_commit> --depth 1
git checkout <main_vllm_commit>
VLLM_TARGET_DEVICE=empty $PIP install --no-build-isolation -v -e .
```

checkout 后，重新应用必要的本地依赖兼容补丁，例如 OpenCV/numpy 约束。

## numpy 与 OpenCV Resolver 冲突

已知模式：vLLM 源码可能要求 `opencv-python-headless>=4.13.0`，而 vLLM Ascend main 可能要求 `numpy<2.0.0` 和 `opencv-python-headless<=4.11.0.86`。较新的 OpenCV wheel 可能强制 `numpy>=2`，导致环境不可解。

对于源码开发环境，优先保持 vLLM Ascend 运行时矩阵，并对 vLLM checkout 做最小本地补丁：

```text
requirements/common.txt:
opencv-python-headless <= 4.11.0.86
```

最终答复中记录这是本地开发补丁。

## 全局 torch-npu 路径泄漏

如果全局 Python 中存在旧的或不兼容的 `torch-npu`，vLLM Ascend `setup.py` 在执行裸 `python3 -m pip show torch-npu` 时可能误找到全局头文件。这会导致头文件/版本不匹配，例如缺少 `AclOpCompileInterface.h`。

把本地源码 patch 为使用当前解释器：

```python
torch_npu_command = f"{sys.executable} -m pip show torch-npu | grep '^Location:' | awk '{{print $2}}'"
```

然后清理并重建：

```bash
rm -rf /root/vllm_dev/vllm-ascend/csrc/build
$PIP install --no-build-isolation \
  -i https://mirrors.aliyun.com/pypi/simple/ \
  --extra-index-url https://download.pytorch.org/whl/cpu/ \
  --extra-index-url https://mirrors.huaweicloud.com/ascend/repos/pypi \
  -c /root/vllm_dev/vllm-ascend-constraints.txt \
  -v -e /root/vllm_dev/vllm-ascend
```

## Build Isolation 拉取错误包

症状：

- build 日志显示 torch 版本与矩阵不同；
- pip 虽有 constraints，仍安装最新版 torch/numpy；
- metadata build 成功，但运行时 import 失败。

预装矩阵版本后使用 `--no-build-isolation`：

```bash
$PIP install --no-build-isolation -v -e /root/vllm_dev/vllm-ascend
```

记住：vLLM build-system 中的 torch 不一定是运行时 torch。

## xgrammar 要求 triton，但 Ascend 使用 triton-ascend

官方 vLLM Ascend Dockerfile 会在 vLLM 安装后卸载普通 `triton`，再安装 `triton-ascend==<matrix-version>`。在 x86_64 上，`xgrammar` wheel 仍可能声明 `Requires-Dist: triton`，所以 `pip check` 可能报告：

```text
xgrammar ... requires triton, which is not installed.
```

不要通过保留普通 `triton` 来修复，因为它可能覆盖 `triton-ascend` 提供的 `triton` 模块。先确认运行时模块来自 Ascend Triton：

```bash
$PY - <<'PY'
import triton
import triton.language as tl
print("triton module", triton.__version__)
print("triton file", triton.__file__)
PY
$PIP show triton-ascend
```

如果本地开发环境要求严格通过 `pip check`，可以把 `xgrammar` metadata 冲突记录为已知的非运行时问题，或添加一个小的本地 metadata shim 表示 `triton==<triton-ascend-version>`，但不要安装普通 Triton 文件。最终环境总结中记录这个本地 metadata shim。

## torchair 需要 pkg_resources

`torch_npu.dynamo` 提供内部 `torchair` 包。当前 torchair 代码仍可能 import `pkg_resources`；`setuptools>=81` 不再提供它。如果 smoke test 失败并出现：

```text
ModuleNotFoundError: No module named 'pkg_resources'
torch_npu.dynamo._TorchairImportError
```

在开发环境中把 setuptools pin 到 81 以下：

```bash
$PIP install -i https://mirrors.aliyun.com/pypi/simple/ 'setuptools<81'
```

然后重新运行 `pip check` 和 smoke test。除非官方矩阵明确要求，不要安装无关的外部 `torchair` 包。

## source CANN 后 pip check 报告 vendor metadata

如果在 `source /usr/local/Ascend/ascend-toolkit/set_env.sh` 后运行 `pip check`，CANN vendor 包会进入 `sys.path`。部分 CANN 包可能把标准库模块声明为安装依赖，从而产生类似误报：

```text
op-compile-tool ... requires getopt, which is not installed.
op-compile-tool ... requires inspect, which is not installed.
op-compile-tool ... requires multiprocessing, which is not installed.
```

在 source Ascend 环境之前运行 Python 包依赖检查：

```bash
/root/vllm_dev/.venv/bin/python -m pip check
```

source Ascend 环境用于运行时 import 和 smoke test，不用于判断普通虚拟环境的依赖解析状态。

## uv Index 策略

多个 index 同时存在时，uv 可能优先选择第一个 index 的包。使用阿里源作为主 index，把 PyTorch CPU / Ascend index 作为 extra index。必要时：

```bash
uv pip install --python /root/vllm_dev/.venv/bin/python \
  --index-url https://mirrors.aliyun.com/pypi/simple/ \
  --extra-index-url https://download.pytorch.org/whl/cpu/ \
  --extra-index-url https://mirrors.huaweicloud.com/ascend/repos/pypi \
  --index-strategy unsafe-best-match \
  -c /root/vllm_dev/vllm-ascend-constraints.txt \
  -v -e /root/vllm_dev/vllm-ascend
```

## Editable vLLM 的 InvalidVersion

如果 editable/dev vLLM 版本解析失败，显式设置匹配版本：

```bash
export VLLM_VERSION=<matched-vllm-version>
```

然后重新安装受影响的 editable package。

## 编译失败

检查：

- `gcc`/`g++` 支持 C++17，且版本新于 gcc 8；
- `SOC_VERSION` 匹配目标硬件；
- CANN 和 NNAL 匹配矩阵；
- `torch` 和 `torch-npu` 版本匹配；
- `git submodule update --init --recursive` 已完成；
- 构建前已 source Ascend 环境脚本。

有用的日志搜索：

```bash
rg -n "error:|Error|FAILED|failed|No such|undefined reference|Traceback|fatal|CMake Error|CPack Error" /root/vllm_dev/*.log /root/vllm_dev/vllm-ascend -g '*.log'
```

## Import 或运行时失败

- 先运行 `scripts/verify_compilation.sh`，区分编译产物缺失和动态库路径问题。
- 使用 `scripts/setup_ld_library_path.sh` 输出的临时 `LD_LIBRARY_PATH`。
- 不要在源码父目录 `/root/vllm_dev` 下运行 smoke test；子目录 `vllm/` 会遮蔽 editable 安装的 `vllm` 包，导致 `ImportError: cannot import name 'LLM' from 'vllm'`。应在 `/root` 或其他中立目录运行。
- 确认 Python 外的 `npu-smi info` 正常。
- 如果在容器中运行，确认 NPU 设备、`/usr/local/Ascend/driver` 和必要 Ascend 库已挂载。

## 缺少自定义 ACLNN 符号

如果 smoke test 或直接 custom op 调用失败并出现：

```text
aclnnAddRmsNormBias or aclnnAddRmsNormBiasGetWorkspaceSize not in libopapi.so
```

不要先重装 Python 包。检查 vLLM Ascend 的 custom op API 库是否在运行时可见：

```bash
eval "$(/root/.codex/skills/vllm-ascend-setup/scripts/setup_ld_library_path.sh /root/vllm_dev/vllm-ascend --python /root/vllm_dev/.venv/bin/python --print-export)"
echo "$LD_LIBRARY_PATH" | tr ':' '\n' | rg 'op_api/lib'
echo "$ASCEND_CUSTOM_OPP_PATH" | tr ':' '\n' | rg 'vllm-ascend$'
nm -D /root/vllm_dev/vllm-ascend/vllm_ascend/_cann_ops_custom/vendors/vllm-ascend/op_api/lib/libcust_opapi.so | rg 'aclnnAddRmsNormBias'
```

自定义 ACLNN 符号位于 `libcust_opapi.so`，不在 toolkit 的 `libopapi.so`。运行时必须能 `dlopen("libcust_opapi.so")`；否则 adapter 会回退到 toolkit `libopapi.so`，并报告符号缺失。

## NPU 不可见

先修复驱动或容器运行时，再调试 Python 包。部分步骤可以在 CPU-only 构建下继续，但 smoke test 需要可见 NPU 设备。

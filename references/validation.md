# 验证

editable 安装完成后，或诊断一个声称已安装完成的环境时，使用本参考。

## 基础包检查

运行时 import 检查前，必须先 source Ascend 环境：

```bash
source /usr/local/Ascend/ascend-toolkit/set_env.sh
source /usr/local/Ascend/nnal/atb/set_env.sh 2>/dev/null || true
export SOC_VERSION=ascend910b1
export TASK_QUEUE_ENABLE=1
export OMP_NUM_THREADS=1
```

检查版本：

```bash
$PY - <<'PY'
import torch
import torch_npu
import vllm
import vllm_ascend
print("torch", torch.__version__)
print("torch_npu", torch_npu.__version__)
print("vllm", getattr(vllm, "__version__", "unknown"))
print("vllm_ascend", getattr(vllm_ascend, "__version__", "unknown"))
PY
```

检查 resolver 状态：

```bash
# 在 source Ascend set_env.sh 之前，在虚拟环境里运行。
# CANN 会把 vendor site-packages 加进 sys.path，部分 vendor metadata
# 会让 pip check 对标准库模块产生误报。
$PIP check
```

## 编译产物

使用技能自带脚本：

```bash
/root/.codex/skills/vllm-ascend-setup/scripts/verify_compilation.sh /root/vllm_dev/vllm-ascend
```

如果缺少必要 `.so`，先检查构建日志再重试。不要用 import 成功来掩盖编译产物缺失。

## 动态库路径

只对当前 shell 生效：

```bash
eval "$(/root/.codex/skills/vllm-ascend-setup/scripts/setup_ld_library_path.sh /root/vllm_dev/vllm-ascend --python /root/vllm_dev/.venv/bin/python --print-export)"
```

脚本必须同时包含：

- `LD_LIBRARY_PATH` 中的 `vllm_ascend/_cann_ops_custom/vendors/vllm-ascend/op_api/lib`；
- `ASCEND_CUSTOM_OPP_PATH` 中的 `vllm_ascend/_cann_ops_custom/vendors/vllm-ascend`。

如果缺少 custom `op_api/lib`，CANN 只能加载 toolkit 自带的 `libopapi.so`，会找不到 vLLM Ascend 自定义 ACLNN 符号。

只有用户明确要求时才持久化：

```bash
/root/.codex/skills/vllm-ascend-setup/scripts/setup_ld_library_path.sh /root/vllm_dev/vllm-ascend --python /root/vllm_dev/.venv/bin/python --persist
```

## Smoke Test

smoke test 会下载或读取模型，所以先检查网络和磁盘。默认使用小模型：

```bash
# 在 /root/vllm_dev 外运行，避免仓库目录 vllm/
# 遮蔽 editable 安装的 vllm 包。
cd /root
$PY /root/.codex/skills/vllm-ascend-setup/scripts/test_vllm_ascend.py --model Qwen/Qwen3-0.6B
```

如果 Hugging Face 不可用，使用 ModelScope：

```bash
export VLLM_USE_MODELSCOPE=True
$PIP install -i https://mirrors.aliyun.com/pypi/simple/ modelscope
cd /root
$PY /root/.codex/skills/vllm-ascend-setup/scripts/test_vllm_ascend.py --model Qwen/Qwen3-0.6B
```

也可以使用本地模型路径：

```bash
$PY /root/.codex/skills/vllm-ascend-setup/scripts/test_vllm_ascend.py --model /path/to/model
```

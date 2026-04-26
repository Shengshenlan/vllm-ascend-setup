# 版本矩阵与兼容性

在选择分支、commit、Python 版本、CANN 版本、PyTorch/torch-npu 版本或 Triton Ascend 版本时，使用本参考。

## 官方来源

安装前必须读取当前上游数据：

```bash
curl -sL https://docs.vllm.ai/projects/ascend/en/latest/_sources/community/versioning_policy.md
curl -sL https://raw.githubusercontent.com/vllm-project/vllm-ascend/main/docs/source/conf.py
```

如果仓库已经 clone，优先读取本次要安装的目标 checkout：

```bash
sed -n '1,220p' /path/to/vllm-ascend/docs/source/conf.py
```

有用的官方安装文档：

```bash
curl -sL https://docs.vllm.ai/projects/ascend/en/latest/_sources/installation.md
curl -sL https://docs.vllm.ai/projects/ascend/zh-cn/latest/installation.html
```

## main 分支规则

对于 `vllm-ascend=main`，解析 `docs/source/conf.py` 的 `myst_substitutions`，并使用 `main_*` 字段：

- `main_vllm_commit`
- `main_vllm_tag`
- `main_python_version`
- `main_cann_version`
- `main_pytorch_torch_npu_version`
- `main_triton_ascend_version`

如果 `main_vllm_commit` 和 `main_vllm_tag` 同时存在，checkout `main_vllm_commit`。把 `main_vllm_tag` 当作便于阅读的版本标签，不要把它当成精确 commit 的替代品。tag 可能落后于兼容性 commit，缺少当前 vLLM Ascend patch 需要的模块。

不要让这些字段覆盖 `main_*`：

- `vllm_version`
- `vllm_ascend_version`
- `pip_vllm_*`
- `cann_image_tag`
- 容器镜像 tag
- 只用于 release 的文档片段

`installation.md` 的依赖说明可能描述的是 release、镜像或通用安装路径。如果它们和 `conf.py` 的 main 字段不同，在没有明确解释前，优先级低于 `conf.py`。

## Release 或 Tag 规则

如果用户指定了 vLLM Ascend 的 release/tag，使用 release 兼容性矩阵，而不是 main 行。保持 vLLM 和 vLLM Ascend 是匹配的一组。不要随意混用 vLLM main 与任意 vLLM Ascend main/release。

安装前记录所选版本组：

```text
vllm-ascend=<branch/tag/commit>
vllm=<exact-commit-preferred, tag-label-if-provided>
python=<required-range>
cann=<required-version>
torch=<required-version>
torch_npu=<required-version>
triton_ascend=<required-version-if-any>
```

## CANN 与 NNAL Gate

选择版本组后，立即检查本机 CANN/NNAL：

```bash
cat /usr/local/Ascend/ascend-toolkit/latest/compiler/version.info 2>/dev/null || true
cat /usr/local/Ascend/driver/version.info 2>/dev/null || true
find /usr/local/Ascend/nnal -maxdepth 4 -name version.info -print -exec cat {} \; 2>/dev/null || true
```

规则：

- 如果本机 CANN/NNAL 与目标版本组匹配，继续。
- 如果本机 CANN/NNAL 不匹配，在安装 Python 包之前停止。
- 给用户两个可执行路径：
  - 升级 CANN/NNAL 到目标版本组，并保持当前选择的分支；
  - 切换到版本矩阵匹配当前 CANN/NNAL 的 vLLM Ascend release/tag。
- 只有用户明确接受非官方组合时，才在不匹配的情况下继续。此时要标记运行验证预计可能失败。

## 冲突优先级

当不同来源的信息看起来冲突时，先判断字段类型，再决定采用哪个：

1. `conf.py`/versioning matrix 的兼容性版本组。
2. 同一分支 Dockerfile 的构建默认值。
3. vLLM Ascend `pyproject.toml` 或 requirements 的运行时约束。
4. vLLM 源码包 requirements。
5. 通用安装页面正文。

vLLM `pyproject.toml [build-system].requires` 中的 torch 是 build isolation 依赖，不是最终 Ascend 环境的运行时 torch。对于 `VLLM_TARGET_DEVICE=empty`，目标运行时 torch 应来自 vLLM Ascend 版本组。

## 当前 main 示例

上次在本机验证时，`vllm-ascend` main 文档映射为：

```text
vLLM Ascend: main
vLLM: 6f786f2c506cb07f4566771fdc62e640e2c4a176, v0.19.0
Python: >=3.10,<3.12
CANN: 8.5.0
PyTorch/torch-npu: 2.9.0 / 2.9.0
Triton Ascend: 3.2.0
```

这只是缓存示例。未来安装前仍要重新读取当前 `conf.py`，因为 main 会变化。

在这个示例里，应 checkout `6f786f2c506cb07f4566771fdc62e640e2c4a176`，不要只 checkout `v0.19.0`。

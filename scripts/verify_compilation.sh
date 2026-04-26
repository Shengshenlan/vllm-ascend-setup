#!/bin/bash
# 验证 vllm-ascend 源码构建产物是否存在

set -euo pipefail

VLLM_ASCEND_DIR="${1:-.}"

echo "=========================================="
echo "验证 vllm-ascend 编译状态"
echo "目录: ${VLLM_ASCEND_DIR}"
echo "=========================================="

cd "${VLLM_ASCEND_DIR}"

# Editable wheel 构建可能不会保留顶层 build/，所以顶层 build 只做信息检查。
if [ -d "build" ]; then
    echo "[OK] 顶层 build/ 目录存在"
    ls -la build/ | head -20
else
    echo "[INFO] 顶层 build/ 目录不存在；editable 构建中这是允许的"
fi

echo ""
echo "检查编译产物..."

KERNEL_SO="vllm_ascend/libvllm_ascend_kernels.so"
if [ -f "${KERNEL_SO}" ]; then
    echo "[OK] ${KERNEL_SO} 存在 ($(du -h "${KERNEL_SO}" | awk '{print $1}'))"
elif [ -f "vllm_ascend/lib64/libvllm_ascend_kernels.so" ]; then
    KERNEL_SO="vllm_ascend/lib64/libvllm_ascend_kernels.so"
    echo "[OK] ${KERNEL_SO} 存在 ($(du -h "${KERNEL_SO}" | awk '{print $1}'))"
else
    echo "[FAIL] vllm_ascend/libvllm_ascend_kernels.so 不存在"
    exit 1
fi

PYTHON_SO=$(find vllm_ascend -maxdepth 1 -type f -name 'vllm_ascend_C*.so' -print | head -1)
if [ -n "${PYTHON_SO}" ] && [ -f "${PYTHON_SO}" ]; then
    echo "[OK] ${PYTHON_SO} 存在 ($(du -h "${PYTHON_SO}" | awk '{print $1}'))"
else
    echo "[FAIL] Python 扩展模块 vllm_ascend/vllm_ascend_C*.so 不存在"
    exit 1
fi

if [ -d "vllm_ascend/_cann_ops_custom" ]; then
    echo "[OK] vllm_ascend/_cann_ops_custom 存在"
else
    echo "[WARN] vllm_ascend/_cann_ops_custom 不存在；如使用自定义 CANN 算子需检查构建日志"
fi

if [ -d "csrc/build" ]; then
    CSRC_SO_COUNT=$(find csrc/build -type f -name '*.so' | wc -l)
    echo "[OK] csrc/build 存在，包含 ${CSRC_SO_COUNT} 个 .so 文件"
else
    echo "[INFO] csrc/build 不存在；只要包内 .so 已生成，editable 安装仍可用"
fi

echo ""
echo "=========================================="
echo "编译验证通过"
echo "=========================================="

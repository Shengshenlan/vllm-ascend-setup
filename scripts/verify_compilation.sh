#!/bin/bash
# 验证 vllm-ascend 编译是否成功

set -e

VLLM_ASCEND_DIR="${1:-.}"

echo "=========================================="
echo "验证 vllm-ascend 编译状态"
echo "目录: ${VLLM_ASCEND_DIR}"
echo "=========================================="

cd "${VLLM_ASCEND_DIR}"

# 检查 build 目录
if [ -d "build" ]; then
    echo "✅ build 目录存在"
    echo "   内容:"
    ls -la build/ | head -20
else
    echo "❌ build 目录不存在"
    exit 1
fi

# 检查关键 .so 文件
echo ""
echo "检查编译产物..."

KERNEL_SO="vllm_ascend/libvllm_ascend_kernels.so"
if [ -f "${KERNEL_SO}" ]; then
    echo "✅ ${KERNEL_SO} 存在 ($(du -h ${KERNEL_SO} | awk '{print $1}'))"
else
    echo "❌ ${KERNEL_SO} 不存在"
    exit 1
fi

PYTHON_SO=$(ls vllm_ascend/vllm_ascend_C*.so 2>/dev/null | head -1)
if [ -n "${PYTHON_SO}" ] && [ -f "${PYTHON_SO}" ]; then
    echo "✅ ${PYTHON_SO} 存在 ($(du -h ${PYTHON_SO} | awk '{print $1}'))"
else
    echo "❌ Python 扩展模块不存在"
    exit 1
fi

# 检查 build/lib.linux-* 目录
BUILD_LIB=$(ls -d build/lib.linux-* 2>/dev/null | head -1)
if [ -n "${BUILD_LIB}" ] && [ -d "${BUILD_LIB}" ]; then
    echo "✅ ${BUILD_LIB} 目录存在"
else
    echo "❌ build/lib.linux-* 目录不存在"
    exit 1
fi

echo ""
echo "=========================================="
echo "🎉 编译验证通过！"
echo "=========================================="

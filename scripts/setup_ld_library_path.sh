#!/bin/bash
# 配置 vllm-ascend 的 LD_LIBRARY_PATH

VLLM_ASCEND_DIR="${1:-.}"
PERSIST="${2:-false}"

cd "${VLLM_ASCEND_DIR}"
VLLM_ASCEND_PATH=$(pwd)

echo "=========================================="
echo "配置 LD_LIBRARY_PATH"
echo "vllm-ascend 路径: ${VLLM_ASCEND_PATH}"
echo "=========================================="

# 设置环境变量
export LD_LIBRARY_PATH=${VLLM_ASCEND_PATH}/vllm_ascend:${VLLM_ASCEND_PATH}/vllm_ascend/lib64:${LD_LIBRARY_PATH}

echo ""
echo "✅ LD_LIBRARY_PATH 已设置"
echo "LD_LIBRARY_PATH=${LD_LIBRARY_PATH}"

# 如果需要持久化
if [ "${PERSIST}" = "true" ] || [ "${PERSIST}" = "persist" ]; then
    SHELL_RC=""
    if [ -f ~/.bashrc ]; then
        SHELL_RC=~/.bashrc
    elif [ -f ~/.zshrc ]; then
        SHELL_RC=~/.zshrc
    fi

    if [ -n "${SHELL_RC}" ]; then
        # 检查是否已经添加过
        if ! grep -q "vllm-ascend.*LD_LIBRARY_PATH" "${SHELL_RC}"; then
            echo "" >> "${SHELL_RC}"
            echo "# vllm-ascend library path" >> "${SHELL_RC}"
            echo "export LD_LIBRARY_PATH=${VLLM_ASCEND_PATH}/vllm_ascend:${VLLM_ASCEND_PATH}/vllm_ascend/lib64:\${LD_LIBRARY_PATH}" >> "${SHELL_RC}"
            echo ""
            echo "✅ 已添加到 ${SHELL_RC}"
            echo "   请运行 'source ${SHELL_RC}' 使配置立即生效"
        else
            echo ""
            echo "ℹ️ ${SHELL_RC} 中已存在 vllm-ascend 配置"
        fi
    else
        echo ""
        echo "⚠️ 未找到 shell 配置文件 (~/.bashrc 或 ~/.zshrc)"
    fi
fi

echo ""
echo "=========================================="
echo "使用提示："
echo "  当前终端会话已生效"
echo "  如需永久生效，请再次运行: ./setup_ld_library_path.sh <path> persist"
echo "=========================================="

# 输出生效的命令供用户 eval
echo ""
echo "复制以下命令使配置在当前 shell 生效："
echo "export LD_LIBRARY_PATH=${VLLM_ASCEND_PATH}/vllm_ascend:${VLLM_ASCEND_PATH}/vllm_ascend/lib64:\${LD_LIBRARY_PATH}"

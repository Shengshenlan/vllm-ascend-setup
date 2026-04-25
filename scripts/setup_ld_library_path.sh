#!/usr/bin/env bash
# Configure vllm-ascend LD_LIBRARY_PATH.

set -euo pipefail

VLLM_ASCEND_DIR="."
PERSIST="false"
RC_FILE=""
PRINT_EXPORT="false"

usage() {
    echo "Usage: $0 [vllm-ascend-dir] [--print-export] [--persist|persist] [--rc-file PATH]"
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --persist|persist|true)
            PERSIST="true"
            shift
            ;;
        --print-export)
            PRINT_EXPORT="true"
            shift
            ;;
        --rc-file)
            RC_FILE="${2:-}"
            if [ -z "${RC_FILE}" ]; then
                echo "Missing value for --rc-file" >&2
                exit 2
            fi
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            VLLM_ASCEND_DIR="$1"
            shift
            ;;
    esac
done

if [ ! -d "${VLLM_ASCEND_DIR}" ]; then
    echo "Directory not found: ${VLLM_ASCEND_DIR}" >&2
    exit 1
fi

cd "${VLLM_ASCEND_DIR}"
VLLM_ASCEND_PATH="$(pwd -P)"

if [ ! -d "${VLLM_ASCEND_PATH}/vllm_ascend" ]; then
    echo "Expected vllm_ascend/ under ${VLLM_ASCEND_PATH}" >&2
    exit 1
fi

LIB_PATH="${VLLM_ASCEND_PATH}/vllm_ascend:${VLLM_ASCEND_PATH}/vllm_ascend/lib64"
EXPORT_CMD="export LD_LIBRARY_PATH=${LIB_PATH}:\${LD_LIBRARY_PATH:-}"

if [ "${PRINT_EXPORT}" = "true" ]; then
    echo "${EXPORT_CMD}"
    exit 0
fi

export LD_LIBRARY_PATH="${LIB_PATH}:${LD_LIBRARY_PATH:-}"

echo "vllm-ascend path: ${VLLM_ASCEND_PATH}"
echo "LD_LIBRARY_PATH for this process:"
echo "${LD_LIBRARY_PATH}"
echo
echo "Run this in your current shell if you executed the script instead of sourcing it:"
echo "${EXPORT_CMD}"

if [ "${PERSIST}" != "true" ]; then
    exit 0
fi

if [ -z "${RC_FILE}" ]; then
    if [ -f "${HOME}/.bashrc" ]; then
        RC_FILE="${HOME}/.bashrc"
    elif [ -f "${HOME}/.zshrc" ]; then
        RC_FILE="${HOME}/.zshrc"
    else
        echo "No shell rc file found. Pass --rc-file PATH to persist manually." >&2
        exit 1
    fi
fi

MARKER_BEGIN="# >>> vllm-ascend LD_LIBRARY_PATH >>>"
MARKER_END="# <<< vllm-ascend LD_LIBRARY_PATH <<<"
TMP_FILE="$(mktemp)"

if [ -f "${RC_FILE}" ]; then
    awk -v begin="${MARKER_BEGIN}" -v end="${MARKER_END}" '
        $0 == begin {skip = 1; next}
        $0 == end {skip = 0; next}
        skip != 1 {print}
    ' "${RC_FILE}" > "${TMP_FILE}"
else
    : > "${TMP_FILE}"
fi

{
    cat "${TMP_FILE}"
    echo
    echo "${MARKER_BEGIN}"
    echo "${EXPORT_CMD}"
    echo "${MARKER_END}"
} > "${RC_FILE}"

rm -f "${TMP_FILE}"
echo
echo "Persisted LD_LIBRARY_PATH block to ${RC_FILE}"

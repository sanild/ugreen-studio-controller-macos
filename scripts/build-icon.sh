#!/bin/zsh

set -euo pipefail

SCRIPT_DIR="${0:A:h}"
TOOL_ROOT="${SCRIPT_DIR:h}"
MASTER_ICON="${TOOL_ROOT}/Assets/AppIcon-master.png"
OUTPUT_ICON="${TOOL_ROOT}/Assets/AppIcon.icns"
ICON_WORK_DIR="$(mktemp -d)"
ICONSET="${ICON_WORK_DIR}/AppIcon.iconset"
trap 'rm -rf "${ICON_WORK_DIR}"' EXIT

mkdir -p "${ICONSET}"

for size in 16 32 128 256 512; do
    sips -z "${size}" "${size}" "${MASTER_ICON}" \
        --out "${ICONSET}/icon_${size}x${size}.png" >/dev/null

    double_size=$((size * 2))
    sips -z "${double_size}" "${double_size}" "${MASTER_ICON}" \
        --out "${ICONSET}/icon_${size}x${size}@2x.png" >/dev/null
done

iconutil --convert icns --output "${OUTPUT_ICON}" "${ICONSET}"
echo "Built ${OUTPUT_ICON}"

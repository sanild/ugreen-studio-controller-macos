#!/bin/zsh

set -euo pipefail

SCRIPT_DIR="${0:A:h}"
TOOL_ROOT="${SCRIPT_DIR:h}"
APP_OUTPUT="${UGREEN_APP_OUTPUT:-${TOOL_ROOT}/build}"
APP_PATH="${APP_OUTPUT}/Studio Controller.app"

"${SCRIPT_DIR}/build-icon.sh"
swift build --package-path "${TOOL_ROOT}" -c release
BIN_PATH="$(swift build --package-path "${TOOL_ROOT}" -c release --show-bin-path)"

mkdir -p "${APP_PATH}/Contents/MacOS"
mkdir -p "${APP_PATH}/Contents/Resources"
cp "${BIN_PATH}/StudioController" "${APP_PATH}/Contents/MacOS/StudioController"
cp "${TOOL_ROOT}/AppInfo.plist" "${APP_PATH}/Contents/Info.plist"
cp "${TOOL_ROOT}/Assets/AppIcon.icns" "${APP_PATH}/Contents/Resources/AppIcon.icns"
chmod +x "${APP_PATH}/Contents/MacOS/StudioController"
codesign \
  --force \
  --sign - \
  --requirements '=designated => identifier "dev.studiocontroller.mac"' \
  "${APP_PATH}"

echo "Built ${APP_PATH}"

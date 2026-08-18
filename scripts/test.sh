#!/bin/zsh

set -euo pipefail

SCRIPT_DIR="${0:A:h}"
TOOL_ROOT="${SCRIPT_DIR:h}"
TEST_DIR="$(mktemp -d)"
TEST_BINARY="${TEST_DIR}/studio-controller-protocol-tests"
trap 'rm -rf "${TEST_DIR}"' EXIT

swiftc \
    "${TOOL_ROOT}/Sources/StudioController/HeadphoneModels.swift" \
    "${TOOL_ROOT}/Sources/StudioController/UGREENProtocol.swift" \
    "${TOOL_ROOT}/Tests/ProtocolTestRunner/main.swift" \
    -o "${TEST_BINARY}"

"${TEST_BINARY}"

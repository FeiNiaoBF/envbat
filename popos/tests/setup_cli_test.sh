#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
output=$(bash "$SCRIPT_DIR/../setup.sh" --help)

grep -q -- "--repair" <<< "$output"
grep -q -- "--reconfigure" <<< "$output"
grep -q 'stage_optional "mise"' "$SCRIPT_DIR/../setup.sh"
grep -q 'popos_mise_is_available' "$SCRIPT_DIR/../setup.sh"
if grep -qE 'INSTALL_NVM_NODE|INSTALL_PYENV|INSTALL_RUSTUP|popos_install_nvm_node|popos_install_pyenv|popos_install_rustup' "$SCRIPT_DIR/../setup.sh"; then
    echo "FAIL: setup still references legacy runtime managers" >&2
    exit 1
fi

echo "PASS: setup CLI"

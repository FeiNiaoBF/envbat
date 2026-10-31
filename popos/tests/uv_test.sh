#!/usr/bin/env bash
set -euo pipefail

TEST_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=popos/lang.sh
source "$TEST_SCRIPT_DIR/../lang.sh"

fail() { :; }
warn() { :; }
ok() { :; }

fail_test() {
    echo "FAIL: $*" >&2
    exit 1
}

test_root=$(mktemp -d)
trap 'rm -rf -- "$test_root"' EXIT
HOME="$test_root/home"
INSTALL_BASE="$test_root/data"
PATH="$INSTALL_BASE/tools/bin:$PATH"
mkdir -p "$HOME"

curl() {
    cat <<'INSTALLER'
[ "${UV_NO_MODIFY_PATH:-}" = 1 ] || exit 41
[ -n "${UV_INSTALL_DIR:-}" ] || exit 42
mkdir -p "$UV_INSTALL_DIR"
printf '#!/usr/bin/env sh\necho "uv 1.0.0"\n' > "$UV_INSTALL_DIR/uv"
printf '#!/usr/bin/env sh\necho "uvx 1.0.0"\n' > "$UV_INSTALL_DIR/uvx"
chmod +x "$UV_INSTALL_DIR/uv" "$UV_INSTALL_DIR/uvx"
INSTALLER
}

popos_install_uv >/dev/null || fail_test "valid installer flow failed"
[ -x "$INSTALL_BASE/tools/bin/uv" ] || fail_test "uv was not installed under INSTALL_BASE"
[ -x "$INSTALL_BASE/tools/bin/uvx" ] || fail_test "uvx was not installed"
curl() { return 99; }
popos_install_uv >/dev/null || fail_test "existing managed uv was not idempotent"

INSTALL_BASE="$test_root/failure-data"
PATH="$INSTALL_BASE/tools/bin:$PATH"
curl() { printf 'exit 0\n'; }
if popos_install_uv >/dev/null 2>&1; then
    fail_test "missing uv binary returned success"
fi

echo "PASS: uv installer"

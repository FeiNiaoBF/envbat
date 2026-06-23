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
mkdir -p "$HOME"

curl() {
    printf '[ "$MISE_INSTALL_PATH" = %q ] || exit 41\n' "$INSTALL_BASE/tools/bin/mise"
    cat <<'INSTALLER'
mkdir -p "$(dirname "$MISE_INSTALL_PATH")"
cat > "$MISE_INSTALL_PATH" <<'MISE'
#!/usr/bin/env sh
case "$1" in
    --version) echo "mise 1.0.0" ;;
    *) exit 0 ;;
esac
MISE
chmod +x "$MISE_INSTALL_PATH"
INSTALLER
}

popos_install_mise >/dev/null || fail_test "valid mise installer flow failed"
[ -x "$INSTALL_BASE/tools/bin/mise" ] || fail_test "mise binary missing"
[ "$MISE_DATA_DIR" = "$INSTALL_BASE/tools/mise" ] || fail_test "MISE_DATA_DIR mismatch"
[ "$MISE_CONFIG_DIR" = "$HOME/.config/mise" ] || fail_test "MISE_CONFIG_DIR mismatch"
[ "$MISE_CACHE_DIR" = "$INSTALL_BASE/cache/mise" ] || fail_test "MISE_CACHE_DIR mismatch"

curl() { printf 'exit 0\n'; }
INSTALL_BASE="$test_root/failure-data"
if popos_install_mise >/dev/null 2>&1; then
    fail_test "missing mise binary returned success"
fi

echo "PASS: mise installer"

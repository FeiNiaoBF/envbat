#!/usr/bin/env bash
set -euo pipefail

TEST_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=popos/lang.sh
source "$TEST_SCRIPT_DIR/../lang.sh"

fail() { :; }
ok() { :; }

fail_test() {
    echo "FAIL: $*" >&2
    exit 1
}

test_root=$(mktemp -d)
trap 'rm -rf -- "$test_root"' EXIT
HOME="$test_root/home"
INSTALL_BASE="$test_root/data"
MISE_LOG="$test_root/mise.log"
export MISE_LOG
mkdir -p "$HOME" "$INSTALL_BASE/tools/bin"

cat > "$INSTALL_BASE/tools/bin/mise" <<'MISE'
#!/usr/bin/env sh
printf '%s\n' "$*" >> "$MISE_LOG"
case "$1" in
    --version) echo 'mise 1.0.0'; exit 0 ;;
    use|where|current|unuse) exit 0 ;;
    *) exit 1 ;;
esac
MISE
chmod +x "$INSTALL_BASE/tools/bin/mise"

popos_mise_is_available || fail_test "existing managed mise was not detected"

popos_mise_use go latest || fail_test "Go mise selection failed"
popos_mise_use node lts || fail_test "Node mise selection failed"
popos_mise_use python latest || fail_test "Python mise selection failed"
popos_mise_use rust stable || fail_test "Rust mise selection failed"
popos_mise_use java temurin-17 || fail_test "Java mise selection failed"
popos_mise_unuse node || fail_test "Node mise unuse failed"

for expected in \
    'use --global go@latest' \
    'use --global node@lts' \
    'use --global python@latest' \
    'use --global rust@stable' \
    'use --global java@temurin-17' \
    'unuse --global node'; do
    grep -qxF "$expected" "$MISE_LOG" || fail_test "mise command missing: $expected"
done

echo "PASS: mise runtime selection"

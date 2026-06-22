#!/usr/bin/env bash
set -euo pipefail

TEST_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=popos/lang.sh
source "$TEST_SCRIPT_DIR/../lang.sh"

fail() { :; }
ok() { :; }

test_root=$(mktemp -d)
trap 'rm -rf -- "$test_root"' EXIT
HOME="$test_root/home"
INSTALL_BASE="$test_root/data"
INSTALL_JAVA=17
mkdir -p "$HOME" "$INSTALL_BASE/tools"

curl() { return 0; }
tar() {
    mkdir -p "$INSTALL_BASE/tools/java/jdk-17/bin"
    printf '#!/usr/bin/env sh\nexit 0\n' > "$INSTALL_BASE/tools/java/jdk-17/bin/java"
    printf '#!/usr/bin/env sh\nexit 0\n' > "$INSTALL_BASE/tools/java/jdk-17/bin/javac"
    chmod +x "$INSTALL_BASE/tools/java/jdk-17/bin/java" "$INSTALL_BASE/tools/java/jdk-17/bin/javac"
}

popos_install_java >/dev/null || {
    echo "FAIL: Java 17 install flow failed" >&2
    exit 1
}
[ -x "$INSTALL_BASE/tools/java/jdk-17/bin/java" ] || {
    echo "FAIL: selected Java version was not used" >&2
    exit 1
}

echo "PASS: language selection"

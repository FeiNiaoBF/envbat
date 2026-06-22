#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=popos/directories.sh
source "$SCRIPT_DIR/../directories.sh"

fail_test() {
    echo "FAIL: $*" >&2
    exit 1
}
fail() { :; }

test_home=$(mktemp -d)
trap 'rm -rf -- "$test_home"' EXIT
HOME="$test_home"
INSTALL_BASE="$test_home/data"

sudo() {
    if [ "${1:-}" = mkdir ]; then
        return 9
    fi
    command "$@"
}

if popos_create_dirs >/dev/null 2>&1; then
    fail_test "directory stage hid mkdir failure"
fi

echo "PASS: module contract"

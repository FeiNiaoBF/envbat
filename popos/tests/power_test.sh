#!/usr/bin/env bash
set -euo pipefail

TEST_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=popos/popos-power.sh
source "$TEST_SCRIPT_DIR/../popos-power.sh"

gsettings() { return 1; }
if gset schema key value success failure >/dev/null 2>&1; then
    echo "FAIL: gsettings failure was reported as success" >&2
    exit 1
fi

[ "$(seconds_to_display 'uint32 600')" = "10分钟" ] || {
    echo "FAIL: uint32 duration was parsed incorrectly" >&2
    exit 1
}

echo "PASS: power failure propagation"

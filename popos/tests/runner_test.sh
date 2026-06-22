#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=popos/runner.sh
source "$SCRIPT_DIR/../runner.sh"

fail_test() {
    echo "FAIL: $*" >&2
    exit 1
}

pass_stage() { return 0; }
fail_stage() { return 7; }

stage_required "required pass" pass_stage
stage_optional "optional fail" fail_stage

[ "${STAGE_STATUSES[0]}" = "OK" ] || fail_test "required success not recorded"
[ "${STAGE_STATUSES[1]}" = "WARN" ] || fail_test "optional failure not recorded"
stage_has_warnings || fail_test "warning state not detected"

output=$(stage_finish "test flow")
grep -q "COMPLETED WITH WARNINGS" <<< "$output" || fail_test "warning outcome missing"

STAGE_NAMES=()
STAGE_STATUSES=()
STAGE_REQUIRED=()
STAGE_MESSAGES=()
stage_required "required fail" fail_stage || true

if stage_finish "test flow" >/dev/null; then
    fail_test "failed required stage returned success"
fi

echo "PASS: runner"

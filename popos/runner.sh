#!/usr/bin/env bash
# === Stage Runner ===
# Records required/optional stage results and prints a final summary.

STAGE_NAMES=()
STAGE_STATUSES=()
STAGE_REQUIRED=()
STAGE_MESSAGES=()

stage_record() {
    local name="$1" status="$2" required="$3" message="${4:-}"
    STAGE_NAMES+=("$name")
    STAGE_STATUSES+=("$status")
    STAGE_REQUIRED+=("$required")
    STAGE_MESSAGES+=("$message")
}

stage_required() {
    local name="$1"
    shift
    echo ""
    echo "== $name =="
    local rc
    if "$@"; then
        stage_record "$name" "OK" "required" ""
        return 0
    else
        rc=$?
        stage_record "$name" "FAIL" "required" "exit $rc"
        return "$rc"
    fi
}

stage_optional() {
    local name="$1"
    shift
    echo ""
    echo "== $name =="
    local rc
    if "$@"; then
        stage_record "$name" "OK" "optional" ""
    else
        rc=$?
        stage_record "$name" "WARN" "optional" "exit $rc"
    fi
    return 0
}

stage_skip() {
    local name="$1" message="${2:-skipped}"
    echo ""
    echo "== $name =="
    echo "  [SKIP] $message"
    stage_record "$name" "SKIP" "optional" "$message"
}

stage_has_failures() {
    local i
    for i in "${!STAGE_STATUSES[@]}"; do
        if [ "${STAGE_STATUSES[$i]}" = "FAIL" ]; then
            return 0
        fi
    done
    return 1
}

stage_has_warnings() {
    local status
    for status in "${STAGE_STATUSES[@]}"; do
        if [ "$status" = "WARN" ]; then
            return 0
        fi
    done
    return 1
}

stage_summary() {
    echo ""
    echo "========================================"
    echo " Stage Summary"
    echo "========================================"
    local i name status required message
    for i in "${!STAGE_NAMES[@]}"; do
        name="${STAGE_NAMES[$i]}"
        status="${STAGE_STATUSES[$i]}"
        required="${STAGE_REQUIRED[$i]}"
        message="${STAGE_MESSAGES[$i]}"
        if [ -n "$message" ]; then
            printf "  [%-4s] %-8s %s - %s\n" "$status" "$required" "$name" "$message"
        else
            printf "  [%-4s] %-8s %s\n" "$status" "$required" "$name"
        fi
    done
    echo "========================================"
}

stage_finish() {
    local flow_name="${1:-flow}"
    stage_summary
    if stage_has_failures; then
        echo "  FAILED: $flow_name"
        return 1
    fi
    if stage_has_warnings; then
        echo "  COMPLETED WITH WARNINGS: $flow_name"
        return 0
    fi
    echo "  SUCCESS: $flow_name"
}

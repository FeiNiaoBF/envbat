#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
output=$(bash "$SCRIPT_DIR/../setup.sh" --help)

grep -q -- "--repair" <<< "$output"
grep -q -- "--reconfigure" <<< "$output"

echo "PASS: setup CLI"

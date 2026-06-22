#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANIFEST_TOOL="$SCRIPT_DIR/../manifest.py"
PYTHON_BIN="${PYTHON_BIN:-python3}"

fail() {
    echo "FAIL: $*" >&2
    exit 1
}

backup_dir=$(mktemp -d)
trap 'rm -rf -- "$backup_dir"' EXIT
printf 'dotfiles' > "$backup_dir/dotfiles.tar.gz"

"$PYTHON_BIN" "$MANIFEST_TOOL" create \
    --backup-dir "$backup_dir" \
    --created-at "2026-06-22T00:00:00+08:00" \
    --host test-host --user test-user --os PopOS --install-base /data \
    --overall-status complete \
    --module dotfiles required ok dotfiles.tar.gz sensitive \
    --module packages optional skip - normal

"$PYTHON_BIN" "$MANIFEST_TOOL" validate "$backup_dir" >/dev/null || fail "valid manifest rejected"

cp "$backup_dir/manifest.json" "$backup_dir/manifest.valid.json"
"$PYTHON_BIN" -c 'import json, pathlib, sys; p=pathlib.Path(sys.argv[1]); d=json.loads(p.read_text()); d["modules"]["dotfiles"]["required"]="true"; p.write_text(json.dumps(d))' "$backup_dir/manifest.json"
if "$PYTHON_BIN" "$MANIFEST_TOOL" validate "$backup_dir" >/dev/null 2>&1; then
    fail "non-boolean required field accepted"
fi
mv "$backup_dir/manifest.valid.json" "$backup_dir/manifest.json"

tree_base="$backup_dir/install-base"
mkdir -p "$tree_base"
safe_tree_path=$("$PYTHON_BIN" -c 'from pathlib import Path; import sys; print((Path(sys.argv[1]) / "workspace").resolve())' "$tree_base")
outside_tree_path=$("$PYTHON_BIN" -c 'from pathlib import Path; import sys; print((Path(sys.argv[1]).parent / "outside").resolve())' "$tree_base")
printf '%s\n' "$safe_tree_path" > "$backup_dir/tree.txt"
"$PYTHON_BIN" "$MANIFEST_TOOL" tree-list "$tree_base" "$backup_dir/tree.txt" >/dev/null || fail "safe directory tree rejected"
printf '%s\n%s\n' "$safe_tree_path" "$outside_tree_path" > "$backup_dir/tree.txt"
if "$PYTHON_BIN" "$MANIFEST_TOOL" tree-list "$tree_base" "$backup_dir/tree.txt" >/dev/null 2>&1; then
    fail "directory tree escape accepted"
fi

printf 'tampered' >> "$backup_dir/dotfiles.tar.gz"
if "$PYTHON_BIN" "$MANIFEST_TOOL" validate "$backup_dir" >/dev/null 2>&1; then
    fail "checksum mismatch accepted"
fi

printf '{"schema_version": 1}' > "$backup_dir/manifest.json"
if "$PYTHON_BIN" "$MANIFEST_TOOL" validate "$backup_dir" >/dev/null 2>&1; then
    fail "schema v1 accepted"
fi

echo "PASS: manifest v2"

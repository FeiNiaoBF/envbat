#!/usr/bin/env bash
set -euo pipefail

TEST_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PYTHON_BIN="${PYTHON_BIN:-python3}"

fail_test() {
    echo "FAIL: $*" >&2
    exit 1
}

test_root=$(mktemp -d)
trap 'rm -rf -- "$test_root"' EXIT
test_home="$test_root/home"
backup_base="$test_root/backups"
install_base="$test_root/data"
mkdir -p "$test_home/.config/envbat" "$test_home/.config/nvim" "$test_home/.ssh"
printf 'original zshrc\n' > "$test_home/.zshrc"
printf 'ENVBAT_PROFILE_SCHEMA=2\nINSTALL_BASE=%q\n' "$install_base" > "$test_home/.config/envbat/profile.sh"
printf 'set number\n' > "$test_home/.config/nvim/init.vim"
printf 'backup key\n' > "$test_home/.ssh/id_ed25519"
chmod 600 "$test_home/.ssh/id_ed25519"

HOME="$test_home" ENVBAT_BACKUP_BASE="$backup_base" \
    PYTHON_BIN="$PYTHON_BIN" ENVBAT_TIMESTAMP=roundtrip \
    bash "$TEST_SCRIPT_DIR/../backup.sh" >/dev/null || fail_test "backup entrypoint failed"

printf 'changed zshrc\n' > "$test_home/.zshrc"
printf 'changed key\n' > "$test_home/.ssh/id_ed25519"
rm -rf -- "$test_home/.config/nvim"

if ! printf 'y\nn\nn\n' | HOME="$test_home" ENVBAT_BACKUP_BASE="$backup_base" \
    PYTHON_BIN="$PYTHON_BIN" bash "$TEST_SCRIPT_DIR/../restore.sh" -d roundtrip >/dev/null; then
    fail_test "restore entrypoint failed"
fi

grep -q '^original zshrc$' "$test_home/.zshrc" || fail_test "zshrc roundtrip failed"
grep -q '^set number$' "$test_home/.config/nvim/init.vim" || fail_test "Neovim roundtrip failed"
grep -q '^changed key$' "$test_home/.ssh/id_ed25519" || fail_test "SSH was restored without confirmation"

echo "PASS: backup restore roundtrip"

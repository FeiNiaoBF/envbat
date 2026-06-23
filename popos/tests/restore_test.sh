#!/usr/bin/env bash
set -euo pipefail

TEST_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=popos/restore.sh
source "$TEST_SCRIPT_DIR/../restore.sh"

fail_test() {
    echo "FAIL: $*" >&2
    exit 1
}

test_root=$(mktemp -d)
trap 'rm -rf -- "$test_root"' EXIT
HOME="$test_root/home"
BACKUP_BASE="$test_root/backups"
PYTHON_BIN="${PYTHON_BIN:-python3}"
mkdir -p "$HOME" "$BACKUP_BASE/v1"

printf '{"schema_version": 1}\n' > "$BACKUP_BASE/v1/manifest.json"
RESTORE_DATE=v1
ask_yes_no() { return 0; }
if restore_precheck >/dev/null 2>&1; then
    fail_test "schema v1 backup was accepted"
fi

payload="$test_root/payload"
mkdir -p "$payload/envbat" "$payload/mise" "$payload/nvim" "$payload/ssh"
printf 'restored zshrc\n' > "$payload/.zshrc"
printf 'ENVBAT_PROFILE_SCHEMA=4\n' > "$payload/envbat/profile.sh"
printf '[tools]\npython = "latest"\n' > "$payload/mise/config.toml"
printf 'set number\n' > "$payload/nvim/init.vim"
printf 'private key\n' > "$payload/ssh/id_ed25519"
mkdir -p "$BACKUP_BASE/valid"
tar -czf "$BACKUP_BASE/valid/dotfiles.tar.gz" -C "$payload" .
"$PYTHON_BIN" "$TEST_SCRIPT_DIR/../manifest.py" create \
    --backup-dir "$BACKUP_BASE/valid" --created-at "2026-06-22T00:00:00+08:00" \
    --host test --user test --os PopOS --install-base "$test_root/data" --overall-status complete \
    --module dotfiles required ok dotfiles.tar.gz sensitive

RESTORE_DATE=valid
restore_precheck >/dev/null || fail_test "valid backup was rejected"

printf 'current zshrc\n' > "$HOME/.zshrc"
cp() { return 1; }
if create_safety_snapshot >/dev/null 2>&1; then
    fail_test "snapshot copy failure was ignored"
fi
unset -f cp

create_safety_snapshot >/dev/null || fail_test "safety snapshot failed"
prepare_restore_payload >/dev/null || fail_test "dotfiles payload extraction failed"
restore_user_state >/dev/null || fail_test "user state restore failed"
grep -q '^restored zshrc$' "$HOME/.zshrc" || fail_test "zshrc was not restored"
grep -q 'ENVBAT_PROFILE_SCHEMA=4' "$HOME/.config/envbat/profile.sh" || fail_test "profile was not restored"
[ -f "$HOME/.config/mise/config.toml" ] || fail_test "mise config was not restored"
[ -f "$HOME/.config/nvim/init.vim" ] || fail_test "Neovim config was not restored"

ask_yes_no() {
    echo "PROMPT:$1"
    case "$1" in
        "开始恢复用户态内容?") return 0 ;;
        *) return 1 ;;
    esac
}
restore_output=$(restore_main -d valid) || fail_test "default restore flow failed"
grep -q 'PROMPT:单独恢复 ~/.ssh' <<< "$restore_output" || fail_test "SSH was not confirmed separately"
grep -q '\[SKIP\].*setup repair' <<< "$restore_output" || fail_test "setup repair did not default to skip"
grep -q 'Stage Summary' <<< "$restore_output" || fail_test "restore summary missing"

echo "PASS: safe restore"

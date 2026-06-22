#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=popos/backup.sh
source "$SCRIPT_DIR/../backup.sh"

fail_test() {
    echo "FAIL: $*" >&2
    exit 1
}

test_root=$(mktemp -d)
trap 'rm -rf -- "$test_root"' EXIT
HOME="$test_root/home"
BACKUP_BASE="$test_root/backups"
INSTALL_BASE="$test_root/data"
PYTHON_BIN="${PYTHON_BIN:-python3}"
mkdir -p "$HOME/.ssh" "$INSTALL_BASE"
printf 'shell config\n' > "$HOME/.zshrc"
printf 'private key\n' > "$HOME/.ssh/id_ed25519"
chmod 600 "$HOME/.ssh/id_ed25519"

backup_packages() { PACKAGES_STATUS=skip; return 1; }
backup_sysconfig() { SYSCONFIG_STATUS=skip; return 1; }
backup_directory_tree() { DIRTREE_STATUS=skip; return 1; }
backup_git_repos() { GITREPOS_STATUS=skip; return 1; }

ENVBAT_TIMESTAMP=success backup_main >/dev/null

[ "$(stat -c %a "$BACKUP_BASE/success")" = 700 ] || fail_test "backup directory mode is not 700"
[ "$(stat -c %a "$BACKUP_BASE/success/dotfiles.tar.gz")" = 600 ] || fail_test "dotfiles archive mode is not 600"
"$PYTHON_BIN" "$SCRIPT_DIR/../manifest.py" validate "$BACKUP_BASE/success" >/dev/null || fail_test "published backup is invalid"
latest_before=$(sha256sum "$BACKUP_BASE/latest/manifest.json")

backup_dotfiles() { return 1; }
if ENVBAT_TIMESTAMP=failure backup_main >/dev/null 2>&1; then
    fail_test "core backup failure returned success"
fi
[ "$(sha256sum "$BACKUP_BASE/latest/manifest.json")" = "$latest_before" ] || fail_test "failed backup replaced latest"
[ ! -e "$BACKUP_BASE/failure" ] || fail_test "failed backup was published"

echo "PASS: secure backup"

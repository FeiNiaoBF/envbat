#!/usr/bin/env bash
set -euo pipefail

TEST_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=popos/shell.sh
source "$TEST_SCRIPT_DIR/../shell.sh"

fail() { :; }
warn() { :; }
ok() { :; }

test_root=$(mktemp -d)
trap 'rm -rf -- "$test_root"' EXIT
HOME="$test_root/home"
TMPDIR="$test_root/tmp"
USER=test-user
mkdir -p "$HOME" "$TMPDIR" "$test_root/bin"
printf '#!/usr/bin/env bash\nexit 0\n' > "$test_root/bin/zsh"
chmod +x "$test_root/bin/zsh"
PATH="$test_root/bin:$PATH"

_popos_install_ohmyzsh_repo() { return 0; }
_popos_install_git_component() { return 0; }
_popos_setup_p10k_config() { return 0; }
_popos_configure_zshrc() { return 0; }
getent() { printf 'test-user:x:1000:1000::/home/test-user:/bin/bash\n'; }
sudo() {
    case "${1:-}" in
        tee) cat >/dev/null; return 0 ;;
        chsh) return 1 ;;
        *) return 0 ;;
    esac
}

if popos_install_ohmyzsh >/dev/null 2>&1; then
    echo "FAIL: chsh failure was reported as success" >&2
    exit 1
fi

echo "PASS: shell failure propagation"

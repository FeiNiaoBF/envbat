#!/usr/bin/env bash
set -euo pipefail

TEST_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=popos/verify.sh
source "$TEST_SCRIPT_DIR/../verify.sh"

fail_test() {
    echo "FAIL: $*" >&2
    exit 1
}

test_root=$(mktemp -d)
trap 'rm -rf -- "$test_root"' EXIT
HOME="$test_root/home"
INSTALL_BASE="$test_root/data"
mkdir -p "$HOME/.config/envbat" "$INSTALL_BASE/workspace/github" "$INSTALL_BASE/tools/bin" "$INSTALL_BASE/temp" "$test_root/bin"

for tool in git curl wget gcc make unzip tar python3 zsh; do
    printf '#!/usr/bin/env bash\nexit 0\n' > "$test_root/bin/$tool"
    chmod +x "$test_root/bin/$tool"
done
PATH="$test_root/bin:$PATH"

loader='# === envbat profile ==='
source_line="[ -f \"\$HOME/.config/envbat/profile.sh\" ] && source \"\$HOME/.config/envbat/profile.sh\""
printf '%s\n%s\n' "$loader" "$source_line" > "$HOME/.bashrc"
printf '%s\n%s\n' "$loader" "$source_line" > "$HOME/.zshrc"
printf 'ENVBAT_PROFILE_SCHEMA=1\n' > "$HOME/.config/envbat/profile.sh"

if popos_verify >/dev/null 2>&1; then
    fail_test "schema v1 profile passed verification"
fi

printf 'ENVBAT_PROFILE_SCHEMA=2\n' > "$HOME/.config/envbat/profile.sh"
popos_verify >/dev/null || fail_test "valid required setup failed verification"

printf '# loader missing\n' > "$HOME/.zshrc"
if popos_verify >/dev/null 2>&1; then
    fail_test "missing zsh profile loader passed verification"
fi

echo "PASS: required verification"

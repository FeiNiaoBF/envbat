#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=popos/shell.sh
source "$SCRIPT_DIR/../shell.sh"

fail() {
    echo "FAIL: $*" >&2
    exit 1
}

ok() { :; }
warn() { :; }

test_home=$(mktemp -d)
trap 'rm -rf -- "$test_home"' EXIT
HOME="$test_home"
TMPDIR="$test_home/tmp"
mkdir -p "$TMPDIR"

cat > "$HOME/.zshrc" <<'EOF'
# === envbat ===
source "$HOME/.config/envbat/profile.sh"
EOF

_popos_configure_zshrc
first_config=$(cksum < "$HOME/.zshrc")
_popos_configure_zshrc
second_config=$(cksum < "$HOME/.zshrc")

omz_line=$(grep -nF "source \"\$ZSH/oh-my-zsh.sh\"" "$HOME/.zshrc" | cut -d: -f1)
p10k_line=$(grep -nF "[[ -f \"\$HOME/.p10k.zsh\" ]] && source \"\$HOME/.p10k.zsh\"" "$HOME/.zshrc" | cut -d: -f1)

[ -n "$omz_line" ] || fail "oh-my-zsh source line missing"
[ -n "$p10k_line" ] || fail "p10k source line missing"
[ "$omz_line" -lt "$p10k_line" ] || fail "p10k must load after oh-my-zsh"
[ "$(grep -cF "source \"\$ZSH/oh-my-zsh.sh\"" "$HOME/.zshrc")" -eq 1 ] || fail "oh-my-zsh source duplicated"
[ "$(grep -cF "[[ -f \"\$HOME/.p10k.zsh\" ]] && source \"\$HOME/.p10k.zsh\"" "$HOME/.zshrc")" -eq 1 ] || fail "p10k source duplicated"
[ "$first_config" = "$second_config" ] || fail ".zshrc changed on the second run"

git() {
    local target="${!#}"
    mkdir -p "$target/custom"
    touch "$target/oh-my-zsh.sh"
}

mkdir -p "$HOME/.oh-my-zsh/custom"
echo "keep" > "$HOME/.oh-my-zsh/custom/user-theme.zsh"

_popos_install_ohmyzsh_repo

[ -f "$HOME/.oh-my-zsh/oh-my-zsh.sh" ] || fail "oh-my-zsh marker missing"
[ -f "$HOME/.oh-my-zsh/custom/user-theme.zsh" ] || fail "existing custom file was lost"
compgen -G "$HOME/.oh-my-zsh.envbat-incomplete-*" >/dev/null || fail "incomplete directory backup missing"

echo "PASS: shell config"

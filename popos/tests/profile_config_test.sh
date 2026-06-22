#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=popos/profile.sh
source "$SCRIPT_DIR/../profile.sh"
# shellcheck source=popos/config.sh
source "$SCRIPT_DIR/../config.sh"

fail() {
    echo "FAIL: $*" >&2
    exit 1
}
ok() { :; }
warn() { :; }

test_home=$(mktemp -d)
trap 'rm -rf -- "$test_home"' EXIT
HOME="$test_home"
PROFILE_DIR="$HOME/.config/envbat"
PROFILE_FILE="$PROFILE_DIR/profile.sh"
mkdir -p "$PROFILE_DIR"

cat > "$PROFILE_FILE" <<'EOF'
INSTALL_BASE="/data"
INSTALL_GO=false
INSTALL_OHMYZSH=true
GIT_USER_NAME="test-user"
EOF

popos_load_profile

[ "${ENVBAT_PROFILE_SCHEMA:-}" = "2" ] || fail "legacy profile was not migrated"
[ "$INSTALL_GO" = false ] || fail "existing choice changed"
[ "$INSTALL_OHMYZSH" = true ] || fail "existing shell choice changed"
[ "$INSTALL_CHROME" = false ] || fail "new Chrome option was enabled"
[ "$INSTALL_CHINESE" = false ] || fail "new locale option was enabled"
[ "$INSTALL_SSH" = skip ] || fail "missing SSH option was not conservative"
compgen -G "$PROFILE_FILE.bak.*" >/dev/null || fail "legacy profile backup missing"

[ ! -e "$HOME/.bashrc" ] || fail "profile migration modified .bashrc"
[ ! -e "$HOME/.zshrc" ] || fail "profile migration modified .zshrc"

expected_name='$(touch "$HOME/profile-injected")'
expected_email='quoted"email@example.com'
GIT_USER_NAME="$expected_name"
GIT_USER_EMAIL="$expected_email"
popos_save_profile
bash -n "$PROFILE_FILE" || fail "shell-special profile value broke syntax"
GIT_USER_NAME=""
GIT_USER_EMAIL=""
# shellcheck source=/dev/null
source "$PROFILE_FILE"
[ "$GIT_USER_NAME" = "$expected_name" ] || fail "Git name was not preserved as data"
[ "$GIT_USER_EMAIL" = "$expected_email" ] || fail "Git email was not preserved as data"
[ ! -e "$HOME/profile-injected" ] || fail "profile value executed as shell code"

cat > "$HOME/.zshrc" <<'EOF'
# === envbat zsh ===
source "$ZSH/oh-my-zsh.sh"
[[ -f "$HOME/.p10k.zsh" ]] && source "$HOME/.p10k.zsh"
# === end envbat zsh ===
EOF
GIT_USER_NAME=""
GIT_USER_EMAIL=""

popos_config_shell_chain
first_config=$(cksum < "$HOME/.zshrc")
popos_config_shell_chain
second_config=$(cksum < "$HOME/.zshrc")

[ "$first_config" = "$second_config" ] || fail ".zshrc loading block is not idempotent"
profile_line=$(grep -nF "source \"\$HOME/.config/envbat/profile.sh\"" "$HOME/.zshrc" | cut -d: -f1)
omz_line=$(grep -nF "source \"\$ZSH/oh-my-zsh.sh\"" "$HOME/.zshrc" | cut -d: -f1)
[ "$profile_line" -lt "$omz_line" ] || fail "profile must load before oh-my-zsh"

echo "PASS: profile and config"

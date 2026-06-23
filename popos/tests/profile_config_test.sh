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
ENVBAT_PROFILE_SCHEMA=2
INSTALL_BASE="/data"
INSTALL_GO=false
INSTALL_NVM_NODE=true
INSTALL_PYENV=false
INSTALL_RUSTUP=true
INSTALL_UV=true
INSTALL_OHMYZSH=true
GIT_USER_NAME="test-user"
EOF

popos_load_profile

[ "${ENVBAT_PROFILE_SCHEMA:-}" = "4" ] || fail "schema 2 profile was not migrated"
[ "$INSTALL_GO" = false ] || fail "existing choice changed"
[ "$INSTALL_NODE" = true ] || fail "Node selection was not migrated"
[ "$INSTALL_PYTHON" = false ] || fail "Python selection was not migrated"
[ "$INSTALL_RUST" = true ] || fail "Rust selection was not migrated"
[ "$INSTALL_MISE" = true ] || fail "mise was not enabled for selected runtimes"
[ "$INSTALL_OHMYZSH" = true ] || fail "existing shell choice changed"
[ "$INSTALL_CHROME" = false ] || fail "new Chrome option was enabled"
[ "$INSTALL_CHINESE" = false ] || fail "new locale option was enabled"
[ "$INSTALL_UV" = true ] || fail "existing uv selection changed"
[ "$INSTALL_SSH" = skip ] || fail "missing SSH option was not conservative"
compgen -G "$PROFILE_FILE.bak.*" >/dev/null || fail "legacy profile backup missing"
grep -q '^INSTALL_NODE=true$' "$PROFILE_FILE" || fail "new Node field missing from profile"
if grep -q '^INSTALL_NVM_NODE=' "$PROFILE_FILE"; then fail "legacy Node field still serialized"; fi

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
grep -q '^export MISE_DATA_DIR=' "$PROFILE_FILE" || fail "mise data path missing"
grep -q 'export MISE_DATA_DIR="$INSTALL_BASE/tools/mise"' "$PROFILE_FILE" || fail "mise data root is not persistent"
grep -q 'export MISE_CACHE_DIR="$INSTALL_BASE/cache/mise"' "$PROFILE_FILE" || fail "mise cache root mismatch"
if grep -qE '^export XDG_(DATA|CACHE)_HOME=' "$PROFILE_FILE"; then
    fail "profile still overrides global XDG data/cache paths"
fi
grep -q 'mise" activate zsh' "$PROFILE_FILE" || fail "zsh mise activation missing"
grep -q 'mise" activate bash' "$PROFILE_FILE" || fail "bash mise activation missing"
if grep -qE 'NVM_DIR|PYENV_ROOT|tools/rustup' "$PROFILE_FILE"; then
    fail "legacy runtime loader remains in schema 3 profile"
fi

INSTALL_MISE=false
INSTALL_GO=false
INSTALL_NODE=false
INSTALL_PYTHON=false
INSTALL_RUST=false
INSTALL_JAVA=skip
popos_save_profile >/dev/null
disabled_path=$(HOME="$HOME" PATH=/usr/bin bash -c 'source "$1"; printf "%s" "$PATH"' _ "$PROFILE_FILE")
case ":$disabled_path:" in
    *:"$INSTALL_BASE/tools/mise/shims":*) fail "disabled mise shims remain active" ;;
esac

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

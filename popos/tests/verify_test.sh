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

printf 'ENVBAT_PROFILE_SCHEMA=4\n' > "$HOME/.config/envbat/profile.sh"
INSTALL_MISE=true
INSTALL_NODE=true
INSTALL_UV=true
verify_output=$(popos_verify) || fail_test "valid required setup failed verification"
grep -q '\[WARN\].*mise marker' <<< "$verify_output" || fail_test "missing managed mise was not reported"
grep -q '\[WARN\].*uv marker' <<< "$verify_output" || fail_test "missing managed uv was not reported"
mkdir -p "$INSTALL_BASE/tools/bin"
mkdir -p "$INSTALL_BASE/tools/mise/shims"
cat > "$INSTALL_BASE/tools/bin/mise" <<'MISE'
#!/usr/bin/env sh
case "$1" in
    where) exit 0 ;;
    --version) echo "mise 1.0.0" ;;
    *) exit 1 ;;
esac
MISE
printf '#!/usr/bin/env sh\nexit 0\n' > "$INSTALL_BASE/tools/bin/uv"
printf '#!/usr/bin/env sh\nexit 0\n' > "$INSTALL_BASE/tools/bin/uvx"
chmod +x "$INSTALL_BASE/tools/bin/mise" "$INSTALL_BASE/tools/bin/uv" "$INSTALL_BASE/tools/bin/uvx"
verify_output=$(popos_verify) || fail_test "managed uv verification failed"
grep -q '\[OK\].*mise$' <<< "$verify_output" || fail_test "managed mise was not verified"
grep -q '\[OK\].*Node' <<< "$verify_output" || fail_test "mise-managed Node was not verified"
grep -q '\[OK\].*uv$' <<< "$verify_output" || fail_test "managed uv was not verified"
grep -q '\[OK\].*uvx$' <<< "$verify_output" || fail_test "managed uvx was not verified"

printf '# loader missing\n' > "$HOME/.zshrc"
if popos_verify >/dev/null 2>&1; then
    fail_test "missing zsh profile loader passed verification"
fi

echo "PASS: required verification"

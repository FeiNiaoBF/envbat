#!/usr/bin/env bash
# === Profile Persistence ===

PROFILE_SCHEMA_CURRENT=4
PROFILE_DIR="${PROFILE_DIR:-$HOME/.config/envbat}"
PROFILE_FILE="${PROFILE_FILE:-$PROFILE_DIR/profile.sh}"

popos_profile_conservative_defaults() {
    INSTALL_BASE="${INSTALL_BASE:-/data}"
    INSTALL_MISE="${INSTALL_MISE:-false}"
    INSTALL_GO="${INSTALL_GO:-false}"
    INSTALL_NODE="${INSTALL_NODE:-false}"
    INSTALL_PYTHON="${INSTALL_PYTHON:-false}"
    INSTALL_RUST="${INSTALL_RUST:-false}"
    INSTALL_UV="${INSTALL_UV:-false}"
    INSTALL_JAVA="${INSTALL_JAVA:-skip}"
    INSTALL_NEOVIM="${INSTALL_NEOVIM:-false}"
    INSTALL_DOCKER="${INSTALL_DOCKER:-false}"
    INSTALL_OHMYZSH="${INSTALL_OHMYZSH:-false}"
    INSTALL_SSH="${INSTALL_SSH:-skip}"
    INSTALL_EXTRA_TOOLS="${INSTALL_EXTRA_TOOLS:-false}"
    INSTALL_UFW="${INSTALL_UFW:-false}"
    INSTALL_FAIL2BAN="${INSTALL_FAIL2BAN:-false}"
    INSTALL_AUTO_UPDATES="${INSTALL_AUTO_UPDATES:-false}"
    INSTALL_CHINESE="${INSTALL_CHINESE:-false}"
    INSTALL_CHROME="${INSTALL_CHROME:-false}"
    GIT_USER_NAME="${GIT_USER_NAME:-}"
    GIT_USER_EMAIL="${GIT_USER_EMAIL:-}"
}

popos_profile_initial_defaults() {
    INSTALL_BASE="${INSTALL_BASE:-/data}"
    INSTALL_MISE="${INSTALL_MISE:-true}"
    INSTALL_GO="${INSTALL_GO:-true}"
    INSTALL_NODE="${INSTALL_NODE:-true}"
    INSTALL_PYTHON="${INSTALL_PYTHON:-true}"
    INSTALL_RUST="${INSTALL_RUST:-true}"
    INSTALL_UV="${INSTALL_UV:-true}"
    INSTALL_JAVA="${INSTALL_JAVA:-skip}"
    INSTALL_NEOVIM="${INSTALL_NEOVIM:-true}"
    INSTALL_DOCKER="${INSTALL_DOCKER:-true}"
    INSTALL_OHMYZSH="${INSTALL_OHMYZSH:-true}"
    INSTALL_SSH="${INSTALL_SSH:-generate}"
    INSTALL_EXTRA_TOOLS="${INSTALL_EXTRA_TOOLS:-true}"
    INSTALL_UFW="${INSTALL_UFW:-true}"
    INSTALL_FAIL2BAN="${INSTALL_FAIL2BAN:-true}"
    INSTALL_AUTO_UPDATES="${INSTALL_AUTO_UPDATES:-true}"
    INSTALL_CHINESE="${INSTALL_CHINESE:-true}"
    INSTALL_CHROME="${INSTALL_CHROME:-false}"
    GIT_USER_NAME="${GIT_USER_NAME:-}"
    GIT_USER_EMAIL="${GIT_USER_EMAIL:-}"
}

popos_write_profile() {
    local temp_file
    if ! mkdir -p "$PROFILE_DIR"; then
        fail "无法创建 profile 目录: $PROFILE_DIR"
        return 1
    fi
    if ! temp_file=$(mktemp "$PROFILE_DIR/profile.sh.tmp.XXXXXX"); then
        fail "无法创建 profile 临时文件"
        return 1
    fi

    if ! {
        echo '# === envbat profile ==='
        printf 'ENVBAT_PROFILE_SCHEMA=%q\n' "$PROFILE_SCHEMA_CURRENT"
        printf 'INSTALL_BASE=%q\n\n' "$INSTALL_BASE"
        cat <<'PROFILE_ENV'
export DATA_HOME="$INSTALL_BASE"
export CODE_HOME="$INSTALL_BASE/workspace/github"
export TOOLS_HOME="$INSTALL_BASE/tools"
export HF_HOME="$INSTALL_BASE/models/huggingface"
export TMPDIR="$INSTALL_BASE/temp"
export MISE_DATA_DIR="$INSTALL_BASE/tools/mise"
export MISE_CONFIG_DIR="$HOME/.config/mise"
export MISE_CACHE_DIR="$INSTALL_BASE/cache/mise"
export MISE_RUSTUP_HOME="$MISE_DATA_DIR/rustup"
export MISE_CARGO_HOME="$MISE_DATA_DIR/cargo"
export RUSTUP_HOME="$MISE_RUSTUP_HOME"
export CARGO_HOME="$MISE_CARGO_HOME"
export PATH="$TOOLS_HOME/bin:$PATH"

PROFILE_ENV
        local var_name
        for var_name in \
            INSTALL_MISE INSTALL_GO INSTALL_NODE INSTALL_PYTHON INSTALL_RUST INSTALL_UV INSTALL_JAVA \
            INSTALL_NEOVIM INSTALL_DOCKER INSTALL_OHMYZSH INSTALL_SSH INSTALL_EXTRA_TOOLS \
            INSTALL_UFW INSTALL_FAIL2BAN INSTALL_AUTO_UPDATES INSTALL_CHINESE INSTALL_CHROME \
            GIT_USER_NAME GIT_USER_EMAIL; do
            printf '%s=%q\n' "$var_name" "${!var_name}"
        done
        cat <<'PROFILE_MISE'

if [ "${INSTALL_MISE:-false}" = true ]; then
    export PATH="$MISE_DATA_DIR/shims:$CARGO_HOME/bin:$PATH"
    if [ -x "$TOOLS_HOME/bin/mise" ]; then
        case "$-" in
            *i*)
                if [ -n "${ZSH_VERSION:-}" ]; then
                    eval "$("$TOOLS_HOME/bin/mise" activate zsh)"
                elif [ -n "${BASH_VERSION:-}" ]; then
                    eval "$("$TOOLS_HOME/bin/mise" activate bash)"
                fi
                ;;
        esac
    fi
fi
PROFILE_MISE
    } > "$temp_file"
    then
        rm -f -- "$temp_file"
        fail "profile 写入失败"
        return 1
    fi
    if ! chmod 600 "$temp_file" || ! mv -f "$temp_file" "$PROFILE_FILE"; then
        rm -f -- "$temp_file"
        fail "profile 原子保存失败"
        return 1
    fi
    ENVBAT_PROFILE_SCHEMA=$PROFILE_SCHEMA_CURRENT
    ok "配置已保存: $PROFILE_FILE"
}

popos_migrate_profile() {
    local backup
    backup="$PROFILE_FILE.bak.$(date +%Y%m%d%H%M%S)"
    if ! cp -a "$PROFILE_FILE" "$backup"; then
        fail "旧 profile 备份失败"
        return 1
    fi
    if [ "${ENVBAT_PROFILE_SCHEMA:-0}" -lt 3 ]; then
        INSTALL_NODE="${INSTALL_NODE:-${INSTALL_NVM_NODE:-false}}"
        INSTALL_PYTHON="${INSTALL_PYTHON:-${INSTALL_PYENV:-false}}"
        INSTALL_RUST="${INSTALL_RUST:-${INSTALL_RUSTUP:-false}}"
        INSTALL_MISE="${INSTALL_MISE:-false}"
        if [ "${INSTALL_GO:-false}" = true ] || [ "$INSTALL_NODE" = true ] || \
            [ "$INSTALL_PYTHON" = true ] || [ "$INSTALL_RUST" = true ] || \
            [ "${INSTALL_JAVA:-skip}" != skip ]; then
            INSTALL_MISE=true
        fi
    fi
    popos_profile_conservative_defaults
    if [ "$INSTALL_SSH" = restore ]; then
        INSTALL_SSH=skip
    fi
    if ! popos_write_profile; then
        return 1
    fi
    warn "旧 profile 已保守迁移到 schema v4，备份: $backup"
}

popos_load_profile() {
    if [ ! -f "$PROFILE_FILE" ]; then
        return 1
    fi
    # shellcheck source=/dev/null
    source "$PROFILE_FILE"
    if [ "${ENVBAT_PROFILE_SCHEMA:-0}" -ne "$PROFILE_SCHEMA_CURRENT" ]; then
        if ! popos_migrate_profile; then
            return 1
        fi
        # shellcheck source=/dev/null
        source "$PROFILE_FILE"
    fi
    popos_profile_conservative_defaults
    ok "已加载配置: $PROFILE_FILE"
}

popos_save_profile() {
    popos_profile_conservative_defaults
    popos_write_profile
}

popos_clean_old_bashrc() {
    local bashrc="$HOME/.bashrc"
    local guard="# === PopOS Environment ==="
    if [ ! -f "$bashrc" ] || ! grep -qF "$guard" "$bashrc" 2>/dev/null; then
        return 0
    fi
    if ! sed -i "/$guard/,/^$/d" "$bashrc"; then
        fail "清理 .bashrc 旧配置失败"
        return 1
    fi
    ok "已清理 .bashrc 中的旧环境变量段"
}

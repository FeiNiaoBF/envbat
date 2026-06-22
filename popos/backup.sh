#!/usr/bin/env bash
# === envbat secure backup ===
set -euo pipefail

BACKUP_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=popos/interactive.sh
source "$BACKUP_SCRIPT_DIR/interactive.sh"
# shellcheck source=popos/runner.sh
source "$BACKUP_SCRIPT_DIR/runner.sh"

BACKUP_BASE="${ENVBAT_BACKUP_BASE:-${BACKUP_BASE:-/data/backups/envbat}}"
PYTHON_BIN="${PYTHON_BIN:-python3}"
INSTALL_BASE="${INSTALL_BASE:-/data}"
BACKUP_DIR=""
FINAL_DIR=""

DOTFILES_STATUS=fail
PACKAGES_STATUS=skip
SYSCONFIG_STATUS=skip
DIRTREE_STATUS=skip
GITREPOS_STATUS=skip

show_help() {
    echo "用法: $0 [--help]"
    echo "安全备份用户配置到 $BACKUP_BASE"
}

backup_load_profile() {
    local profile="$HOME/.config/envbat/profile.sh"
    if [ -f "$profile" ]; then
        # shellcheck source=/dev/null
        if ! source "$profile"; then
            fail "无法加载 envbat profile: $profile"
            return 1
        fi
    fi
    INSTALL_BASE="${INSTALL_BASE:-/data}"
    case "$INSTALL_BASE" in
        /) fail "INSTALL_BASE 不能是根目录 /"; return 1 ;;
        /*) return 0 ;;
        *) fail "INSTALL_BASE 必须是绝对路径: $INSTALL_BASE"; return 1 ;;
    esac
}

backup_prepare_staging() {
    if ! mkdir -p "$BACKUP_BASE" || ! chmod 700 "$BACKUP_BASE"; then
        fail "无法准备备份根目录: $BACKUP_BASE"
        return 1
    fi
    if [ -e "$FINAL_DIR" ]; then
        fail "备份时间戳已存在: $FINAL_DIR"
        return 1
    fi
    if ! mkdir -p "$BACKUP_DIR" || ! chmod 700 "$BACKUP_DIR"; then
        fail "无法创建备份 staging 目录"
        return 1
    fi
}

backup_dotfiles() {
    DOTFILES_STATUS=fail
    local work_dir src
    if ! work_dir=$(mktemp -d "$BACKUP_DIR/.dotfiles.XXXXXX"); then
        fail "无法创建 dotfiles 临时目录"
        return 1
    fi

    for src in "$HOME/.bashrc" "$HOME/.zshrc" "$HOME/.p10k.zsh" "$HOME/.gitconfig" "$HOME/.gitignore_global"; do
        if [ -f "$src" ] && ! cp "$src" "$work_dir/"; then
            rm -rf -- "$work_dir"
            fail "复制 $(basename "$src") 失败"
            return 1
        fi
    done
    if [ -f "$HOME/.config/envbat/profile.sh" ]; then
        if ! mkdir -p "$work_dir/envbat" || ! cp "$HOME/.config/envbat/profile.sh" "$work_dir/envbat/profile.sh"; then
            rm -rf -- "$work_dir"
            fail "复制 envbat profile 失败"
            return 1
        fi
    fi
    if [ -d "$HOME/.ssh" ]; then
        if ! mkdir -p "$work_dir/ssh" || ! cp -R "$HOME/.ssh/." "$work_dir/ssh/"; then
            rm -rf -- "$work_dir"
            fail "复制 SSH 目录失败"
            return 1
        fi
    fi
    if [ -d "$HOME/.config/nvim" ] && ! cp -R "$HOME/.config/nvim" "$work_dir/nvim"; then
        rm -rf -- "$work_dir"
        fail "复制 Neovim 配置失败"
        return 1
    fi
    if [ -d "$HOME/.oh-my-zsh/custom" ]; then
        if ! mkdir -p "$work_dir/oh-my-zsh-custom" || ! cp -R "$HOME/.oh-my-zsh/custom/." "$work_dir/oh-my-zsh-custom/"; then
            rm -rf -- "$work_dir"
            fail "复制 oh-my-zsh custom 失败"
            return 1
        fi
    fi

    if ! tar -czf "$BACKUP_DIR/dotfiles.tar.gz" -C "$work_dir" . || ! chmod 600 "$BACKUP_DIR/dotfiles.tar.gz"; then
        rm -rf -- "$work_dir"
        fail "dotfiles 打包失败"
        return 1
    fi
    rm -rf -- "$work_dir"
    DOTFILES_STATUS=ok
    ok "dotfiles 已安全打包"
}

backup_packages() {
    PACKAGES_STATUS=warn
    if ! dpkg --get-selections > "$BACKUP_DIR/packages.txt" || ! chmod 600 "$BACKUP_DIR/packages.txt"; then
        fail "包列表导出失败"
        return 1
    fi
    PACKAGES_STATUS=ok
}

backup_sysconfig() {
    SYSCONFIG_STATUS=warn
    local work_dir
    if ! work_dir=$(mktemp -d "$BACKUP_DIR/.sysconfig.XXXXXX"); then
        fail "系统配置临时目录创建失败"
        return 1
    fi
    if [ -f /etc/apt/sources.list ]; then cp /etc/apt/sources.list "$work_dir/" || { rm -rf -- "$work_dir"; return 1; }; fi
    if [ -d /etc/apt/sources.list.d ]; then cp -R /etc/apt/sources.list.d "$work_dir/" || { rm -rf -- "$work_dir"; return 1; }; fi
    crontab -l > "$work_dir/crontab.txt" 2>/dev/null || :
    if [ -f /etc/hostname ]; then cp /etc/hostname "$work_dir/" || { rm -rf -- "$work_dir"; return 1; }; fi
    if [ -f /etc/hosts ]; then cp /etc/hosts "$work_dir/" || { rm -rf -- "$work_dir"; return 1; }; fi
    if [ -d /etc/netplan ]; then cp -R /etc/netplan "$work_dir/" || { rm -rf -- "$work_dir"; return 1; }; fi
    if ! tar -czf "$BACKUP_DIR/system-config.tar.gz" -C "$work_dir" . || ! chmod 600 "$BACKUP_DIR/system-config.tar.gz"; then
        rm -rf -- "$work_dir"
        fail "系统配置打包失败"
        return 1
    fi
    rm -rf -- "$work_dir"
    SYSCONFIG_STATUS=ok
}

backup_directory_tree() {
    DIRTREE_STATUS=warn
    if ! find "$INSTALL_BASE" \
        \( -path "$BACKUP_BASE" -o -path '*/lost+found' -o -path '*/temp' -o -path '*/.cache' \) -prune -o \
        -type d -print | sort > "$BACKUP_DIR/directory-tree.txt" || \
        ! chmod 600 "$BACKUP_DIR/directory-tree.txt"; then
        fail "目录结构导出失败"
        return 1
    fi
    DIRTREE_STATUS=ok
}

backup_git_repos() {
    GITREPOS_STATUS=warn
    if ! "$PYTHON_BIN" "$BACKUP_SCRIPT_DIR/manifest.py" repos-create "$HOME/Code" "$BACKUP_DIR/git-repos.json"; then
        fail "Git 仓库列表导出失败"
        return 1
    fi
    GITREPOS_STATUS=ok
}

module_path() {
    local status="$1" path="$2"
    if [ "$status" = ok ]; then
        printf '%s' "$path"
    else
        printf '-'
    fi
}

backup_write_manifest() {
    local overall=complete created host os_name
    if stage_has_warnings; then overall=complete_with_warnings; fi
    created=$(date -Iseconds)
    host=$(hostname)
    os_name=$(grep '^PRETTY_NAME=' /etc/os-release 2>/dev/null | cut -d= -f2- | tr -d '"')
    os_name="${os_name:-unknown}"

    if ! "$PYTHON_BIN" "$BACKUP_SCRIPT_DIR/manifest.py" create \
        --backup-dir "$BACKUP_DIR" --created-at "$created" --host "$host" --user "$(whoami)" \
        --os "$os_name" --install-base "$INSTALL_BASE" --overall-status "$overall" \
        --module dotfiles required "$DOTFILES_STATUS" "$(module_path "$DOTFILES_STATUS" dotfiles.tar.gz)" sensitive \
        --module packages optional "$PACKAGES_STATUS" "$(module_path "$PACKAGES_STATUS" packages.txt)" normal \
        --module sysconfig optional "$SYSCONFIG_STATUS" "$(module_path "$SYSCONFIG_STATUS" system-config.tar.gz)" sensitive \
        --module directory_tree optional "$DIRTREE_STATUS" "$(module_path "$DIRTREE_STATUS" directory-tree.txt)" normal \
        --module git_repos optional "$GITREPOS_STATUS" "$(module_path "$GITREPOS_STATUS" git-repos.json)" normal; then
        fail "manifest v2 生成失败"
        return 1
    fi

    if ! {
        echo "schema_version: 2"
        echo "created_at: $created"
        echo "overall_status: $overall"
        echo "install_base: $INSTALL_BASE"
        echo "dotfiles: $DOTFILES_STATUS"
        echo "packages: $PACKAGES_STATUS"
        echo "sysconfig: $SYSCONFIG_STATUS"
        echo "directory_tree: $DIRTREE_STATUS"
        echo "git_repos: $GITREPOS_STATUS"
    } > "$BACKUP_DIR/MANIFEST.txt" || ! chmod 600 "$BACKUP_DIR/MANIFEST.txt"; then
        fail "MANIFEST.txt 生成失败"
        return 1
    fi
    "$PYTHON_BIN" "$BACKUP_SCRIPT_DIR/manifest.py" validate "$BACKUP_DIR" >/dev/null
}

backup_publish() {
    local latest_temp="$BACKUP_BASE/.latest.$$"
    if ! mv "$BACKUP_DIR" "$FINAL_DIR"; then
        fail "备份发布失败"
        return 1
    fi
    BACKUP_DIR=""
    if ! ln -s "$FINAL_DIR" "$latest_temp" || ! mv -Tf "$latest_temp" "$BACKUP_BASE/latest"; then
        rm -f -- "$latest_temp"
        fail "latest 原子更新失败"
        return 1
    fi
    ok "latest → $FINAL_DIR"
}

backup_cleanup_staging() {
    case "$BACKUP_DIR" in
        "$BACKUP_BASE"/.staging-*)
            if [ -d "$BACKUP_DIR" ]; then rm -rf -- "$BACKUP_DIR"; fi
            ;;
    esac
}

backup_stop_on_signal() {
    trap - INT TERM
    exit 130
}

backup_main() {
    umask 077
    STAGE_NAMES=(); STAGE_STATUSES=(); STAGE_REQUIRED=(); STAGE_MESSAGES=()
    DOTFILES_STATUS=fail; PACKAGES_STATUS=skip; SYSCONFIG_STATUS=skip; DIRTREE_STATUS=skip; GITREPOS_STATUS=skip

    local timestamp
    timestamp="${ENVBAT_TIMESTAMP:-$(date +%Y-%m-%dT%H%M%S%z)}"
    FINAL_DIR="$BACKUP_BASE/$timestamp"
    BACKUP_DIR="$BACKUP_BASE/.staging-$timestamp-$$"

    if ! stage_required "backup profile" backup_load_profile; then stage_finish "backup" || true; return 1; fi
    if ! stage_required "prepare staging" backup_prepare_staging; then stage_finish "backup" || true; [ -z "$BACKUP_DIR" ] || rm -rf -- "$BACKUP_DIR"; return 1; fi
    if ! stage_required "dotfiles" backup_dotfiles; then stage_finish "backup" || true; rm -rf -- "$BACKUP_DIR"; return 1; fi

    if command -v dpkg &>/dev/null; then stage_optional "packages" backup_packages; else PACKAGES_STATUS=skip; stage_skip "packages" "dpkg unavailable"; fi
    stage_optional "system config" backup_sysconfig
    if [ -d "$INSTALL_BASE" ]; then stage_optional "directory tree" backup_directory_tree; else DIRTREE_STATUS=skip; stage_skip "directory tree" "install base missing"; fi
    if [ -d "$HOME/Code" ]; then stage_optional "git repos" backup_git_repos; else GITREPOS_STATUS=skip; stage_skip "git repos" "~/Code missing"; fi

    if ! stage_required "manifest v2" backup_write_manifest; then stage_finish "backup" || true; rm -rf -- "$BACKUP_DIR"; return 1; fi
    if ! stage_required "publish latest" backup_publish; then stage_finish "backup" || true; [ -z "$BACKUP_DIR" ] || rm -rf -- "$BACKUP_DIR"; return 1; fi
    stage_finish "backup"
    echo "  位置: $FINAL_DIR"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    trap backup_cleanup_staging EXIT
    trap backup_stop_on_signal INT TERM
    case "${1:-}" in
        "") backup_main ;;
        --help|-h) show_help ;;
        *) warn "未知参数: $1"; exit 1 ;;
    esac
fi

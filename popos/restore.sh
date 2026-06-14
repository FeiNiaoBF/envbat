#!/usr/bin/env bash
# === envbat — Restore Tool ===
# Restores from a backup in /data/backups/envbat/.
# Default: restore latest backup fully.
# Interactive: ask per item with -i flag.
#
# Usage:
#   ./popos/restore.sh                    # Restore latest backup (all items)
#   ./popos/restore.sh -i                 # Interactive: confirm per item
#   ./popos/restore.sh -d 2026-06-14T1530+0800  # Restore specific backup
#   ./popos/restore.sh --help             # Show help
# ============================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/interactive.sh"

BACKUP_BASE="/data/backups/envbat"
INTERACTIVE=false
RESTORE_DATE=""

show_help() {
    echo "用法: $0 [选项]"
    echo ""
    echo "选项:"
    echo "  -i            交互模式 — 逐项确认是否恢复"
    echo "  -d <时间戳>    指定备份日期 (如 2026-06-14T1530+0800)"
    echo "                 默认使用 latest 符号链接"
    echo "  --help        显示此帮助"
    exit 0
}

# Parse args
while [ $# -gt 0 ]; do
    case "$1" in
        -i) INTERACTIVE=true; shift ;;
        -d) RESTORE_DATE="$2"; shift 2 ;;
        --help) show_help ;;
        *) warn "未知参数: $1"; exit 1 ;;
    esac
done

# Determine backup directory
if [ -n "$RESTORE_DATE" ]; then
    RESTORE_DIR="$BACKUP_BASE/$RESTORE_DATE"
else
    RESTORE_DIR="$BACKUP_BASE/latest"
fi

if [ ! -d "$RESTORE_DIR" ]; then
    fail "备份目录不存在: $RESTORE_DIR"
    exit 1
fi

# Resolve symlink to real path for display
RESTORE_DIR_REAL=$(cd "$RESTORE_DIR" && pwd)

# ============================================================
echo ""
echo "################################################"
echo "#  envbat 恢复工具                             #"
echo "################################################"
echo ""
info "恢复来源: $RESTORE_DIR_REAL"
echo ""

# ---- Check backup contents ----
has_dotfiles=false; has_packages=false; has_sysconfig=false
has_dirtree=false; has_gitrepos=false

[ -f "$RESTORE_DIR/dotfiles.tar.gz" ] && has_dotfiles=true
[ -f "$RESTORE_DIR/packages.txt" ] && has_packages=true
[ -f "$RESTORE_DIR/apt-sources.tar.gz" ] && has_sysconfig=true
[ -f "$RESTORE_DIR/directory-tree.txt" ] && has_dirtree=true
[ -f "$RESTORE_DIR/git-repos.txt" ] && has_gitrepos=true

echo "--- 备份内容 ---"
$has_dotfiles && echo "  [found] dotfiles" || echo "  [miss]  dotfiles"
$has_packages && echo "  [found] 包列表" || echo "  [miss]  包列表"
$has_sysconfig && echo "  [found] 系统配置" || echo "  [miss]  系统配置"
$has_dirtree && echo "  [found] 目录结构" || echo "  [miss]  目录结构"
$has_gitrepos && echo "  [found] Git 仓库列表" || echo "  [miss]  Git 仓库列表"
echo ""

# ---- Confirm restore ----
if ! ask_yes_no "开始恢复以上内容?" "Y"; then
    info "已取消"
    exit 0
fi

# ---- Safety backup before overwrite ----
echo "--- 安全备份: 备份将被覆盖的当前文件 ---"
local safe_dir="/tmp/envbat-restore-backup-$(date +%Y%m%d%H%M%S)"
mkdir -p "$safe_dir"
for item in "$HOME/.bashrc" "$HOME/.zshrc" "$HOME/.gitconfig" "$HOME/.config/nvim"; do
    if [ -e "$item" ]; then
        local dest="$safe_dir/"
        mkdir -p "$(dirname "$dest$item")"
        cp -r "$item" "$dest" 2>/dev/null || true
    fi
done
ok "当前文件已备份到: $safe_dir"
echo "  如需回滚: cp -r $safe_dir/* ~/"
echo ""

# ---- Restore dotfiles ----
restore_dotfiles() {
    title "恢复 dotfiles"
    local tmp_dir
    tmp_dir=$(mktemp -d)
    tar -xzf "$RESTORE_DIR/dotfiles.tar.gz" -C "$tmp_dir" 2>/dev/null
    # Restore each item
    for item in .bashrc .zshrc .gitconfig .gitignore_global; do
        if [ -f "$tmp_dir/$item" ]; then
            cp "$tmp_dir/$item" "$HOME/$item" && echo "  [OK]  ~/$item" || warn "~/$item 恢复失败"
        fi
    done
    # SSH
    if [ -d "$tmp_dir/ssh" ]; then
        mkdir -p "$HOME/.ssh"
        cp "$tmp_dir/ssh/"* "$HOME/.ssh/" 2>/dev/null
        chmod 600 "$HOME/.ssh/id_ed25519" 2>/dev/null || true
        chmod 644 "$HOME/.ssh/id_ed25519.pub" 2>/dev/null || true
        echo "  [OK]  SSH 密钥"
    fi
    # Neovim config
    if [ -d "$tmp_dir/nvim" ]; then
        mkdir -p "$HOME/.config"
        cp -r "$tmp_dir/nvim" "$HOME/.config/" 2>/dev/null && echo "  [OK]  Neovim 配置"
    fi
    # oh-my-zsh custom
    if [ -d "$tmp_dir/oh-my-zsh-custom" ]; then
        local omz_custom="$HOME/.oh-my-zsh/custom"
        mkdir -p "$omz_custom"
        [ -d "$tmp_dir/oh-my-zsh-custom/themes" ] && cp -r "$tmp_dir/oh-my-zsh-custom/themes" "$omz_custom/" 2>/dev/null
        [ -d "$tmp_dir/oh-my-zsh-custom/plugins" ] && cp -r "$tmp_dir/oh-my-zsh-custom/plugins" "$omz_custom/" 2>/dev/null
        echo "  [OK]  oh-my-zsh 自定义"
    fi
    rm -rf "$tmp_dir"
    ok "dotfiles 恢复完成"
}

# ---- Restore apt sources ----
restore_sysconfig() {
    title "恢复系统配置"
    local tmp_dir
    tmp_dir=$(mktemp -d)
    tar -xzf "$RESTORE_DIR/apt-sources.tar.gz" -C "$tmp_dir" 2>/dev/null
    if [ -f "$tmp_dir/apt/sources.list" ]; then
        sudo cp "$tmp_dir/apt/sources.list" /etc/apt/sources.list && echo "  [OK]  apt sources.list"
    fi
    if [ -d "$tmp_dir/apt/sources.list.d" ]; then
        sudo cp -r "$tmp_dir/apt/sources.list.d/"* /etc/apt/sources.list.d/ 2>/dev/null && echo "  [OK]  apt sources.list.d"
    fi
    if [ -f "$tmp_dir/crontab.txt" ] && [ -s "$tmp_dir/crontab.txt" ]; then
        crontab "$tmp_dir/crontab.txt" 2>/dev/null && echo "  [OK]  crontab"
    fi
    if [ -f "$tmp_dir/hostname" ]; then
        sudo cp "$tmp_dir/hostname" /etc/hostname 2>/dev/null && echo "  [OK]  hostname"
    fi
    if [ -f "$tmp_dir/hosts" ]; then
        sudo cp "$tmp_dir/hosts" /etc/hosts 2>/dev/null && echo "  [OK]  hosts"
    fi
    rm -rf "$tmp_dir"
    ok "系统配置恢复完成"
}

# ---- Restore packages ----
restore_packages() {
    title "恢复包列表"
    if [ ! -s "$RESTORE_DIR/packages.txt" ]; then
        echo "  [SKIP] 包列表为空"
        return
    fi
    warn "这将重新安装 $RESTORE_DIR/../packages.txt 中的所有包"
    if ! ask_yes_no "是否继续?" "N"; then
        echo "  [SKIP] 用户取消"
        return
    fi
    sudo dpkg --clear-selections 2>/dev/null
    sudo dpkg --set-selections < "$RESTORE_DIR/packages.txt" 2>/dev/null
    sudo apt-get dselect-upgrade -y 2>/dev/null
    ok "包列表恢复完成"
}

# === Execute ===
if $has_dotfiles; then
    if $INTERACTIVE && ! ask_yes_no "恢复 dotfiles?" "Y"; then
        echo "  [SKIP] 用户跳过"
    else
        restore_dotfiles
    fi
fi

if $has_packages; then
    if $INTERACTIVE && ! ask_yes_no "恢复包列表?" "N"; then
        echo "  [SKIP] 用户跳过"
    else
        restore_packages
    fi
fi

if $has_sysconfig; then
    if $INTERACTIVE && ! ask_yes_no "恢复系统配置?" "Y"; then
        echo "  [SKIP] 用户跳过"
    else
        restore_sysconfig
    fi
fi

if $has_dirtree; then
    title "恢复目录结构"
    if $INTERACTIVE && ! ask_yes_no "恢复 /data 目录结构?" "Y"; then
        echo "  [SKIP] 用户跳过"
    else
        while IFS= read -r dir; do
            if [ ! -d "$dir" ]; then
                mkdir -p "$dir" 2>/dev/null && echo "  [CREATE] $dir" || warn "创建失败: $dir"
            else
                echo "  [EXISTS] $dir"
            fi
        done < "$RESTORE_DIR/directory-tree.txt"
        ok "目录结构恢复完成"
    fi
fi

if $has_gitrepos; then
    title "恢复 Git 仓库 (克隆远程)"
    if $INTERACTIVE && ! ask_yes_no "克隆所有 Git 仓库?" "N"; then
        echo "  [SKIP] 用户跳过"
    else
        while IFS= read -r line; do
            # Format: [relative/path] git@github.com:user/repo.git
            local repo_path repo_url
            repo_path=$(echo "$line" | sed -n 's/^\[\(.*\)\] \(.*\)$/\1/p')
            repo_url=$(echo "$line" | sed -n 's/^\[\(.*\)\] \(.*\)$/\2/p')
            if [ -z "$repo_path" ] || [ -z "$repo_url" ]; then
                continue
            fi
            local target="$HOME/$repo_path"
            if [ -d "$target/.git" ]; then
                echo "  [SKIP] $repo_path (已存在)"
            else
                mkdir -p "$(dirname "$target")"
                git clone "$repo_url" "$target" 2>/dev/null && echo "  [CLONE] $repo_path" || warn "克隆失败: $repo_path"
            fi
        done < "$RESTORE_DIR/git-repos.txt"
        ok "Git 仓库恢复完成"
    fi
fi

# === Summary ===
echo ""
echo "========================================"
echo " ✅ 恢复完成"
echo ""
echo "  来源: $RESTORE_DIR_REAL"
echo "  原始文件备份在: $safe_dir"
echo "  如需完全回滚:"
echo "    cp -r $safe_dir/* ~/"
echo "========================================"

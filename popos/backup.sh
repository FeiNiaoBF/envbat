#!/usr/bin/env bash
# === envbat — Backup Tool ===
# Backs up dotfiles, package list, system config, /data structure, and git repos.
#
# Usage:
#   ./popos/backup.sh                    # Full backup to /data/backups/envbat/
#   ./popos/backup.sh --help             # Show help
#
# Output:
#   /data/backups/envbat/<timestamp>/    # Backup directory
#   /data/backups/envbat/latest          # Symlink to latest backup
# ============================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/interactive.sh"

BACKUP_BASE="/data/backups/envbat"
TIMESTAMP=$(date +%Y-%m-%dT%H%M%S%z)
BACKUP_DIR="$BACKUP_BASE/$TIMESTAMP"

show_help() {
    echo "用法: $0"
    echo "  备份系统配置和数据到 $BACKUP_BASE"
    echo ""
    echo "  选项:"
    echo "    --help    显示此帮助"
    exit 0
}

for arg in "$@"; do
    case "$arg" in
        --help) show_help ;;
        *) warn "未知参数: $arg"; exit 1 ;;
    esac
done

# ============================================================
echo ""
echo "################################################"
echo "#  envbat 备份工具                             #"
echo "#  → $BACKUP_BASE"
echo "################################################"
echo ""

# ---- [1] Create backup directory ----
mkdir -p "$BACKUP_DIR"
ok "创建备份目录: $BACKUP_DIR"

# ---- [2] Backup dotfiles ----
echo ""
echo "--- 备份 dotfiles ---"
dotfiles_dir=$(mktemp -d)
# Collect dotfiles
for src in "$HOME/.bashrc" "$HOME/.zshrc" "$HOME/.gitconfig" "$HOME/.gitignore_global"; do
    if [ -f "$src" ]; then
        cp "$src" "$dotfiles_dir/" 2>/dev/null
        echo "  [OK]  $(basename "$src")"
    else
        echo "  [SKIP] $(basename "$src") (不存在)"
    fi
done
# SSH keys
if [ -d "$HOME/.ssh" ]; then
    mkdir -p "$dotfiles_dir/ssh"
    cp "$HOME/.ssh/id_ed25519" "$HOME/.ssh/id_ed25519.pub" "$HOME/.ssh/config" "$dotfiles_dir/ssh/" 2>/dev/null || true
    echo "  [OK]  SSH 密钥"
fi
# Neovim config
if [ -d "$HOME/.config/nvim" ]; then
    cp -r "$HOME/.config/nvim" "$dotfiles_dir/" 2>/dev/null
    echo "  [OK]  Neovim 配置"
fi
# oh-my-zsh custom
if [ -d "$HOME/.oh-my-zsh/custom" ]; then
    local custom_target="$dotfiles_dir/oh-my-zsh-custom"
    mkdir -p "$custom_target"
    cp -r "$HOME/.oh-my-zsh/custom/themes" "$custom_target/" 2>/dev/null || true
    cp -r "$HOME/.oh-my-zsh/custom/plugins" "$custom_target/" 2>/dev/null || true
    echo "  [OK]  oh-my-zsh 自定义主题/插件"
fi
# Package into tar.gz
tar -czf "$BACKUP_DIR/dotfiles.tar.gz" -C "$dotfiles_dir" . 2>/dev/null
rm -rf "$dotfiles_dir"
ok "dotfiles 已打包: dotfiles.tar.gz"

# ---- [3] Package list ----
echo ""
echo "--- 备份包列表 ---"
dpkg --get-selections > "$BACKUP_DIR/packages.txt" 2>/dev/null
local pkg_count
pkg_count=$(wc -l < "$BACKUP_DIR/packages.txt")
ok "包列表已导出: $pkg_count 个包"

# ---- [4] System config ----
echo ""
echo "--- 备份系统配置 ---"
sys_dir=$(mktemp -d)
# apt sources
if [ -d /etc/apt/sources.list.d ] || [ -f /etc/apt/sources.list ]; then
    local apt_dir="$sys_dir/apt"
    mkdir -p "$apt_dir"
    [ -f /etc/apt/sources.list ] && cp /etc/apt/sources.list "$apt_dir/"
    [ -d /etc/apt/sources.list.d ] && cp -r /etc/apt/sources.list.d "$apt_dir/"
    echo "  [OK]  apt 源"
fi
# crontab
crontab -l > "$sys_dir/crontab.txt" 2>/dev/null && echo "  [OK]  crontab" || echo "  [SKIP] crontab (无任务)"
# Network config (hostname, hosts, netplan)
[ -f /etc/hostname ] && cp /etc/hostname "$sys_dir/" 2>/dev/null
[ -f /etc/hosts ] && cp /etc/hosts "$sys_dir/" 2>/dev/null
[ -d /etc/netplan ] && cp -r /etc/netplan "$sys_dir/" 2>/dev/null
# Package into tar.gz
tar -czf "$BACKUP_DIR/apt-sources.tar.gz" -C "$sys_dir" . 2>/dev/null
rm -rf "$sys_dir"
ok "系统配置已打包: apt-sources.tar.gz"

# ---- [5] Directory tree ----
echo ""
echo "--- 备份目录结构 ---"
if [ -d /data ]; then
    find /data -type d -not -path '*/lost+found' -not -path '*/temp/*' -not -path '*/.cache/*' 2>/dev/null | sort > "$BACKUP_DIR/directory-tree.txt"
    local dir_count
    dir_count=$(wc -l < "$BACKUP_DIR/directory-tree.txt")
    ok "目录结构已导出: $dir_count 个目录"
else
    echo "  [SKIP] /data 不存在"
    touch "$BACKUP_DIR/directory-tree.txt"
fi

# ---- [6] Git repos ----
echo ""
echo "--- 备份 Git 仓库远程地址 ---"
if [ -d "$HOME/Code" ]; then
    # Find all .git dirs under ~/Code, extract remote origin URL
    > "$BACKUP_DIR/git-repos.txt"
    while IFS= read -r -d '' gitdir; do
        local repo_dir
        repo_dir="$(dirname "$gitdir")"
        local remote_url
        remote_url=$(git -C "$repo_dir" remote get-url origin 2>/dev/null || true)
        if [ -n "$remote_url" ]; then
            local rel_path="${repo_dir#$HOME/}"
            echo "[$rel_path] $remote_url" >> "$BACKUP_DIR/git-repos.txt"
        fi
    done < <(find "$HOME/Code" -name ".git" -type d -prune -print0 2>/dev/null)
    local repo_count
    repo_count=$(wc -l < "$BACKUP_DIR/git-repos.txt")
    ok "Git 仓库地址已导出: $repo_count 个仓库"
else
    echo "  [SKIP] ~/Code 不存在"
    touch "$BACKUP_DIR/git-repos.txt"
fi

# ---- [7] Generate MANIFEST ----
echo ""
echo "--- 生成 MANIFEST ---"
{
    echo "backup_timestamp: $TIMESTAMP"
    echo "hostname: $(hostname 2>/dev/null || echo 'unknown')"
    echo "os: $(lsb_release -ds 2>/dev/null || grep PRETTY_NAME /etc/os-release 2>/dev/null | cut -d= -f2 | tr -d '\"' || echo 'unknown')"
    echo "user: $(whoami)"
    echo "packages: $pkg_count"
    echo "dotfiles: dotfiles.tar.gz"
    echo "packages_file: packages.txt"
    echo "system_config: apt-sources.tar.gz"
    echo "directory_tree: directory-tree.txt"
    echo "git_repos: git-repos.txt"
} > "$BACKUP_DIR/MANIFEST"
ok "MANIFEST 已生成"

# ---- [8] Update latest symlink ----
ln -sfn "$BACKUP_DIR" "$BACKUP_BASE/latest"
ok "符号链接已更新: latest → $BACKUP_DIR"

# ---- [9] Summary ----
local total_size
total_size=$(du -sh "$BACKUP_DIR" 2>/dev/null | cut -f1)
echo ""
echo "========================================"
echo " ✅ 备份完成"
echo ""
echo "  位置:      $BACKUP_DIR"
echo "  大小:      $total_size"
echo "  时间:      $(date '+%Y-%m-%d %H:%M:%S')"
echo "========================================"

#!/usr/bin/env bash
# === envbat — Backup Tool ===
# Backs up user state, package list, system config, /data structure, and git repos.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/interactive.sh"
source "$SCRIPT_DIR/runner.sh"

BACKUP_BASE="/data/backups/envbat"
TIMESTAMP=$(date +%Y-%m-%dT%H%M%S%z)
BACKUP_DIR="$BACKUP_BASE/$TIMESTAMP"

DOTFILES_STATUS="missing"
PACKAGES_STATUS="missing"
SYSCONFIG_STATUS="missing"
DIRTREE_STATUS="missing"
GITREPOS_STATUS="missing"

show_help() {
    echo "用法: $0 [--help]"
    echo "  备份系统配置和用户状态到 $BACKUP_BASE"
}

json_escape() {
    printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'
}

create_backup_dir() {
    mkdir -p "$BACKUP_DIR"
    ok "创建备份目录: $BACKUP_DIR"
}

backup_dotfiles() {
    echo "--- 备份 dotfiles ---"
    local dotfiles_dir
    dotfiles_dir=$(mktemp -d)

    for src in "$HOME/.bashrc" "$HOME/.zshrc" "$HOME/.gitconfig" "$HOME/.gitignore_global"; do
        if [ -f "$src" ]; then
            if ! cp "$src" "$dotfiles_dir/"; then
                rm -rf "$dotfiles_dir"
                fail "复制 $(basename "$src") 失败"
                return 1
            fi
            echo "  [OK]  $(basename "$src")"
        else
            echo "  [SKIP] $(basename "$src") (不存在)"
        fi
    done

    if [ -f "$HOME/.config/envbat/profile.sh" ]; then
        mkdir -p "$dotfiles_dir/envbat"
        if ! cp "$HOME/.config/envbat/profile.sh" "$dotfiles_dir/envbat/profile.sh"; then
            rm -rf "$dotfiles_dir"
            fail "复制 envbat profile 失败"
            return 1
        fi
        echo "  [OK]  envbat profile"
    fi

    if [ -d "$HOME/.ssh" ]; then
        mkdir -p "$dotfiles_dir/ssh"
        if ! cp -a "$HOME/.ssh/." "$dotfiles_dir/ssh/"; then
            rm -rf "$dotfiles_dir"
            fail "复制 SSH 目录失败"
            return 1
        fi
        echo "  [OK]  SSH 目录"
    fi

    if [ -d "$HOME/.config/nvim" ]; then
        if ! cp -a "$HOME/.config/nvim" "$dotfiles_dir/"; then
            rm -rf "$dotfiles_dir"
            fail "复制 Neovim 配置失败"
            return 1
        fi
        echo "  [OK]  Neovim 配置"
    fi

    if [ -d "$HOME/.oh-my-zsh/custom" ]; then
        mkdir -p "$dotfiles_dir/oh-my-zsh-custom"
        if ! cp -a "$HOME/.oh-my-zsh/custom/." "$dotfiles_dir/oh-my-zsh-custom/"; then
            rm -rf "$dotfiles_dir"
            fail "复制 oh-my-zsh 自定义目录失败"
            return 1
        fi
        echo "  [OK]  oh-my-zsh 自定义主题/插件"
    fi

    if ! tar -czf "$BACKUP_DIR/dotfiles.tar.gz" -C "$dotfiles_dir" .; then
        rm -rf "$dotfiles_dir"
        fail "dotfiles 打包失败"
        return 1
    fi
    rm -rf "$dotfiles_dir"
    DOTFILES_STATUS="ok"
    ok "dotfiles 已打包: dotfiles.tar.gz"
}

backup_packages() {
    echo "--- 备份包列表 ---"
    if ! dpkg --get-selections > "$BACKUP_DIR/packages.txt"; then
        fail "导出包列表失败"
        return 1
    fi
    PACKAGES_STATUS="ok"
    local pkg_count
    pkg_count=$(wc -l < "$BACKUP_DIR/packages.txt")
    ok "包列表已导出: $pkg_count 个包"
}

backup_sysconfig() {
    echo "--- 备份系统配置 ---"
    local sys_dir apt_dir
    sys_dir=$(mktemp -d)
    apt_dir="$sys_dir/apt"

    if [ -d /etc/apt/sources.list.d ] || [ -f /etc/apt/sources.list ]; then
        mkdir -p "$apt_dir"
        if [ -f /etc/apt/sources.list ] && ! cp /etc/apt/sources.list "$apt_dir/"; then
            rm -rf "$sys_dir"
            fail "复制 apt sources.list 失败"
            return 1
        fi
        if [ -d /etc/apt/sources.list.d ] && ! cp -a /etc/apt/sources.list.d "$apt_dir/"; then
            rm -rf "$sys_dir"
            fail "复制 apt sources.list.d 失败"
            return 1
        fi
        echo "  [OK]  apt 源"
    fi

    crontab -l > "$sys_dir/crontab.txt" 2>/dev/null && echo "  [OK]  crontab" || echo "  [SKIP] crontab (无任务)"
    if [ -f /etc/hostname ] && ! cp /etc/hostname "$sys_dir/"; then
        rm -rf "$sys_dir"
        fail "复制 hostname 失败"
        return 1
    fi
    if [ -f /etc/hosts ] && ! cp /etc/hosts "$sys_dir/"; then
        rm -rf "$sys_dir"
        fail "复制 hosts 失败"
        return 1
    fi
    if [ -d /etc/netplan ] && ! cp -a /etc/netplan "$sys_dir/"; then
        rm -rf "$sys_dir"
        fail "复制 netplan 失败"
        return 1
    fi

    if ! tar -czf "$BACKUP_DIR/apt-sources.tar.gz" -C "$sys_dir" .; then
        rm -rf "$sys_dir"
        fail "系统配置打包失败"
        return 1
    fi
    rm -rf "$sys_dir"
    SYSCONFIG_STATUS="ok"
    ok "系统配置已打包: apt-sources.tar.gz"
}

backup_directory_tree() {
    echo "--- 备份目录结构 ---"
    if [ -d /data ]; then
        if ! find /data -type d -not -path '*/lost+found' -not -path '*/temp/*' -not -path '*/.cache/*' | sort > "$BACKUP_DIR/directory-tree.txt"; then
            fail "导出 /data 目录结构失败"
            return 1
        fi
        local dir_count
        dir_count=$(wc -l < "$BACKUP_DIR/directory-tree.txt")
        ok "目录结构已导出: $dir_count 个目录"
    else
        echo "  [SKIP] /data 不存在"
        touch "$BACKUP_DIR/directory-tree.txt"
    fi
    DIRTREE_STATUS="ok"
}

backup_git_repos() {
    echo "--- 备份 Git 仓库远程地址 ---"
    > "$BACKUP_DIR/git-repos.txt"
    if [ -d "$HOME/Code" ]; then
        local gitdir repo_dir remote_url rel_path repo_count
        while IFS= read -r -d '' gitdir; do
            repo_dir="$(dirname "$gitdir")"
            remote_url=$(git -C "$repo_dir" remote get-url origin 2>/dev/null || true)
            if [ -n "$remote_url" ]; then
                rel_path="${repo_dir#$HOME/}"
                echo "[$rel_path] $remote_url" >> "$BACKUP_DIR/git-repos.txt"
            fi
        done < <(find "$HOME/Code" -name ".git" -type d -prune -print0 2>/dev/null)
        repo_count=$(wc -l < "$BACKUP_DIR/git-repos.txt")
        ok "Git 仓库地址已导出: $repo_count 个仓库"
    else
        echo "  [SKIP] ~/Code 不存在"
    fi
    GITREPOS_STATUS="ok"
}

write_manifests() {
    echo "--- 生成 MANIFEST ---"
    local host os user created
    host=$(hostname 2>/dev/null || echo "unknown")
    os=$(lsb_release -ds 2>/dev/null || grep PRETTY_NAME /etc/os-release 2>/dev/null | cut -d= -f2 | tr -d '"' || echo "unknown")
    user=$(whoami)
    created=$(date -Iseconds)

    {
        echo "backup_timestamp: $TIMESTAMP"
        echo "created_at: $created"
        echo "hostname: $host"
        echo "os: $os"
        echo "user: $user"
        echo "dotfiles: dotfiles.tar.gz ($DOTFILES_STATUS)"
        echo "packages_file: packages.txt ($PACKAGES_STATUS)"
        echo "system_config: apt-sources.tar.gz ($SYSCONFIG_STATUS)"
        echo "directory_tree: directory-tree.txt ($DIRTREE_STATUS)"
        echo "git_repos: git-repos.txt ($GITREPOS_STATUS)"
    } > "$BACKUP_DIR/MANIFEST.txt"

    cat > "$BACKUP_DIR/manifest.json" << JSONEOF
{
  "schema_version": 1,
  "created_at": "$(json_escape "$created")",
  "host": "$(json_escape "$host")",
  "user": "$(json_escape "$user")",
  "os": "$(json_escape "$os")",
  "modules": {
    "dotfiles": {"status": "$DOTFILES_STATUS", "path": "dotfiles.tar.gz"},
    "packages": {"status": "$PACKAGES_STATUS", "path": "packages.txt"},
    "sysconfig": {"status": "$SYSCONFIG_STATUS", "path": "apt-sources.tar.gz"},
    "directory_tree": {"status": "$DIRTREE_STATUS", "path": "directory-tree.txt"},
    "git_repos": {"status": "$GITREPOS_STATUS", "path": "git-repos.txt"}
  }
}
JSONEOF
    ok "MANIFEST.txt 和 manifest.json 已生成"
}

update_latest_link() {
    if ! ln -sfn "$BACKUP_DIR" "$BACKUP_BASE/latest"; then
        fail "更新 latest 符号链接失败"
        return 1
    fi
    ok "符号链接已更新: latest → $BACKUP_DIR"
}

for arg in "$@"; do
    case "$arg" in
        --help) show_help; exit 0 ;;
        *) warn "未知参数: $arg"; exit 1 ;;
    esac
done

echo ""
echo "################################################"
echo "#  envbat 备份工具                             #"
echo "#  → $BACKUP_BASE"
echo "################################################"
echo ""

stage_required "create backup directory" create_backup_dir || { stage_summary; exit 1; }
stage_optional "dotfiles" backup_dotfiles
stage_optional "packages" backup_packages
stage_optional "system config" backup_sysconfig
stage_optional "directory tree" backup_directory_tree
stage_optional "git repos" backup_git_repos
stage_required "manifest" write_manifests || { stage_summary; exit 1; }
stage_required "latest symlink" update_latest_link || { stage_summary; exit 1; }

stage_summary

total_size=$(du -sh "$BACKUP_DIR" 2>/dev/null | cut -f1)
echo ""
echo "========================================"
echo " ✅ 备份完成"
echo ""
echo "  位置:      $BACKUP_DIR"
echo "  大小:      ${total_size:-unknown}"
echo "  时间:      $(date '+%Y-%m-%d %H:%M:%S')"
echo "========================================"

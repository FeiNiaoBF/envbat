#!/usr/bin/env bash
# === envbat — Restore Tool ===
# Restores user state from /data/backups/envbat. System restore is opt-in.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/interactive.sh"
source "$SCRIPT_DIR/runner.sh"

BACKUP_BASE="/data/backups/envbat"
INTERACTIVE=false
RESTORE_DATE=""
RESTORE_DIR=""
RESTORE_DIR_REAL=""
SAFE_DIR=""

has_dotfiles=false
has_packages=false
has_sysconfig=false
has_dirtree=false
has_gitrepos=false
has_manifest=false

show_help() {
    echo "用法: $0 [选项]"
    echo ""
    echo "选项:"
    echo "  -i            交互模式 — 逐项确认是否恢复"
    echo "  -d <时间戳>    指定备份日期 (如 2026-06-14T1530+0800)"
    echo "  --help        显示帮助"
}

parse_args() {
    while [ $# -gt 0 ]; do
        case "$1" in
            -i) INTERACTIVE=true; shift ;;
            -d)
                if [ $# -lt 2 ]; then
                    fail "-d 需要时间戳参数"
                    return 1
                fi
                RESTORE_DATE="$2"
                shift 2
                ;;
            --help|-h) show_help; exit 0 ;;
            *) warn "未知参数: $1"; return 1 ;;
        esac
    done
}

restore_precheck() {
    if [ -n "$RESTORE_DATE" ]; then
        RESTORE_DIR="$BACKUP_BASE/$RESTORE_DATE"
    else
        RESTORE_DIR="$BACKUP_BASE/latest"
    fi

    if [ ! -d "$RESTORE_DIR" ]; then
        fail "备份目录不存在: $RESTORE_DIR"
        return 1
    fi

    RESTORE_DIR_REAL=$(cd "$RESTORE_DIR" && pwd)
    [ -f "$RESTORE_DIR/manifest.json" ] && has_manifest=true
    [ -f "$RESTORE_DIR/dotfiles.tar.gz" ] && has_dotfiles=true
    [ -f "$RESTORE_DIR/packages.txt" ] && has_packages=true
    [ -f "$RESTORE_DIR/apt-sources.tar.gz" ] && has_sysconfig=true
    [ -f "$RESTORE_DIR/directory-tree.txt" ] && has_dirtree=true
    [ -f "$RESTORE_DIR/git-repos.txt" ] && has_gitrepos=true

    info "恢复来源: $RESTORE_DIR_REAL"
    if $has_manifest; then
        echo "  [OK]  manifest.json"
    else
        echo "  [SKIP] manifest.json 不存在，使用旧备份文件探测"
    fi

    echo "--- 备份内容 ---"
    $has_dotfiles && echo "  [found] dotfiles" || echo "  [miss]  dotfiles"
    $has_packages && echo "  [found] 包列表" || echo "  [miss]  包列表"
    $has_sysconfig && echo "  [found] 系统配置" || echo "  [miss]  系统配置"
    $has_dirtree && echo "  [found] 目录结构" || echo "  [miss]  目录结构"
    $has_gitrepos && echo "  [found] Git 仓库列表" || echo "  [miss]  Git 仓库列表"

    if ! ask_yes_no "开始恢复用户态内容?" "Y"; then
        info "已取消"
        return 1
    fi
}

create_safety_snapshot() {
    SAFE_DIR="/tmp/envbat-restore-backup-$(date +%Y%m%d%H%M%S)"
    mkdir -p "$SAFE_DIR"

    for item in "$HOME/.bashrc" "$HOME/.zshrc" "$HOME/.gitconfig" "$HOME/.gitignore_global" "$HOME/.ssh" "$HOME/.config/nvim" "$HOME/.config/envbat/profile.sh"; do
        if [ -e "$item" ]; then
            local rel="${item#$HOME/}"
            local dest="$SAFE_DIR/$rel"
            mkdir -p "$(dirname "$dest")"
            cp -a "$item" "$dest" 2>/dev/null || true
        fi
    done

    ok "当前文件已备份到: $SAFE_DIR"
    echo "  如需回滚: cp -a $SAFE_DIR/. ~/"
}

extract_dotfiles() {
    local tmp_dir="$1"
    tar -xzf "$RESTORE_DIR/dotfiles.tar.gz" -C "$tmp_dir"
}

restore_dotfiles() {
    local tmp_dir
    tmp_dir=$(mktemp -d)
    if ! extract_dotfiles "$tmp_dir"; then
        rm -rf "$tmp_dir"
        fail "dotfiles 解压失败"
        return 1
    fi

    for item in .bashrc .zshrc .gitconfig .gitignore_global; do
        if [ -f "$tmp_dir/$item" ]; then
            cp "$tmp_dir/$item" "$HOME/$item"
            echo "  [OK]  ~/$item"
        fi
    done

    if [ -f "$tmp_dir/envbat/profile.sh" ]; then
        mkdir -p "$HOME/.config/envbat"
        cp "$tmp_dir/envbat/profile.sh" "$HOME/.config/envbat/profile.sh"
        echo "  [OK]  envbat profile"
    fi

    if [ -d "$tmp_dir/nvim" ]; then
        mkdir -p "$HOME/.config"
        rm -rf "$HOME/.config/nvim"
        cp -a "$tmp_dir/nvim" "$HOME/.config/"
        echo "  [OK]  Neovim 配置"
    fi

    if [ -d "$tmp_dir/oh-my-zsh-custom" ]; then
        mkdir -p "$HOME/.oh-my-zsh/custom"
        cp -a "$tmp_dir/oh-my-zsh-custom/." "$HOME/.oh-my-zsh/custom/"
        echo "  [OK]  oh-my-zsh 自定义"
    fi

    rm -rf "$tmp_dir"
    ok "用户态 dotfiles 恢复完成"
}

restore_ssh() {
    local tmp_dir
    tmp_dir=$(mktemp -d)
    if ! extract_dotfiles "$tmp_dir"; then
        rm -rf "$tmp_dir"
        fail "dotfiles 解压失败，无法恢复 SSH"
        return 1
    fi

    if [ ! -d "$tmp_dir/ssh" ]; then
        rm -rf "$tmp_dir"
        echo "  [SKIP] 备份中没有 SSH 目录"
        return 0
    fi

    if ! ask_yes_no "检测到 SSH 备份，是否恢复 ~/.ssh? 这会覆盖当前 SSH 文件" "N"; then
        rm -rf "$tmp_dir"
        echo "  [SKIP] 用户跳过 SSH 恢复"
        return 0
    fi

    mkdir -p "$HOME/.ssh"
    cp -a "$tmp_dir/ssh/." "$HOME/.ssh/"
    chmod 700 "$HOME/.ssh"
    [ -f "$HOME/.ssh/id_ed25519" ] && chmod 600 "$HOME/.ssh/id_ed25519"
    [ -f "$HOME/.ssh/id_ed25519.pub" ] && chmod 644 "$HOME/.ssh/id_ed25519.pub"
    rm -rf "$tmp_dir"
    ok "SSH 已恢复"
}

restore_directory_tree() {
    while IFS= read -r dir; do
        [ -z "$dir" ] && continue
        if [ ! -d "$dir" ]; then
            mkdir -p "$dir"
            echo "  [CREATE] $dir"
        else
            echo "  [EXISTS] $dir"
        fi
    done < "$RESTORE_DIR/directory-tree.txt"
    ok "目录结构恢复完成"
}

restore_git_repos() {
    while IFS= read -r line; do
        local repo_path repo_url target
        repo_path=$(echo "$line" | sed -n 's/^\[\(.*\)\] \(.*\)$/\1/p')
        repo_url=$(echo "$line" | sed -n 's/^\[\(.*\)\] \(.*\)$/\2/p')
        if [ -z "$repo_path" ] || [ -z "$repo_url" ]; then
            continue
        fi
        target="$HOME/$repo_path"
        if [ -d "$target/.git" ]; then
            echo "  [SKIP] $repo_path (已存在，不 pull)"
        else
            mkdir -p "$(dirname "$target")"
            if git clone "$repo_url" "$target"; then
                echo "  [CLONE] $repo_path"
            else
                warn "克隆失败: $repo_path"
            fi
        fi
    done < "$RESTORE_DIR/git-repos.txt"
    ok "Git 仓库恢复完成"
}

restore_sysconfig() {
    if ! ask_yes_no "高级选项：恢复 apt sources/hosts/hostname/crontab? 默认不建议" "N"; then
        echo "  [SKIP] 用户跳过系统配置恢复"
        return 0
    fi

    local tmp_dir
    tmp_dir=$(mktemp -d)
    if ! tar -xzf "$RESTORE_DIR/apt-sources.tar.gz" -C "$tmp_dir"; then
        rm -rf "$tmp_dir"
        fail "系统配置解压失败"
        return 1
    fi

    if [ -f "$tmp_dir/apt/sources.list" ]; then
        sudo cp "$tmp_dir/apt/sources.list" /etc/apt/sources.list
        echo "  [OK]  apt sources.list"
    fi
    if [ -d "$tmp_dir/apt/sources.list.d" ]; then
        sudo cp -a "$tmp_dir/apt/sources.list.d/." /etc/apt/sources.list.d/
        echo "  [OK]  apt sources.list.d"
    fi
    if [ -f "$tmp_dir/crontab.txt" ] && [ -s "$tmp_dir/crontab.txt" ]; then
        crontab "$tmp_dir/crontab.txt"
        echo "  [OK]  crontab"
    fi
    if [ -f "$tmp_dir/hostname" ]; then
        sudo cp "$tmp_dir/hostname" /etc/hostname
        echo "  [OK]  hostname"
    fi
    if [ -f "$tmp_dir/hosts" ]; then
        sudo cp "$tmp_dir/hosts" /etc/hosts
        echo "  [OK]  hosts"
    fi
    rm -rf "$tmp_dir"
}

restore_packages() {
    if ! ask_yes_no "高级选项：完整恢复 apt 包选择? 默认不建议" "N"; then
        echo "  [SKIP] 用户跳过包列表恢复"
        return 0
    fi
    sudo dpkg --clear-selections
    sudo dpkg --set-selections < "$RESTORE_DIR/packages.txt"
    sudo apt-get dselect-upgrade -y
}

maybe_run_repair() {
    if ask_yes_no "是否现在运行 ./popos/setup.sh --repair 补装依赖?" "N"; then
        "$SCRIPT_DIR/setup.sh" --repair
    else
        echo "  [SKIP] 用户稍后手动运行 setup repair"
    fi
}

parse_args "$@"

echo ""
echo "################################################"
echo "#  envbat 恢复工具                             #"
echo "################################################"
echo ""

stage_required "restore precheck" restore_precheck || { stage_summary; exit 1; }
stage_required "safety snapshot" create_safety_snapshot || { stage_summary; exit 1; }

$has_dotfiles && stage_optional "dotfiles" restore_dotfiles || stage_skip "dotfiles" "backup missing"
$has_dotfiles && stage_optional "ssh" restore_ssh || stage_skip "ssh" "backup missing"
$has_dirtree && stage_optional "directory tree" restore_directory_tree || stage_skip "directory tree" "backup missing"
$has_gitrepos && stage_optional "git repos" restore_git_repos || stage_skip "git repos" "backup missing"

if $INTERACTIVE && $has_sysconfig; then
    stage_optional "system config advanced" restore_sysconfig
else
    stage_skip "system config advanced" "default skip"
fi

if $INTERACTIVE && $has_packages; then
    stage_optional "packages advanced" restore_packages
else
    stage_skip "packages advanced" "default skip"
fi

stage_optional "setup repair prompt" maybe_run_repair
stage_summary

echo ""
echo "========================================"
echo " ✅ 恢复流程完成"
echo ""
echo "  来源: $RESTORE_DIR_REAL"
echo "  原始文件备份在: $SAFE_DIR"
echo "  如需回滚:"
echo "    cp -a $SAFE_DIR/. ~/"
echo "========================================"

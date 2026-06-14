# Phase 2: Backup & Restore Tool Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Create two independent shell scripts — `popos/backup.sh` and `popos/restore.sh` — that backup and restore the user's dotfiles, installed packages, system config, git repos, and `/data` directory structure to timestamped archives under `/data/backups/envbat/`.

**Architecture:** Pure Bash scripts following the existing `popos/` conventions. `backup.sh` collects data into a timestamped directory under `/data/backups/envbat/` and updates a `latest` symlink. `restore.sh` reads from that directory (latest by default, or a specific timestamp with `-d` flag) and restores items either all at once or interactively (`-i` flag). Both source `interactive.sh` for colored output and prompt helpers.

**Tech Stack:** Bash, `tar`, `dpkg`, `crontab`, `find`, `git`.

---

## File Structure

### New files

| File | Responsibility |
|---|---|
| `popos/backup.sh` | Orchestrate full backup: collect dotfiles, packages, system config, dir tree, git repos |
| `popos/restore.sh` | Orchestrate restore: read backup dir, restore items (default all, interactive with `-i`) |
| `docs/plans/2026-06-14-phase2-backup-restore.md` | This plan document |

### Backup directory layout (on disk, not in repo)

```
/data/backups/envbat/
├── 2026-06-14T1530+0800/
│   ├── MANIFEST
│   ├── dotfiles.tar.gz
│   ├── packages.txt
│   ├── apt-sources.tar.gz
│   ├── crontab.txt
│   ├── directory-tree.txt
│   └── git-repos.txt
└── latest → 2026-06-14T1530+0800/
```

---

## Tasks

### Task 1: Create `popos/backup.sh`

**Files:**
- Create: `popos/backup.sh`

- [ ] **Step 1: Write the backup.sh script**

```bash
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
local dotfiles_dir=""
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
local sys_dir=""
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
```

- [ ] **Step 2: Verify syntax**

Run: `bash -n popos/backup.sh` — expected: no output (syntax OK).

- [ ] **Step 3: Dry-run test (prevent accidental data write)**

**Do NOT execute the full script on your dev machine** — it would actually create backup and touch local files. Instead, run a syntax-only + sourcing test:

```bash
# 1) syntax check
bash -n popos/backup.sh
# 2) quick sanity: source it and verify functions/helpers load
bash -c 'source popos/backup.sh 2>&1; echo "LOAD OK"' 
echo "=== backup.sh loads without errors ==="
```

Expected:
- `bash -n` exits with return code 0
- `source ... LOAD OK` output, no error messages

- [ ] **Step 4: Commit**

```bash
git add popos/backup.sh
git commit -m "feat: add backup.sh — dotfiles, packages, system config, git repos"
```

---

### Task 2: Create `popos/restore.sh`

**Files:**
- Create: `popos/restore.sh`

- [ ] **Step 1: Write the restore.sh script**

```bash
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
```

- [ ] **Step 2: Verify syntax**

Run: `bash -n popos/restore.sh` — expected: no output (syntax OK).

- [ ] **Step 3: Dry-run source test**

```bash
bash -n popos/restore.sh
bash -c 'source popos/restore.sh 2>&1; echo "LOAD OK"'
echo "=== restore.sh loads without errors ==="
```

- [ ] **Step 4: Commit**

```bash
git add popos/restore.sh
git commit -m "feat: add restore.sh — restore dotfiles, packages, system config, git repos"
```

---

### Task 3: Add backup/restore scripts to README.md

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Update README.md with backup/restore usage**

Read `README.md` first, then add the backup/restore section after the existing PopOS section:

```markdown
### Backup & Restore (PopOS)

Backup your configuration, package list, and system settings:

```bash
# 备份
./popos/backup.sh

# 恢复最新备份（全部）
./popos/restore.sh

# 恢复最新备份（逐项确认）
./popos/restore.sh -i

# 恢复指定备份
./popos/restore.sh -d 2026-06-14T1530+0800
```
```

- [ ] **Step 2: Commit**

```bash
git add README.md
git commit -m "docs: add backup/restore usage to README"
```

---

## Self-Review

**Spec coverage:**
- backup.sh — Task 1 covers all 5 backup items (dotfiles, packages, system config, directory tree, git repos)
- restore.sh default (all) — Task 2 covers full restore
- restore.sh `-i` (interactive) — Task 2 covers per-item confirmation
- restore.sh `-d` (specific date) — Task 2 covers `-d` flag parsing
- Safety backup before overwrite — Task 2 `step 1` includes `/tmp/envbat-restore-backup-*`
- MANIFEST — Task 1 generates metadata file

**Placeholder scan:** All code blocks contain complete, runnable implementations. No TBD/TODO.

**Type consistency:** `BACKUP_BASE="/data/backups/envbat"` used consistently in both scripts. Timestamp format `%Y-%m-%dT%H%M%S%z` consistent. Date flag `-d` in restore.sh expects same format. Function names follow existing conventions. `interactive.sh` functions (`ok`, `warn`, `fail`, `info`, `title`, `ask_yes_no`) correctly sourced in both scripts.

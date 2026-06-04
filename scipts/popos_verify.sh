#!/usr/bin/env bash
# === PopOS: Verify Setup ===
# Source this from setup-popos.sh only.

popos_verify() {
    echo "========================================"
    echo " [5/5] 验证配置"
    echo "========================================"

    # --- Directory structure ---
    echo ">>> /data 目录结构:"
    local top_dirs
    top_dirs="$(find /data -maxdepth 1 -type d | wc -l)"
    local all_dirs
    all_dirs="$(find /data -type d | wc -l)"
    echo "  顶层目录: $top_dirs | 总计目录: $all_dirs"
    echo ""

    # --- Symlinks ---
    echo ">>> 符号链接:"
    local symlinks_ok=0 symlinks_miss=0
    for name in Code Projects Experiments Data Datasets Models Tools Library Shared Backups; do
        local path="$HOME/$name"
        if [ -L "$path" ]; then
            local target
            target="$(readlink "$path")"
            echo "  [OK]  ~/$name → $target"
            ((symlinks_ok++))
        else
            echo "  [MISS] ~/$name"
            ((symlinks_miss++))
        fi
    done
    echo "  $symlinks_ok OK, $symlinks_miss missing"
    echo ""

    # --- Env vars ---
    echo ">>> 环境变量:"
    for var in DATA_HOME CODE_HOME TOOLS_HOME HF_HOME CARGO_HOME TMPDIR; do
        if [ -n "${!var:-}" ]; then
            echo "  [OK]  $var=${!var}"
        else
            echo "  [MISS] $var (未设置)"
        fi
    done
    echo ""

    # --- Installed tools ---
    echo ">>> 基础工具:"
    local tools_tools=(git curl wget gcc make htop neofetch tree rg fdfind unzip tar)
    local tools_ok=0 tools_miss=0
    for cmd in "${tools_tools[@]}"; do
        if command -v "$cmd" &>/dev/null; then
            echo "  [OK]  $cmd"
            ((tools_ok++))
        else
            echo "  [MISS] $cmd"
            ((tools_miss++))
        fi
    done
    echo "  $tools_ok OK, $tools_miss missing"
    echo ""
}

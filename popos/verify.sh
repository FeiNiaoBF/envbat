#!/usr/bin/env bash
# === PopOS: Verify Setup ===
# Source this from setup-popos.sh only.

popos_verify() {
    echo "========================================"
    echo " [5/5] 验证配置"
    echo "========================================"

    # --- Directory structure ---
    if [ ! -d "/data" ]; then
        echo "  [SKIP] /data 目录不存在，跳过目录结构验证"
        echo ""
    else
        echo ">>> /data 目录结构:"
        local top_dirs
        top_dirs="$(find /data -maxdepth 1 -type d 2>/dev/null | wc -l)"
        local all_dirs
        all_dirs="$(find /data -type d 2>/dev/null | wc -l)"
        echo "  顶层目录: $top_dirs | 总计目录: $all_dirs"
        echo ""
    fi

    # --- Symlinks ---
    echo ">>> 符号链接:"
    local symlinks_ok=0 symlinks_miss=0
    for name in Code Projects Data Tools Experiments Datasets Models Library Shared Backups; do
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

    # --- Profile ---
    echo ">>> 配置文件:"
    if [ -f "$HOME/.config/envbat/profile.sh" ]; then
        echo "  [OK]  配置文件存在: ~/.config/envbat/profile.sh"
    else
        echo "  [MISS] 配置文件不存在"
    fi
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
    local tools_tools=(git curl wget gcc make htop neofetch tree rg fdfind unzip tar fzf zoxide)
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

    # --- Development tools (chosen during setup) ---
    echo ">>> 开发工具:"
    local lang_tools=()
    if [ "${INSTALL_GO:-false}" = true ]; then
        lang_tools+=(go)
    fi
    if [ "${INSTALL_NVM_NODE:-false}" = true ]; then
        lang_tools+=(node npm)
    fi
    if [ "${INSTALL_RUSTUP:-false}" = true ]; then
        lang_tools+=(rustc cargo)
    fi
    if [ "${INSTALL_NEOVIM:-false}" = true ]; then
        lang_tools+=(nvim)
    fi
    if [ "${INSTALL_DOCKER:-false}" = true ]; then
        lang_tools+=(docker)
    fi
    if [ "${INSTALL_JAVA:-skip}" != "skip" ]; then
        lang_tools+=(java javac)
    fi

    if [ ${#lang_tools[@]} -eq 0 ]; then
        echo "  (未选择开发工具)"
    else
        local dev_ok=0 dev_miss=0
        for cmd in "${lang_tools[@]}"; do
            if command -v "$cmd" &>/dev/null || [ -x "$HOME/Tools/bin/$cmd" ]; then
                echo "  [OK]  $cmd"
                ((dev_ok++))
            else
                echo "  [MISS] $cmd"
                ((dev_miss++))
            fi
        done
        echo "  $dev_ok OK, $dev_miss missing"
    fi
    echo ""
}

popos_summary() {
    echo "========================================"
    echo " 📋 系统状态摘要"
    echo "========================================"

    # Disk
    if [ -d /data ]; then
        local data_used data_total data_pct
        data_used=$(df -h /data 2>/dev/null | awk 'NR==2{print $3}')
        data_total=$(df -h /data 2>/dev/null | awk 'NR==2{print $2}')
        data_pct=$(df -h /data 2>/dev/null | awk 'NR==2{print $5}')
        echo "  /data:    ${data_used} / ${data_total} (${data_pct})"
    fi
    local root_used root_total root_pct
    root_used=$(df -h / 2>/dev/null | awk 'NR==2{print $3}')
    root_total=$(df -h / 2>/dev/null | awk 'NR==2{print $2}')
    root_pct=$(df -h / 2>/dev/null | awk 'NR==2{print $5}')
    echo "  系统盘:   ${root_used} / ${root_total} (${root_pct})"

    # Memory
    local mem_total mem_used
    mem_total=$(free -h 2>/dev/null | awk 'NR==2{print $2}')
    mem_used=$(free -h 2>/dev/null | awk 'NR==2{print $3}')
    echo "  内存:     ${mem_used} / ${mem_total}"

    # Uptime
    local uptime_str
    uptime_str=$(uptime -p 2>/dev/null | sed 's/up //')
    echo "  运行时间: ${uptime_str}"

    # Shell
    echo "  默认 Shell: $SHELL"

    # Profile
    if [ -f "$HOME/.config/envbat/profile.sh" ]; then
        echo "  配置文件: ✅ 已保存"
    fi

    # Symlink check
    local sym_ok=0 sym_total=0
    for name in Code Projects Data Tools; do
        [ -L "$HOME/$name" ] && ((sym_ok++))
        ((sym_total++))
    done
    echo "  符号链接: ${sym_ok}/${sym_total} 有效"
    echo ""
}

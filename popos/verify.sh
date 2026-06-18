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
            symlinks_ok=$((symlinks_ok + 1))
        else
            echo "  [MISS] ~/$name"
            symlinks_miss=$((symlinks_miss + 1))
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
    echo ">>> 必需基础工具:"
    local required_tools=(git curl wget gcc make unzip tar zsh)
    local tools_ok=0 tools_miss=0
    for cmd in "${required_tools[@]}"; do
        if command -v "$cmd" &>/dev/null; then
            echo "  [OK]  $cmd"
            tools_ok=$((tools_ok + 1))
        else
            echo "  [MISS] $cmd"
            tools_miss=$((tools_miss + 1))
        fi
    done
    echo "  $tools_ok OK, $tools_miss missing"
    echo ""

    echo ">>> 可选基础工具:"
    local optional_tools=(htop neofetch tree rg fdfind fzf zoxide)
    local opt_ok=0 opt_miss=0
    for cmd in "${optional_tools[@]}"; do
        if command -v "$cmd" &>/dev/null; then
            echo "  [OK]  $cmd"
            opt_ok=$((opt_ok + 1))
        else
            echo "  [MISS] $cmd"
            opt_miss=$((opt_miss + 1))
        fi
    done
    echo "  $opt_ok OK, $opt_miss missing"
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
                dev_ok=$((dev_ok + 1))
            else
                echo "  [MISS] $cmd"
                dev_miss=$((dev_miss + 1))
            fi
        done
        echo "  $dev_ok OK, $dev_miss missing"
    fi
    echo ""

    # --- Shell setup ---
    if [ "${INSTALL_OHMYZSH:-false}" = true ]; then
        echo ">>> Zsh / oh-my-zsh:"
        local login_shell
        login_shell="$(getent passwd "$USER" 2>/dev/null | cut -d: -f7 || true)"
        if command -v zsh &>/dev/null; then
            echo "  [OK]  zsh"
        else
            echo "  [MISS] zsh"
        fi
        if [ -d "$HOME/.oh-my-zsh" ]; then
            echo "  [OK]  ~/.oh-my-zsh"
        else
            echo "  [MISS] ~/.oh-my-zsh"
        fi
        if [ "${login_shell##*/}" = "zsh" ]; then
            echo "  [OK]  默认 shell: $login_shell"
        else
            echo "  [MISS] 默认 shell 不是 zsh: ${login_shell:-unknown}"
        fi
        echo ""
    fi

    # --- Chinese input method ---
    if [ "${INSTALL_CHINESE:-false}" = true ]; then
        echo ">>> 中文输入法:"
        if locale -a 2>/dev/null | grep -qi '^zh_CN\.utf8$'; then
            echo "  [OK]  zh_CN.UTF-8 locale"
        else
            echo "  [MISS] zh_CN.UTF-8 locale"
        fi
        if command -v fcitx5 &>/dev/null; then
            echo "  [OK]  fcitx5"
        else
            echo "  [MISS] fcitx5"
        fi
        if [ -f "$HOME/.xinputrc" ] && grep -q fcitx5 "$HOME/.xinputrc" 2>/dev/null; then
            echo "  [OK]  im-config: fcitx5"
        else
            echo "  [MISS] im-config 未设置为 fcitx5"
        fi
        if [ -f "$HOME/.config/autostart/org.fcitx.Fcitx5.desktop" ] || [ -f "$HOME/.config/autostart/fcitx5.desktop" ]; then
            echo "  [OK]  fcitx5 自启动"
        else
            echo "  [MISS] fcitx5 自启动"
        fi
        echo ""
    fi

    if [ "${tools_miss:-0}" -gt 0 ]; then
        return 1
    fi
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

    # Security
    echo "  防火墙: $(sudo ufw status 2>/dev/null | head -1 || echo '未安装')"
    echo "  Fail2ban: $(systemctl is-active fail2ban 2>/dev/null || echo '未安装')"

    # Profile
    if [ -f "$HOME/.config/envbat/profile.sh" ]; then
        echo "  配置文件: ✅ 已保存"
    fi

    # Symlink check
    local sym_ok=0 sym_total=0
    for name in Code Projects Data Tools; do
        [ -L "$HOME/$name" ] && sym_ok=$((sym_ok + 1))
        sym_total=$((sym_total + 1))
    done
    echo "  符号链接: ${sym_ok}/${sym_total} 有效"

    # Env vars (from profile)
    echo ""
    echo "--- 环境变量 ---"
    for var in DATA_HOME CODE_HOME TOOLS_HOME HF_HOME CARGO_HOME TMPDIR; do
        if [ -n "${!var:-}" ]; then
            echo "  [OK]  $var=${!var}"
        else
            echo "  [MISS] $var"
        fi
    done
    echo ""
}

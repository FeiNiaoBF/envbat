#!/usr/bin/env bash
# === PopOS 开发环境 — 交互式一键配置 ===
# 使用方式:
#   chmod +x popos/setup.sh
#   sudo ./popos/setup.sh
#
# 首次运行：一问一答引导式，保存配置后自动安装。
# 再次运行：检测到已有配置自动跳过问答，按上次选择执行。
# ============================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load all modules
source "$SCRIPT_DIR/interactive.sh"
source "$SCRIPT_DIR/check.sh"
source "$SCRIPT_DIR/directories.sh"
source "$SCRIPT_DIR/profile.sh"
source "$SCRIPT_DIR/install.sh"
source "$SCRIPT_DIR/lang.sh"
source "$SCRIPT_DIR/neovim.sh"
source "$SCRIPT_DIR/docker.sh"
source "$SCRIPT_DIR/shell.sh"
source "$SCRIPT_DIR/ssh.sh"
source "$SCRIPT_DIR/config.sh"
source "$SCRIPT_DIR/verify.sh"
source "$SCRIPT_DIR/mirror.sh"
source "$SCRIPT_DIR/utils.sh"

# ============================================================
# Interactive Questions
# ============================================================
popos_ask_questions() {
    title "安装基础路径"
    if [ -d "/data" ]; then
        INSTALL_BASE="/data"
        ok "检测到 /data 分区"
    else
        ask_input "未检测到 /data 分区，请输入安装基础目录" "/home/$(whoami)/dev" INSTALL_BASE
    fi
    echo "  安装基础: $INSTALL_BASE"
    echo ""

    title "开发语言"
    ask_yes_no "安装 Go 语言?" "Y" && INSTALL_GO=true || INSTALL_GO=false
    ask_yes_no "安装 Node.js (via nvm)?" "Y" && INSTALL_NVM_NODE=true || INSTALL_NVM_NODE=false
    ask_yes_no "安装 Python (via pyenv)?" "Y" && INSTALL_PYENV=true || INSTALL_PYENV=false
    ask_yes_no "安装 Rust (via rustup)?" "Y" && INSTALL_RUSTUP=true || INSTALL_RUSTUP=false
    ask_select "Java 版本?" INSTALL_JAVA "skip" "11" "17" "21"
    echo ""

    title "编辑器与工具"
    ask_yes_no "安装 Neovim?" "Y" && INSTALL_NEOVIM=true || INSTALL_NEOVIM=false
    ask_yes_no "安装 Docker?" "Y" && INSTALL_DOCKER=true || INSTALL_DOCKER=false
    ask_yes_no "安装 oh-my-zsh + Powerlevel10k? (会切换默认 shell 为 zsh)" "Y" && INSTALL_OHMYZSH=true || INSTALL_OHMYZSH=false
    echo ""

    title "SSH 密钥"
    ask_select "SSH 密钥设置" INSTALL_SSH "generate" "restore" "skip"
    echo ""

    title "Git 配置"
    ask_input "Git 用户名" "${GIT_USER_NAME:-}" GIT_USER_NAME
    ask_input "Git 邮箱" "${GIT_USER_EMAIL:-}" GIT_USER_EMAIL
    echo ""

    title "额外工具"
    ask_yes_no "安装额外工具 (ripgrep, fd-find, fzf, zoxide)?" "Y" && INSTALL_EXTRA_TOOLS=true || INSTALL_EXTRA_TOOLS=false
    echo ""

    # Detect Go latest version for profile
    if [ "$INSTALL_GO" = true ]; then
        GO_VERSION=$(curl -sL 'https://go.dev/dl/?mode=json' | grep -oP '"version": "\K[^"]+' | head -1 2>/dev/null || echo "")
    fi
}

# ============================================================
# Main
# ============================================================
echo ""
echo "################################################"
echo "#  PopOS 开发环境 - 交互式一键配置              #"
echo "#  Phase 1: 语言运行时 + 工具 + 桌面配置        #"
echo "################################################"
echo ""

# ---- Pre-check ----
popos_check_system

# ---- Profile (interactive or load) ----
popos_load_profile && PROFILE_EXISTS=true || PROFILE_EXISTS=false

if [ "$PROFILE_EXISTS" = true ]; then
    if ! ask_yes_no "检测到已有配置，是否重新配置?" "N"; then
        echo "  使用现有配置继续安装"
    else
        popos_ask_questions
        popos_save_profile
    fi
else
    popos_ask_questions
    popos_save_profile
fi

# Clean old env vars from .bashrc
popos_clean_old_bashrc

# ============================================================
# Execute
# ============================================================
title "开始安装"

popos_create_dirs
popos_ensure_symlinks
popos_cleanup_flatpak

popos_install_tools

popos_install_languages

if [ "$INSTALL_NEOVIM" = true ]; then
    popos_install_neovim
    popos_install_nerd_font
fi

if [ "$INSTALL_DOCKER" = true ]; then
    popos_install_docker
fi

if [ "$INSTALL_OHMYZSH" = true ]; then
    popos_install_ohmyzsh
fi

popos_setup_ssh
popos_config_shell_chain

# ============================================================
# Verify + Summary
# ============================================================
popos_verify

echo "========================================"
echo " ✅ PopOS 环境配置完成！"
echo ""
echo "  下一步:"
echo "    重新登录或执行: source ~/.zshrc"
echo "    SSH 公钥: cat ~/.ssh/id_ed25519.pub"
echo "    终端字体请设为 JetBrainsMono Nerd Font"
echo "========================================"

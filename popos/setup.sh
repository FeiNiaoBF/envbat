#!/usr/bin/env bash
# === PopOS 开发环境 — 交互式一键配置 ===
# 使用方式:
#   chmod +x popos/setup.sh
#   ./popos/setup.sh
#   ./popos/setup.sh --repair   # 复用已保存 profile，非交互补装/修复
# ============================================================
set -euo pipefail

REPAIR_MODE=false

show_help() {
    echo "用法: $0 [--repair] [--help]"
    echo ""
    echo "  --repair   复用 ~/.config/envbat/profile.sh，跳过问答并执行阶段化修复"
    echo "  --help     显示帮助"
}

while [ $# -gt 0 ]; do
    case "$1" in
        --repair) REPAIR_MODE=true; shift ;;
        --help|-h) show_help; exit 0 ;;
        *) echo "未知参数: $1"; show_help; exit 1 ;;
    esac
done

if [ "$(id -u)" -eq 0 ]; then
    echo "错误: 不要使用 sudo 运行此脚本。脚本内部会在需要时自动调用 sudo。"
    echo "正确用法: ./popos/setup.sh"
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "$SCRIPT_DIR/runner.sh"
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
source "$SCRIPT_DIR/security.sh"
source "$SCRIPT_DIR/locale.sh"

run_required() {
    if ! stage_required "$@"; then
        stage_summary
        exit 1
    fi
}

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

    if [ "$INSTALL_GO" = true ]; then
        GO_VERSION=$(curl -sL 'https://go.dev/dl/?mode=json' | grep -oP '"version": "\K[^"]+' | head -1 2>/dev/null || echo "")
    fi

    title "安全设置"
    ask_yes_no "开启 UFW 防火墙?" "Y" && INSTALL_UFW=true || INSTALL_UFW=false
    ask_yes_no "安装 Fail2ban (防SSH暴力破解)?" "Y" && INSTALL_FAIL2BAN=true || INSTALL_FAIL2BAN=false
    ask_yes_no "开启自动安全更新?" "Y" && INSTALL_AUTO_UPDATES=true || INSTALL_AUTO_UPDATES=false
    echo ""

    title "中文环境"
    ask_yes_no "配置中文 locale + fcitx5 输入法?" "Y" && INSTALL_CHINESE=true || INSTALL_CHINESE=false
    echo ""

    title "浏览器"
    ask_yes_no "安装 Google Chrome?" "Y" && INSTALL_CHROME=true || INSTALL_CHROME=false
    echo ""
}

popos_prepare_profile() {
    local profile_exists=false
    popos_load_profile && profile_exists=true || profile_exists=false

    if [ "$REPAIR_MODE" = true ]; then
        if [ "$profile_exists" != true ]; then
            fail "repair 模式需要先存在 ~/.config/envbat/profile.sh"
            return 1
        fi
        echo "  使用现有配置执行 repair"
    elif [ "$profile_exists" = true ]; then
        if ask_yes_no "检测到已有配置，是否重新配置?" "N"; then
            popos_ask_questions
            popos_save_profile
        else
            echo "  使用现有配置继续安装"
        fi
    else
        popos_ask_questions
        popos_save_profile
    fi

    popos_clean_old_bashrc
}

popos_setup_directories() {
    popos_create_dirs
    popos_ensure_symlinks
}

echo ""
echo "################################################"
echo "#  PopOS 环境配置 - 阶段化容错安装              #"
echo "################################################"
echo ""

run_required "precheck" popos_check_system
run_required "profile" popos_prepare_profile
run_required "directories" popos_setup_directories

stage_optional "flatpak cleanup" popos_cleanup_flatpak

run_required "base tools" popos_install_tools

if [ "${INSTALL_OHMYZSH:-false}" = true ]; then
    stage_optional "oh-my-zsh + Powerlevel10k" popos_install_ohmyzsh
else
    stage_skip "oh-my-zsh + Powerlevel10k" "user disabled"
fi

[ "${INSTALL_GO:-false}" = true ] && stage_optional "go" popos_install_go || stage_skip "go" "user disabled"
[ "${INSTALL_NVM_NODE:-false}" = true ] && stage_optional "node nvm" popos_install_nvm_node || stage_skip "node nvm" "user disabled"
[ "${INSTALL_PYENV:-false}" = true ] && stage_optional "pyenv" popos_install_pyenv || stage_skip "pyenv" "user disabled"
[ "${INSTALL_RUSTUP:-false}" = true ] && stage_optional "rustup" popos_install_rustup || stage_skip "rustup" "user disabled"
[ "${INSTALL_JAVA:-skip}" != "skip" ] && stage_optional "java" popos_install_java || stage_skip "java" "user disabled"

if [ "${INSTALL_UFW:-false}" = true ] || [ "${INSTALL_FAIL2BAN:-false}" = true ] || [ "${INSTALL_AUTO_UPDATES:-false}" = true ]; then
    stage_optional "security" popos_install_security
else
    stage_skip "security" "user disabled"
fi

[ "${INSTALL_CHINESE:-false}" = true ] && stage_optional "locale input method" popos_setup_locale || stage_skip "locale input method" "user disabled"
[ "${INSTALL_CHROME:-false}" = true ] && stage_optional "chrome" popos_install_chrome || stage_skip "chrome" "user disabled"

if [ "${INSTALL_NEOVIM:-false}" = true ]; then
    stage_optional "neovim" popos_install_neovim
    stage_optional "nerd font" popos_install_nerd_font
else
    stage_skip "neovim" "user disabled"
    stage_skip "nerd font" "user disabled"
fi

[ "${INSTALL_DOCKER:-false}" = true ] && stage_optional "docker" popos_install_docker || stage_skip "docker" "user disabled"

if [ "${INSTALL_SSH:-skip}" != "skip" ]; then
    stage_optional "ssh" popos_setup_ssh
else
    stage_skip "ssh" "user disabled"
fi

run_required "shell loading" popos_config_shell_chain
run_required "verify" popos_verify
stage_optional "system summary" popos_summary

stage_summary

echo ""
echo "========================================"
echo " ✅ PopOS 环境配置流程完成"
echo ""
echo "  下一步:"
echo "    重新登录或执行: source ~/.zshrc"
echo "    SSH 公钥: cat ~/.ssh/id_ed25519.pub"
echo "    终端字体请设为 JetBrainsMono Nerd Font"
echo "========================================"

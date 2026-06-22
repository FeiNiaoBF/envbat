#!/usr/bin/env bash
# === PopOS staged setup ===
set -euo pipefail

REPAIR_MODE=false
RECONFIGURE_MODE=false

show_help() {
    echo "用法: $0 [--repair|--reconfigure] [--help]"
    echo ""
    echo "  --repair       使用现有 profile，非交互修复已选择项目"
    echo "  --reconfigure  使用现有值重新选择并保存配置"
    echo "  --help         显示帮助"
}

while [ $# -gt 0 ]; do
    case "$1" in
        --repair) REPAIR_MODE=true; shift ;;
        --reconfigure) RECONFIGURE_MODE=true; shift ;;
        --help|-h) show_help; exit 0 ;;
        *) echo "未知参数: $1"; show_help; exit 1 ;;
    esac
done

if $REPAIR_MODE && $RECONFIGURE_MODE; then
    echo "错误: --repair 与 --reconfigure 不能同时使用"
    exit 1
fi
if [ "$(id -u)" -eq 0 ]; then
    echo "错误: 不要使用 sudo 运行此脚本；脚本会按需调用 sudo。"
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=popos/runner.sh
source "$SCRIPT_DIR/runner.sh"
# shellcheck source=popos/interactive.sh
source "$SCRIPT_DIR/interactive.sh"
# shellcheck source=popos/check.sh
source "$SCRIPT_DIR/check.sh"
# shellcheck source=popos/directories.sh
source "$SCRIPT_DIR/directories.sh"
# shellcheck source=popos/profile.sh
source "$SCRIPT_DIR/profile.sh"
# shellcheck source=popos/install.sh
source "$SCRIPT_DIR/install.sh"
# shellcheck source=popos/lang.sh
source "$SCRIPT_DIR/lang.sh"
# shellcheck source=popos/neovim.sh
source "$SCRIPT_DIR/neovim.sh"
# shellcheck source=popos/docker.sh
source "$SCRIPT_DIR/docker.sh"
# shellcheck source=popos/shell.sh
source "$SCRIPT_DIR/shell.sh"
# shellcheck source=popos/ssh.sh
source "$SCRIPT_DIR/ssh.sh"
# shellcheck source=popos/config.sh
source "$SCRIPT_DIR/config.sh"
# shellcheck source=popos/verify.sh
source "$SCRIPT_DIR/verify.sh"
# shellcheck source=popos/security.sh
source "$SCRIPT_DIR/security.sh"
# shellcheck source=popos/locale.sh
source "$SCRIPT_DIR/locale.sh"

run_required() {
    if ! stage_required "$@"; then
        stage_finish "PopOS setup" || true
        exit 1
    fi
}

bool_default() {
    local var_name="$1"
    if [ "${!var_name:-false}" = true ]; then
        printf 'Y'
    else
        printf 'N'
    fi
}

ask_bool() {
    local prompt="$1" var_name="$2"
    if ask_yes_no "$prompt" "$(bool_default "$var_name")"; then
        printf -v "$var_name" true
    else
        printf -v "$var_name" false
    fi
}

popos_ask_questions() {
    title "安装基础路径"
    local default_base="${INSTALL_BASE:-}"
    if [ -z "$default_base" ]; then
        [ -d /data ] && default_base=/data || default_base="$HOME/dev"
    fi
    ask_input "安装基础目录" "$default_base" INSTALL_BASE

    title "开发语言"
    ask_bool "安装 Go 语言?" INSTALL_GO
    ask_bool "安装 Node.js (via nvm)?" INSTALL_NVM_NODE
    ask_bool "安装 Python (via pyenv)?" INSTALL_PYENV
    ask_bool "安装 Rust (via rustup)?" INSTALL_RUSTUP
    ask_select "Java 版本?" INSTALL_JAVA "skip" "11" "17" "21"

    title "编辑器与工具"
    ask_bool "安装 Neovim?" INSTALL_NEOVIM
    ask_bool "安装 Docker?" INSTALL_DOCKER
    ask_bool "安装 oh-my-zsh + Powerlevel10k?" INSTALL_OHMYZSH
    ask_bool "安装额外工具 (ripgrep, fd-find, fzf, zoxide)?" INSTALL_EXTRA_TOOLS

    title "SSH 密钥"
    ask_select "SSH 密钥设置" INSTALL_SSH "generate" "skip"

    title "Git 配置"
    ask_input "Git 用户名" "${GIT_USER_NAME:-}" GIT_USER_NAME
    ask_input "Git 邮箱" "${GIT_USER_EMAIL:-}" GIT_USER_EMAIL

    title "安全设置"
    ask_bool "开启 UFW 防火墙?" INSTALL_UFW
    ask_bool "安装 Fail2ban?" INSTALL_FAIL2BAN
    ask_bool "开启自动安全更新?" INSTALL_AUTO_UPDATES

    title "中文环境"
    ask_bool "配置中文 locale + fcitx5 输入法?" INSTALL_CHINESE

    title "浏览器"
    ask_bool "安装 Google Chrome?" INSTALL_CHROME
}

popos_print_selection_summary() {
    echo ""
    echo "========================================"
    echo " 配置摘要"
    echo "========================================"
    printf "  安装目录: %s\n" "$INSTALL_BASE"
    printf "  Go/Node/Python/Rust/Java: %s/%s/%s/%s/%s\n" "$INSTALL_GO" "$INSTALL_NVM_NODE" "$INSTALL_PYENV" "$INSTALL_RUSTUP" "$INSTALL_JAVA"
    printf "  Neovim/Docker/Zsh: %s/%s/%s\n" "$INSTALL_NEOVIM" "$INSTALL_DOCKER" "$INSTALL_OHMYZSH"
    printf "  Security/Chinese/Chrome: %s/%s/%s\n" "$INSTALL_UFW,$INSTALL_FAIL2BAN,$INSTALL_AUTO_UPDATES" "$INSTALL_CHINESE" "$INSTALL_CHROME"
    printf "  SSH: %s\n" "$INSTALL_SSH"
    echo "========================================"
}

popos_prepare_profile() {
    local profile_exists=false
    if popos_load_profile; then
        profile_exists=true
    fi

    if $REPAIR_MODE; then
        if [ "$profile_exists" != true ]; then
            fail "--repair 需要现有的 ~/.config/envbat/profile.sh"
            return 1
        fi
        echo "  使用现有 schema v2 profile 执行 repair"
    elif $RECONFIGURE_MODE; then
        if [ "$profile_exists" != true ]; then
            popos_profile_initial_defaults
        fi
        popos_ask_questions
        popos_print_selection_summary
        if ! ask_yes_no "确认保存并执行以上配置?" "Y"; then
            fail "用户取消重新配置"
            return 1
        fi
        popos_save_profile || return 1
        # shellcheck source=/dev/null
        source "$PROFILE_FILE"
    elif [ "$profile_exists" = true ]; then
        echo "  使用现有配置；如需修改请运行 --reconfigure"
    else
        popos_profile_initial_defaults
        popos_ask_questions
        popos_print_selection_summary
        if ! ask_yes_no "确认保存并开始安装?" "Y"; then
            fail "用户取消安装"
            return 1
        fi
        popos_save_profile || return 1
        # shellcheck source=/dev/null
        source "$PROFILE_FILE"
    fi

    case "$INSTALL_BASE" in
        /*)
            if [ "$INSTALL_BASE" = / ]; then
                fail "INSTALL_BASE 不能是根目录 /"
                return 1
            fi
            ;;
        *)
            fail "INSTALL_BASE 必须是绝对路径: $INSTALL_BASE"
            return 1
            ;;
    esac

    popos_clean_old_bashrc
}

popos_setup_directories() {
    popos_create_dirs || return 1
    popos_ensure_symlinks
}

echo ""
echo "################################################"
echo "#  PopOS 环境配置 - 阶段化容错安装              #"
echo "################################################"

run_required "precheck" popos_check_system
run_required "profile" popos_prepare_profile
run_required "directories" popos_setup_directories
stage_optional "flatpak cleanup" popos_cleanup_flatpak
run_required "base tools" popos_install_tools

if [ "$INSTALL_OHMYZSH" = true ]; then stage_optional "oh-my-zsh + Powerlevel10k" popos_install_ohmyzsh; else stage_skip "oh-my-zsh + Powerlevel10k" "user disabled"; fi
if [ "$INSTALL_GO" = true ]; then stage_optional "go" popos_install_go; else stage_skip "go" "user disabled"; fi
if [ "$INSTALL_NVM_NODE" = true ]; then stage_optional "node nvm" popos_install_nvm_node; else stage_skip "node nvm" "user disabled"; fi
if [ "$INSTALL_PYENV" = true ]; then stage_optional "pyenv" popos_install_pyenv; else stage_skip "pyenv" "user disabled"; fi
if [ "$INSTALL_RUSTUP" = true ]; then stage_optional "rustup" popos_install_rustup; else stage_skip "rustup" "user disabled"; fi
if [ "$INSTALL_JAVA" != skip ]; then stage_optional "java" popos_install_java; else stage_skip "java" "user disabled"; fi

if [ "$INSTALL_UFW" = true ] || [ "$INSTALL_FAIL2BAN" = true ] || [ "$INSTALL_AUTO_UPDATES" = true ]; then stage_optional "security" popos_install_security; else stage_skip "security" "user disabled"; fi
if [ "$INSTALL_CHINESE" = true ]; then stage_optional "locale input method" popos_setup_locale; else stage_skip "locale input method" "user disabled"; fi
if [ "$INSTALL_CHROME" = true ]; then stage_optional "chrome" popos_install_chrome; else stage_skip "chrome" "user disabled"; fi
if [ "$INSTALL_NEOVIM" = true ]; then stage_optional "neovim" popos_install_neovim; stage_optional "nerd font" popos_install_nerd_font; else stage_skip "neovim" "user disabled"; stage_skip "nerd font" "user disabled"; fi
if [ "$INSTALL_DOCKER" = true ]; then stage_optional "docker" popos_install_docker; else stage_skip "docker" "user disabled"; fi
if [ "$INSTALL_SSH" = generate ]; then stage_optional "ssh" popos_setup_ssh; else stage_skip "ssh" "user disabled"; fi

run_required "shell loading" popos_config_shell_chain
run_required "verify" popos_verify
stage_optional "system summary" popos_summary

stage_finish "PopOS setup"
echo ""
echo "下一步: 重新登录，或执行 source ~/.zshrc"

#!/usr/bin/env bash
# === 实用工具函数集 ===
# 从 kejilion.sh 精选的桌面运维工具，适配 PopOS 环境
#
# 包含:
#   popos_install_package  — 智能包安装器（跨包管理器）
#   popos_system_update    — 全量系统更新（含 dpkg 修复）
#   popos_fix_dpkg         — 修复 dpkg 中断锁
#   popos_service          — systemctl 统一封装
#   popos_pause            — 暂停模式（按任意键继续）
#
# 使用方式:
#   source popos/07-utils.sh
#   popos_install_package git neovim htop
#   popos_system_update
#   popos_service status ssh
#   popos_pause
# ============================================================

# ---- 修复 dpkg 中断锁 ----
# 当 apt/dpkg 意外中断时，清理锁文件并强制配置
popos_fix_dpkg() {
    echo "修复 dpkg 中断问题 ..."
    sudo pkill -9 -f 'apt|dpkg' 2>/dev/null || true
    sudo rm -f /var/lib/dpkg/lock-frontend /var/lib/dpkg/lock
    sudo DEBIAN_FRONTEND=noninteractive dpkg --configure -a
    echo "dpkg 修复完成"
}

# ---- 智能包安装器 ----
# 自动检测包管理器安装软件包
# 支持: apt, dnf, yum, apk, pacman, zypper
#
# 使用: popos_install_package <package1> [package2 ...]
# 示例: popos_install_package htop neovim git curl
popos_install_package() {
    if [ $# -eq 0 ]; then
        echo "错误: 未提供软件包名称"
        echo "用法: popos_install_package <package1> [package2 ...]"
        return 1
    fi

    local package installed_all=true
    for package in "$@"; do
        if command -v "$package" &>/dev/null; then
            echo "[跳过] $package 已安装"
            continue
        fi

        echo "正在安装 $package ..."

        if command -v dnf &>/dev/null; then
            sudo dnf install -y "$package"
        elif command -v yum &>/dev/null; then
            sudo yum install -y "$package"
        elif command -v apt &>/dev/null; then
            sudo apt update -y 2>/dev/null
            sudo apt install -y "$package"
        elif command -v apk &>/dev/null; then
            sudo apk add "$package"
        elif command -v pacman &>/dev/null; then
            sudo pacman -S --noconfirm "$package"
        elif command -v zypper &>/dev/null; then
            sudo zypper install -y "$package"
        else
            echo "错误: 未知的包管理器，无法安装 $package"
            installed_all=false
            continue
        fi

        if command -v "$package" &>/dev/null; then
            echo "[完成] $package 安装成功"
        else
            echo "[失败] $package 可能未正确安装 (尝试用 'which $package' 确认)"
        fi
    done

    $installed_all && return 0 || return 1
}

# ---- 系统更新 ----
# 全量更新系统，自动处理 dpkg 中断
popos_system_update() {
    echo "正在执行系统更新 ..."

    if command -v dnf &>/dev/null; then
        sudo dnf -y update
    elif command -v yum &>/dev/null; then
        sudo yum -y update
    elif command -v apt &>/dev/null; then
        popos_fix_dpkg
        sudo DEBIAN_FRONTEND=noninteractive apt update -y
        sudo DEBIAN_FRONTEND=noninteractive apt full-upgrade -y
    elif command -v apk &>/dev/null; then
        sudo apk update && sudo apk upgrade
    elif command -v pacman &>/dev/null; then
        sudo pacman -Syu --noconfirm
    elif command -v zypper &>/dev/null; then
        sudo zypper refresh
        sudo zypper update
    elif command -v opkg &>/dev/null; then
        sudo opkg update
    else
        echo "错误: 未知的包管理器"
        return 1
    fi

    echo "系统更新完成"
}

# ---- systemctl 封装 ----
# 统一管理服务，兼容 Alpine (apk) 的 service 命令
#
# 使用: popos_service <command> <service_name>
#   command: start, stop, restart, status, enable, disable
# 示例: popos_service status ssh
#       popos_service restart nginx
popos_service() {
    local command="$1"
    local service_name="$2"

    if [ -z "$command" ] || [ -z "$service_name" ]; then
        echo "用法: popos_service <command> <service_name>"
        echo "  command: start, stop, restart, status, enable, disable"
        return 1
    fi

    local exit_code=0
    if command -v apk &>/dev/null; then
        # Alpine 用 rc-update/service
        case "$command" in
            enable|disable)
                sudo rc-update "$command" "$service_name"
                ;;
            *)
                sudo service "$service_name" "$command"
                ;;
        esac
        exit_code=$?
    elif command -v systemctl &>/dev/null; then
        sudo systemctl "$command" "$service_name"
        exit_code=$?
    else
        echo "错误: 未找到 systemctl 或 service 命令"
        return 1
    fi

    if [ $exit_code -eq 0 ]; then
        echo "[完成] $service_name $command"
    else
        echo "[失败] $service_name $command (exit: $exit_code)"
    fi
    return $exit_code
}

# ---- 暂停模式 ----
# 显示完成信息，等待用户按键后继续
popos_pause() {
    echo ""
    echo "操作完成"
    read -n 1 -s -r -p "按任意键继续..."
    echo ""
}

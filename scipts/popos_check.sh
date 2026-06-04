#!/usr/bin/env bash
# === PopOS: System Prerequisites Check ===
# Source this from setup-popos.sh only.

popos_check_system() {
    echo "========================================"
    echo " [1/5] 检查系统环境"
    echo "========================================"

    # OS info
    if command -v lsb_release &>/dev/null; then
        local os_name
        os_name="$(lsb_release -ds 2>/dev/null)"
        echo "  OS:      $os_name"
    elif [ -f /etc/os-release ]; then
        echo "  OS:      $(grep PRETTY_NAME /etc/os-release | cut -d= -f2 | tr -d '\"')"
    else
        echo "  OS:      $(uname -s)"
    fi
    echo "  Kernel:  $(uname -r)"
    echo "  Host:    $(hostname)"
    echo "  User:    $(whoami)"
    echo ""

    # Sudo check
    if sudo -n true 2>/dev/null; then
        echo "  [OK] sudo 无密码可用"
    else
        echo "  [WARN] sudo 可能需要密码（部分操作需交互）"
    fi

    # /data mount
    if [ -d /data ]; then
        local df_out
        df_out="$(df -h /data | awk 'NR==2{printf "%s / %s (%s used)", $2, $4, $3}')"
        echo "  [OK] /data: $df_out"
    else
        echo "  [WARN] /data 不存在，将由脚本创建"
    fi

    # Internet
    if ping -c 1 -W 2 8.8.8.8 &>/dev/null; then
        echo "  [OK] 网络连通"
    else
        echo "  [WARN] 网络可能不通"
    fi
    echo ""
}

#!/usr/bin/env bash
# === PopOS: Install Base Tools ===
# Source this from setup-popos.sh only.

popos_install_tools() {
    echo "========================================"
    echo " [4/5] 安装基础工具"
    echo "========================================"

    local packages=(
        git curl wget ca-certificates
        build-essential
        htop neofetch tree
        unzip tar gzip bzip2 xz-utils
        ripgrep fd-find
        software-properties-common apt-transport-https
    )

    echo "  更新包索引..."
    sudo apt-get update -qq 2>/dev/null || { echo "  [WARN] apt update 失败，继续尝试安装"; }

    echo "  安装 ${#packages[@]} 个包..."
    sudo apt-get install -y -qq "${packages[@]}" 2>/dev/null

    if [ $? -eq 0 ]; then
        echo "  [OK] 基础工具安装完成"
    else
        echo "  [WARN] 部分包可能安装失败，请检查 apt 输出"
    fi
    echo ""
}

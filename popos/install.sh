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
        fzf zoxide
        software-properties-common apt-transport-https
    )

    echo "  更新包索引..."
    if ! sudo apt-get update -qq; then
        echo "  [WARN] apt update 失败，继续尝试安装"
    fi

    echo "  安装 ${#packages[@]} 个包..."
    local apt_output
    apt_output=$(sudo apt-get install -y -qq "${packages[@]}" 2>&1)
    local apt_rc=$?

    if [ $apt_rc -eq 0 ]; then
        echo "  [OK] 基础工具安装完成"
    else
        echo "  [WARN] 以下包可能安装失败，错误输出:"
        echo "$apt_output" | tail -20
    fi
    echo ""
    # fd-find → fd alias (PopOS package installs as fdfind)
    if command -v fdfind &>/dev/null && ! command -v fd &>/dev/null; then
        sudo ln -sf "$(command -v fdfind)" /usr/local/bin/fd 2>/dev/null && \
            echo "  [OK] fd 别名已创建 (fdfind → fd)"
    fi
}

popos_install_chrome() {
    echo ">>> 安装 Google Chrome <<<"
    if command -v google-chrome &>/dev/null || command -v google-chrome-stable &>/dev/null; then
        echo "  [SKIP] Google Chrome 已安装"
        return
    fi
    # Add Google Chrome repo
    curl -fsSL https://dl.google.com/linux/linux_signing_key.pub | \
        sudo tee /etc/apt/keyrings/google.asc >/dev/null
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/google.asc] https://dl.google.com/linux/chrome/deb/ stable main" | \
        sudo tee /etc/apt/sources.list.d/google-chrome.list >/dev/null
    sudo apt-get update -qq 2>/dev/null
    sudo apt-get install -y -qq google-chrome-stable 2>/dev/null
    ok "Google Chrome 已安装"
    echo ""
}

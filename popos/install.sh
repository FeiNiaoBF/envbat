#!/usr/bin/env bash
# === PopOS: Install Base Tools ===
# Source this from setup-popos.sh only.

popos_install_tools() {
    echo "========================================"
    echo " [4/5] 安装基础工具"
    echo "========================================"

    local required_packages=(
        git curl wget ca-certificates
        build-essential
        unzip tar gzip bzip2 xz-utils
        software-properties-common apt-transport-https
        python3
        zsh
    )
    local optional_packages=(
        htop neofetch tree
        ripgrep fd-find
        fzf zoxide
    )

    echo "  更新包索引..."
    if ! sudo apt-get update -qq; then
        echo "  [WARN] apt update 失败，继续尝试安装"
    fi

    echo "  安装 ${#required_packages[@]} 个必需包..."
    local apt_output
    if apt_output=$(sudo apt-get install -y -qq "${required_packages[@]}" 2>&1); then
        echo "  [OK] 必需工具安装完成"
    else
        echo "  [FAIL] 必需工具安装失败，错误输出:"
        echo "$apt_output" | tail -20
        return 1
    fi

    if command -v zsh &>/dev/null; then
        echo "  [OK]  zsh: $(command -v zsh)"
    else
        echo "  [FAIL] zsh 安装后仍不可用"
        return 1
    fi

    if [ "${INSTALL_EXTRA_TOOLS:-true}" = true ]; then
        echo "  安装 ${#optional_packages[@]} 个可选工具..."
        local pkg
        for pkg in "${optional_packages[@]}"; do
            if apt_output=$(sudo apt-get install -y -qq "$pkg" 2>&1); then
                echo "  [OK]  $pkg"
            else
                echo "  [WARN] $pkg 安装失败，跳过"
                echo "$apt_output" | tail -5
            fi
        done
    else
        echo "  [SKIP] 可选基础工具已禁用"
    fi
    echo ""
    # fd-find → fd alias (PopOS package installs as fdfind)
    if command -v fdfind &>/dev/null && ! command -v fd &>/dev/null; then
        if sudo ln -sf "$(command -v fdfind)" /usr/local/bin/fd; then
            echo "  [OK] fd 别名已创建 (fdfind → fd)"
        else
            warn "fd 别名创建失败"
        fi
    fi
}

popos_install_chrome() {
    echo ">>> 安装 Google Chrome <<<"
    if command -v google-chrome &>/dev/null || command -v google-chrome-stable &>/dev/null; then
        echo "  [SKIP] Google Chrome 已安装"
        return
    fi

    if ! sudo install -m 0755 -d /etc/apt/keyrings; then
        echo "  [WARN] 无法创建 apt keyring 目录"
        return 1
    fi
    if ! curl -fsSL https://dl.google.com/linux/linux_signing_key.pub | sudo tee /etc/apt/keyrings/google.asc >/dev/null; then
        echo "  [WARN] Google Chrome 签名密钥下载失败"
        return 1
    fi

    local arch
    arch=$(dpkg --print-architecture)
    if ! echo "deb [arch=$arch signed-by=/etc/apt/keyrings/google.asc] https://dl.google.com/linux/chrome/deb/ stable main" | sudo tee /etc/apt/sources.list.d/google-chrome.list >/dev/null; then
        echo "  [WARN] Google Chrome apt 源写入失败"
        return 1
    fi

    local apt_output
    if ! apt_output=$(sudo apt-get update -qq 2>&1); then
        echo "  [WARN] apt update 失败，无法安装 Chrome"
        echo "$apt_output" | tail -20
        return 1
    fi
    if ! apt_output=$(sudo apt-get install -y -qq google-chrome-stable 2>&1); then
        echo "  [WARN] Google Chrome 安装失败"
        echo "$apt_output" | tail -20
        return 1
    fi

    ok "Google Chrome 已安装"
    echo ""
}

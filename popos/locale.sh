#!/usr/bin/env bash
# === PopOS: Chinese Locale + Input Method ===

popos_setup_locale() {
    echo "========================================"
    echo " 配置中文环境"
    echo "========================================"

    if [ "${INSTALL_CHINESE:-false}" != true ]; then
        return
    fi

    echo ">>> 中文 locale <<<"
    if locale -a 2>/dev/null | grep -q zh_CN.UTF-8; then
        echo "  [SKIP] zh_CN.UTF-8 已生成"
    else
        sudo locale-gen zh_CN.UTF-8 2>/dev/null
        sudo update-locale LANG=zh_CN.UTF-8 2>/dev/null
        ok "zh_CN.UTF-8 locale 已生成"
    fi

    echo ">>> fcitx5 中文输入法 <<<"
    if command -v fcitx5 &>/dev/null; then
        echo "  [SKIP] fcitx5 已安装"
    else
        sudo apt-get install -y -qq fcitx5 fcitx5-rime 2>/dev/null
        im-config -n fcitx5 2>/dev/null
        # Auto-start on desktop login
        mkdir -p "$HOME/.config/autostart"
        cp /usr/share/applications/fcitx5.desktop "$HOME/.config/autostart/" 2>/dev/null || true
        ok "fcitx5 + rime 输入法已安装"
        echo "  [HINT] 重新登录后生效，可用 Ctrl+Space 切换输入法"
    fi
    echo ""
}

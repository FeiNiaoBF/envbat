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
    if locale -a 2>/dev/null | grep -qi '^zh_CN\.utf8$'; then
        echo "  [SKIP] zh_CN.UTF-8 已生成"
    else
        sudo sed -i 's/^# *\(zh_CN.UTF-8 UTF-8\)/\1/' /etc/locale.gen
        if ! sudo locale-gen zh_CN.UTF-8; then
            fail "zh_CN.UTF-8 locale 生成失败"
            return 1
        fi
        if ! sudo update-locale LANG=zh_CN.UTF-8; then
            fail "系统 locale 更新失败"
            return 1
        fi
        ok "zh_CN.UTF-8 locale 已生成"
    fi

    echo ">>> fcitx5 中文输入法 <<<"
    if ! sudo apt-get install -y -qq im-config fcitx5 fcitx5-rime fcitx5-chinese-addons fcitx5-config-qt; then
        fail "fcitx5 输入法安装失败"
        return 1
    fi
    if command -v fcitx5 &>/dev/null; then
        ok "fcitx5 + rime 输入法已安装"
    else
        fail "fcitx5 安装失败"
        return 1
    fi

    if command -v im-config &>/dev/null; then
        if im-config -n fcitx5; then
            ok "im-config 已切换为 fcitx5"
        else
            fail "im-config 配置失败，请手动运行: im-config -n fcitx5"
            return 1
        fi
    else
        fail "im-config 未安装，无法自动切换输入法框架"
        return 1
    fi

    # Auto-start on desktop login
    mkdir -p "$HOME/.config/autostart"
    if [ -f /usr/share/applications/org.fcitx.Fcitx5.desktop ]; then
        cp /usr/share/applications/org.fcitx.Fcitx5.desktop "$HOME/.config/autostart/" 2>/dev/null || true
        ok "fcitx5 自启动已配置"
    elif [ -f /usr/share/applications/fcitx5.desktop ]; then
        cp /usr/share/applications/fcitx5.desktop "$HOME/.config/autostart/" 2>/dev/null || true
        ok "fcitx5 自启动已配置"
    else
        warn "未找到 fcitx5 desktop 文件，请在系统设置中确认自启动"
    fi

    echo "  [HINT] 重新登录后生效，可用 Ctrl+Space 切换输入法"
    echo ""
}

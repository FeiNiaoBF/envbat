#!/usr/bin/env bash
# === SSH Key Setup ===

popos_setup_ssh() {
    echo ">>> SSH 密钥 <<<"
    if ! mkdir -p "$HOME/.ssh" || ! chmod 700 "$HOME/.ssh"; then
        fail "无法准备 ~/.ssh"
        return 1
    fi

    if [ -f "$HOME/.ssh/id_ed25519" ]; then
        if ! chmod 600 "$HOME/.ssh/id_ed25519"; then
            fail "SSH 私钥权限修复失败"
            return 1
        fi
        if [ -f "$HOME/.ssh/id_ed25519.pub" ] && ! chmod 644 "$HOME/.ssh/id_ed25519.pub"; then
            fail "SSH 公钥权限修复失败"
            return 1
        fi
        echo "  [SKIP] SSH 密钥已存在"
        return 0
    fi

    if [ "${INSTALL_SSH:-skip}" != generate ]; then
        echo "  [SKIP] 用户选择跳过 SSH 设置"
        return 0
    fi

    local email="${GIT_USER_EMAIL:-yeekox@example.com}"
    if ! ssh-keygen -t ed25519 -C "$email" -f "$HOME/.ssh/id_ed25519" -N ""; then
        fail "SSH 密钥生成失败"
        return 1
    fi
    if [ ! -f "$HOME/.ssh/id_ed25519" ] || [ ! -f "$HOME/.ssh/id_ed25519.pub" ]; then
        fail "SSH 密钥生成结果不完整"
        return 1
    fi
    if ! chmod 600 "$HOME/.ssh/id_ed25519" || ! chmod 644 "$HOME/.ssh/id_ed25519.pub"; then
        fail "SSH 密钥权限设置失败"
        return 1
    fi
    ok "已生成 SSH 密钥: ~/.ssh/id_ed25519"
    echo "  [HINT] 公钥内容如下，请添加到 GitHub/GitLab:"
    cat "$HOME/.ssh/id_ed25519.pub"
}

#!/usr/bin/env bash
# === SSH Key Setup ===

popos_setup_ssh() {
    echo ">>> SSH 密钥 <<<"
    mkdir -p "$HOME/.ssh"
    chmod 700 "$HOME/.ssh"
    if [ -f "$HOME/.ssh/id_ed25519" ]; then
        echo "  [SKIP] SSH 密钥已存在"
        # Ensure ssh-agent has it
        eval "$(ssh-agent -s)" >/dev/null 2>&1
        ssh-add "$HOME/.ssh/id_ed25519" 2>/dev/null || true
        return
    fi
    case "$INSTALL_SSH" in
        generate)
            local email="${GIT_USER_EMAIL:-yeekox@example.com}"
            ssh-keygen -t ed25519 -C "$email" -f "$HOME/.ssh/id_ed25519" -N "" 2>/dev/null
            eval "$(ssh-agent -s)" >/dev/null 2>&1
            ssh-add "$HOME/.ssh/id_ed25519" 2>/dev/null
            ok "已生成 SSH 密钥: ~/.ssh/id_ed25519"
            echo "  [HINT] 公钥内容如下，请添加到 GitHub/GitLab:"
            cat "$HOME/.ssh/id_ed25519.pub"
            ;;
        restore)
            local backup_ssh="$INSTALL_BASE/backups/dotfiles/ssh"
            if [ -d "$backup_ssh" ]; then
                cp -a "$backup_ssh/." "$HOME/.ssh/" 2>/dev/null
                chmod 600 "$HOME/.ssh/id_ed25519" 2>/dev/null
                chmod 644 "$HOME/.ssh/id_ed25519.pub" 2>/dev/null
                eval "$(ssh-agent -s)" >/dev/null 2>&1
                ssh-add "$HOME/.ssh/id_ed25519" 2>/dev/null || true
                ok "SSH 密钥已从备份恢复"
            else
                warn "备份目录 $backup_ssh 不存在，跳过"
            fi
            ;;
        skip)
            echo "  [SKIP] 用户选择跳过 SSH 设置"
            ;;
    esac
}

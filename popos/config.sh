#!/usr/bin/env bash
# === Shell Loading Chain ===
# Injects source ~/.config/envbat/profile.sh into .bashrc and .zshrc.
# Also configures git user.name / user.email if set.

popos_config_shell_chain() {
    echo ">>> 配置 Shell 加载链 <<<"
    local profile_guard="# === envbat profile ==="
    local source_line='[ -f "$HOME/.config/envbat/profile.sh" ] && source "$HOME/.config/envbat/profile.sh"'
    # Add to .bashrc
    local bashrc="$HOME/.bashrc"
    if ! grep -qF "$profile_guard" "$bashrc" 2>/dev/null; then
        cat >> "$bashrc" << 'EOF'

# envbat — load persisted profile
[ -f "$HOME/.config/envbat/profile.sh" ] && source "$HOME/.config/envbat/profile.sh"
EOF
        ok ".bashrc 已添加 envbat 加载链"
    else
        echo "  [SKIP] .bashrc 已有 envbat 加载链"
    fi
    # Add to .zshrc (if exists or will exist after oh-my-zsh install)
    local zshrc="$HOME/.zshrc"
    if [ ! -f "$zshrc" ]; then
        # Pre-create .zshrc for oh-my-zsh
        touch "$zshrc"
    fi
    if ! grep -qF "$profile_guard" "$zshrc" 2>/dev/null; then
        cat >> "$zshrc" << 'EOF'

# envbat — load persisted profile
[ -f "$HOME/.config/envbat/profile.sh" ] && source "$HOME/.config/envbat/profile.sh"
EOF
        ok ".zshrc 已添加 envbat 加载链"
    else
        echo "  [SKIP] .zshrc 已有 envbat 加载链"
    fi
    # Git config
    if [ -n "$GIT_USER_NAME" ]; then
        git config --global user.name "$GIT_USER_NAME"
        ok "Git user.name 已设置"
    fi
    if [ -n "$GIT_USER_EMAIL" ]; then
        git config --global user.email "$GIT_USER_EMAIL"
        ok "Git user.email 已设置"
    fi
    echo ""
}

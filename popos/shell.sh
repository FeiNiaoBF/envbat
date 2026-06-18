#!/usr/bin/env bash
# === Shell Setup: oh-my-zsh + Powerlevel10k + Plugins ===

popos_install_ohmyzsh() {
    echo ">>> 安装 oh-my-zsh <<<"
    if ! command -v zsh &>/dev/null; then
        echo "  安装 zsh..."
        sudo apt-get install -y -qq zsh
    fi

    local zsh_bin
    zsh_bin="$(command -v zsh || true)"
    if [ -z "$zsh_bin" ]; then
        fail "zsh 未安装，跳过 oh-my-zsh 配置"
        return 1
    fi

    if [ -d "$HOME/.oh-my-zsh" ]; then
        echo "  [SKIP] oh-my-zsh 已安装"
    else
        if git clone --depth 1 https://github.com/ohmyzsh/ohmyzsh.git "$HOME/.oh-my-zsh"; then
            ok "oh-my-zsh 已安装"
        else
            fail "oh-my-zsh 下载失败，请检查 GitHub 网络连通"
            return 1
        fi
    fi
    echo ">>> 安装 Powerlevel10k <<<"
    local p10k_dir="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k"
    if [ -d "$p10k_dir" ]; then
        echo "  [SKIP] Powerlevel10k 已安装"
    else
        if git clone --depth 1 https://github.com/romkatv/powerlevel10k.git "$p10k_dir"; then
            ok "Powerlevel10k 已安装"
        else
            fail "Powerlevel10k 下载失败，请检查 GitHub 网络连通"
            return 1
        fi
    fi
    echo ">>> 安装 Zsh 插件 <<<"
    local custom_dir="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins"
    mkdir -p "$custom_dir"
    # zsh-autosuggestions
    if [ ! -d "$custom_dir/zsh-autosuggestions" ]; then
        if ! git clone --depth 1 https://github.com/zsh-users/zsh-autosuggestions "$custom_dir/zsh-autosuggestions"; then
            fail "zsh-autosuggestions 下载失败，请检查 GitHub 网络连通"
            return 1
        fi
    fi
    # zsh-syntax-highlighting
    if [ ! -d "$custom_dir/zsh-syntax-highlighting" ]; then
        if ! git clone --depth 1 https://github.com/zsh-users/zsh-syntax-highlighting "$custom_dir/zsh-syntax-highlighting"; then
            fail "zsh-syntax-highlighting 下载失败，请检查 GitHub 网络连通"
            return 1
        fi
    fi
    ok "Zsh 插件已安装"
    # Update .zshrc theme and plugins
    local zshrc="$HOME/.zshrc"
    if [ ! -f "$zshrc" ]; then
        {
            echo 'export ZSH="$HOME/.oh-my-zsh"'
            echo 'ZSH_THEME="powerlevel10k/powerlevel10k"'
            echo 'plugins=(git zsh-autosuggestions zsh-syntax-highlighting fzf)'
            echo 'source "$ZSH/oh-my-zsh.sh"'
        } > "$zshrc"
    else
        if grep -q '^ZSH_THEME=' "$zshrc"; then
            sed -i 's/^ZSH_THEME=.*/ZSH_THEME="powerlevel10k\/powerlevel10k"/' "$zshrc"
        else
            echo 'ZSH_THEME="powerlevel10k/powerlevel10k"' >> "$zshrc"
        fi
        if grep -q '^plugins=' "$zshrc"; then
            sed -i 's/^plugins=.*/plugins=(git zsh-autosuggestions zsh-syntax-highlighting fzf)/' "$zshrc"
        else
            echo 'plugins=(git zsh-autosuggestions zsh-syntax-highlighting fzf)' >> "$zshrc"
        fi
        if ! grep -q '^export ZSH=' "$zshrc" && ! grep -q '^ZSH=' "$zshrc"; then
            sed -i '1iexport ZSH="$HOME/.oh-my-zsh"' "$zshrc"
        fi
        if ! grep -q 'oh-my-zsh.sh' "$zshrc"; then
            echo 'source "$ZSH/oh-my-zsh.sh"' >> "$zshrc"
        fi
    fi
    # Change default shell
    if ! grep -qxF "$zsh_bin" /etc/shells 2>/dev/null; then
        echo "$zsh_bin" | sudo tee -a /etc/shells >/dev/null
    fi

    local login_shell
    login_shell="$(getent passwd "$USER" 2>/dev/null | cut -d: -f7 || true)"
    if [ "$login_shell" != "$zsh_bin" ]; then
        sudo chsh -s "$zsh_bin" "$USER" && ok "默认 shell 已切换为 zsh (重新登录生效)" || \
            warn "chsh 失败，请手动运行: sudo chsh -s $zsh_bin $USER"
    else
        echo "  [OK] 默认 shell 已是 zsh"
    fi
}

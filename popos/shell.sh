#!/usr/bin/env bash
# === Shell Setup: oh-my-zsh + Powerlevel10k + Plugins ===

popos_install_ohmyzsh() {
    echo ">>> 安装 oh-my-zsh <<<"
    if [ -d "$HOME/.oh-my-zsh" ]; then
        echo "  [SKIP] oh-my-zsh 已安装"
    else
        sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended 2>/dev/null
        ok "oh-my-zsh 已安装"
    fi
    echo ">>> 安装 Powerlevel10k <<<"
    local p10k_dir="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k"
    if [ -d "$p10k_dir" ]; then
        echo "  [SKIP] Powerlevel10k 已安装"
    else
        git clone --depth 1 https://github.com/romkatv/powerlevel10k.git "$p10k_dir" 2>/dev/null
        ok "Powerlevel10k 已安装"
    fi
    echo ">>> 安装 Zsh 插件 <<<"
    local custom_dir="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins"
    mkdir -p "$custom_dir"
    # zsh-autosuggestions
    if [ ! -d "$custom_dir/zsh-autosuggestions" ]; then
        git clone --depth 1 https://github.com/zsh-users/zsh-autosuggestions "$custom_dir/zsh-autosuggestions" 2>/dev/null
    fi
    # zsh-syntax-highlighting
    if [ ! -d "$custom_dir/zsh-syntax-highlighting" ]; then
        git clone --depth 1 https://github.com/zsh-users/zsh-syntax-highlighting "$custom_dir/zsh-syntax-highlighting" 2>/dev/null
    fi
    # fzf (via apt, ensure zsh integration)
    if command -v fzf &>/dev/null; then
        local fzf_zsh="/usr/share/doc/fzf/examples/key-bindings.zsh"
        if [ -f "$fzf_zsh" ]; then
            echo "source $fzf_zsh" >> "$PROFILE_FILE"
        fi
    fi
    ok "Zsh 插件已安装"
    # Update .zshrc theme and plugins
    local zshrc="$HOME/.zshrc"
    sed -i 's/^ZSH_THEME=.*/ZSH_THEME="powerlevel10k\/powerlevel10k"/' "$zshrc" 2>/dev/null
    sed -i 's/^plugins=.*/plugins=(git zsh-autosuggestions zsh-syntax-highlighting fzf)/' "$zshrc" 2>/dev/null
    # Change default shell
    if [ "$SHELL" != "$(which zsh)" ]; then
        chsh -s "$(which zsh)" 2>/dev/null && ok "默认 shell 已切换为 zsh (重新登录生效)" || \
            warn "chsh 失败，请手动运行: chsh -s $(which zsh)"
    else
        echo "  [OK] 默认 shell 已是 zsh"
    fi
}

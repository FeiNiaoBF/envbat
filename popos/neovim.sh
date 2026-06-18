#!/usr/bin/env bash
# === Neovim Installer ===

popos_install_neovim() {
    echo ">>> 安装 Neovim <<<"
    local nvim_root="$INSTALL_BASE/tools/neovim"
    local nvim_bin="$nvim_root/bin/nvim"
    if [ -x "$nvim_bin" ]; then
        echo "  [SKIP] Neovim 已安装"
        return
    fi
    echo "  下载最新 Neovim ..."
    local url
    url=$(curl -sL https://api.github.com/repos/neovim/neovim/releases/latest \
        | grep -oP '"browser_download_url": "\K[^"]+nvim-linux-x86_64\.tar\.gz' || true)
    if [ -z "$url" ]; then
        fail "无法获取 Neovim 下载地址"
        return 1
    fi
    if ! curl -#L "$url" | sudo tar -C "$INSTALL_BASE/tools" -xz; then
        fail "Neovim 下载/解压失败"
        return 1
    fi
    # The extracted name is nvim-linux-x86_64, rename to neovim
    if [ -d "$INSTALL_BASE/tools/nvim-linux-x86_64" ]; then
        mv "$INSTALL_BASE/tools/nvim-linux-x86_64" "$nvim_root"
    fi
    if [ ! -x "$nvim_bin" ]; then
        fail "Neovim 安装后未找到 $nvim_bin"
        return 1
    fi
    # Symlink
    mkdir -p "$HOME/Tools/bin"
    ln -sf "$nvim_bin" "$HOME/Tools/bin/nvim"
    ok "Neovim 已安装"
}

popos_install_nerd_font() {
    echo ">>> 安装 Nerd Font (JetBrainsMono) <<<"
    local font_dir="$HOME/.local/share/fonts"
    local target="$font_dir/JetBrainsMonoNerdFont"
    if fc-list | grep -qi "JetBrainsMono.*Nerd" 2>/dev/null; then
        echo "  [SKIP] JetBrainsMono Nerd Font 已安装"
        return
    fi
    mkdir -p "$font_dir"
    local url
    url="https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip"
    local tmp_zip="/tmp/JetBrainsMono-NF.zip"
    if ! curl -#L "$url" -o "$tmp_zip"; then
        fail "Nerd Font 下载失败"
        return 1
    fi
    if ! unzip -qo "$tmp_zip" -d "$font_dir/JetBrainsMonoNerdFont"; then
        rm -f "$tmp_zip"
        fail "Nerd Font 解压失败"
        return 1
    fi
    rm -f "$tmp_zip"
    fc-cache -f "$font_dir" 2>/dev/null || true
    ok "JetBrainsMono Nerd Font 已安装"
    echo "  [HINT] 请在终端设置中选择 JetBrainsMono Nerd Font 作为字体"
}

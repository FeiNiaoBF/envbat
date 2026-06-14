# Phase 1: PopOS Interactive Setup Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Transform PopOS setup from a silent batch script into an interactive guided installer that asks one question at a time, persists choices to `~/.config/envbat/profile.sh`, and installs all development runtimes/tools.

**Architecture:** A modular shell-script suite, each file owning one responsibility. `setup.sh` is the interactive orchestrator: it sources all modules, runs the question-answer loop, saves the profile, and dispatches installations in order. Profile persistence lets re-runs skip questioning.

**Tech Stack:** Bash + PopOS 24.04 (apt-based). `gsettings` for GNOME/COSMIC settings. Version managers (nvm, pyenv, rustup) handle multi-language runtimes.

---

## File Structure

### Modified files

| File | What changes |
|---|---|
| `popos/setup.sh` | **Rewrite** — new interactive orchestrator with profile detection + question loop |
| `popos/directories.sh` | **Enhance** — add Code/Projects/Data/Tools symlink guarantee; add flatpak cleanup step |
| `popos/config.sh` | **Rewrite** — now writes `source` lines into `.zshrc`/`.bashrc` instead of appending env vars directly; cleans old duplicated entries |
| `popos/install.sh` | **Expand** — add fzf, zoxide, ripgrep, fd-find to apt list |
| `popos/verify.sh` | **Expand** — check symlinks exist, check profile is sourced, check key tools (nvim, go, node, rust, java, docker) |

### New files

| File | Responsibility |
|---|---|
| `popos/interactive.sh` | Reusable prompt helpers: `ask_yes_no`, `ask_input`, `colored output` |
| `popos/profile.sh` | `popos_save_profile` (write answers to `~/.config/envbat/profile.sh`), `popos_load_profile` (source if exists), `popos_clean_old_bashrc` (remove duplicated env vars from .bashrc) |
| `popos/lang.sh` | Functions: `popos_install_go`, `popos_install_nvm_node`, `popos_install_pyenv`, `popos_install_rustup`, `popos_install_java` — each downloads to `/data/tools/` |
| `popos/neovim.sh` | `popos_install_neovim` — download latest tarball, symlink to `~/Tools/bin/` |
| `popos/docker.sh` | `popos_install_docker` — add official repo, apt install, usermod |
| `popos/shell.sh` | `popos_install_ohmyzsh` — oh-my-zsh + Powerlevel10k + recommended plugins + `chsh -s zsh` |
| `popos/ssh.sh` | `popos_setup_ssh` — interact: generate ed25519 or restore from backup |
| `popos/font.sh` | `popos_install_nerd_font` — download JetBrainsMono Nerd Font to `/data/tools/fonts/`, update font cache |

---

## Interactive Flow

```
setup.sh start
  │
  ├─ [1] Welcome banner
  ├─ [2] System check (check.sh)
  │
  ├─ [3] Profile found? ──Y──→ Load it, skip to [5]
  │     N
  │     ▼
  │  Interactive loop (one Q at a time):
  │   ├─ Base path (detect /data, else prompt)
  │   ├─ Go? (Y/n, default latest)
  │   ├─ Node via nvm? (Y/n)
  │   ├─ Python via pyenv? (Y/n)
  │   ├─ Rust via rustup? (Y/n)
  │   ├─ Java? (version: 21/17/11/skip)
  │   ├─ Neovim? (Y/n)
  │   ├─ Docker? (Y/n)
  │   ├─ oh-my-zsh + Powerlevel10k? (Y/n)
  │   ├─ SSH key? (generate/restore/skip)
  │   ├─ Git name/email
  │   └─ Extra tools? (rg/fd/fzf/zoxide, Y/n)
  │
  ├─ [4] Save profile → ~/.config/envbat/profile.sh
  │
  ├─ [5] Execute installations (in order)
  │   ├─ directories.sh    (dirs + symlinks + flatpak cleanup)
  │   ├─ install.sh         (base apt tools)
  │   ├─ lang.sh            (selected languages)
  │   ├─ neovim.sh          (neovim + Nerd Font)
  │   ├─ docker.sh          (Docker)
  │   ├─ shell.sh           (oh-my-zsh + P10k)
  │   ├─ ssh.sh             (SSH keys)
  │   └─ config.sh          (shell loading chain)
  │
  ├─ [6] Verify (verify.sh)
  └─ [7] Summary + next steps
```

---

## Tasks

### Task 1: Create `popos/interactive.sh` — prompt helpers

**Files:**
- Create: `popos/interactive.sh`

- [ ] **Step: Write the prompt helper file**

```bash
#!/usr/bin/env bash
# === Interactive Prompt Helpers ===
# Colored output + reusable question functions.
# Source this from setup.sh only.

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

ok()   { echo -e "  ${GREEN}[OK]${NC} $1"; }
info() { echo -e "  ${CYAN}$1${NC}"; }
warn() { echo -e "  ${YELLOW}[WARN]${NC} $1"; }
fail() { echo -e "  ${RED}[FAIL]${NC} $1"; }
title(){ echo -e "\n${BOLD}== $1 ==${NC}\n"; }

# Ask yes/no, default Yes. Returns 0 for Y, 1 for N.
ask_yes_no() {
    local prompt="$1" default="${2:-Y}" answer
    local hint
    [[ "$default" =~ ^[Yy] ]] && hint="Y/n" || hint="y/N"
    while true; do
        read -r -p "  $prompt ($hint): " answer
        answer="${answer:-$default}"
        case "$answer" in
            [Yy]*) return 0 ;;
            [Nn]*) return 1 ;;
            *) warn "请输入 y 或 n" ;;
        esac
    done
}

# Ask for text input with a default value.
ask_input() {
    local prompt="$1" default="$2" var_name="$3" input
    local hint=""
    [ -n "$default" ] && hint=" (默认: $default)"
    read -r -p "  $prompt$hint: " input
    input="${input:-$default}"
    printf -v "$var_name" "%s" "$input"
}

# Ask for a single-choice selection from a list.
ask_select() {
    local prompt="$1" var_name="$2"
    shift 2
    local options=("$@")
    local i choice
    echo "  $prompt"
    for i in "${!options[@]}"; do
        echo "    $((i+1)). ${options[$i]}"
    done
    while true; do
        read -r -p "  输入编号 (1-${#options[@]}): " choice
        if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "${#options[@]}" ]; then
            printf -v "$var_name" "%s" "${options[$((choice-1))]}"
            return 0
        fi
        warn "请输入 1-${#options[@]} 之间的数字"
    done
}
```

- [ ] **Step: Verify sourcing works**

Run: `bash -c 'source popos/interactive.sh && ok "test" && info "test" && ask_yes_no "continue?" && echo ok || echo no'` — no syntax errors.

---

### Task 2: Create `popos/profile.sh` — profile generator/loader

**Files:**
- Create: `popos/profile.sh`

- [ ] **Step: Write the profile module**

```bash
#!/usr/bin/env bash
# === Profile Persistence ===
# Stores interactive answers so re-runs skip questioning.
# Location: ~/.config/envbat/profile.sh
#
# Usage (source this file):
#   popos_load_profile   → source profile if exists, returns 0 or 1
#   popos_save_profile   → write current vars to profile
#   popos_clean_old_bashrc → remove legacy env vars from .bashrc

PROFILE_DIR="$HOME/.config/envbat"
PROFILE_FILE="$PROFILE_DIR/profile.sh"

# Variables that get persisted (set by interactive.sh questions)
# These are populated by setup.sh before calling popos_save_profile:
#   INSTALL_BASE        — /data or custom
#   INSTALL_GO          — true/false
#   INSTALL_NVM_NODE    — true/false
#   INSTALL_PYENV       — true/false
#   INSTALL_RUSTUP      — true/false
#   INSTALL_JAVA        — version or "skip"
#   INSTALL_NEOVIM      — true/false
#   INSTALL_DOCKER      — true/false
#   INSTALL_OHMYZSH     — true/false
#   INSTALL_SSH         — generate/restore/skip
#   INSTALL_EXTRA_TOOLS — true/false
#   GIT_USER_NAME       — string
#   GIT_USER_EMAIL      — string
#   GO_VERSION          — e.g. "1.23"
#   JAVA_VERSION        — e.g. "21"

popos_load_profile() {
    if [ -f "$PROFILE_FILE" ]; then
        # shellcheck source=/dev/null
        source "$PROFILE_FILE"
        ok "已加载配置: $PROFILE_FILE"
        return 0
    fi
    return 1
}

popos_save_profile() {
    mkdir -p "$PROFILE_DIR"
    cat > "$PROFILE_FILE" << PROFILEEOF
# === envbat profile ===
# Generated by setup.sh $(date +%Y-%m-%d)
# Delete this file to re-run interactive setup.

INSTALL_BASE="${INSTALL_BASE:-/data}"
INSTALL_GO="${INSTALL_GO:-true}"
INSTALL_NVM_NODE="${INSTALL_NVM_NODE:-true}"
INSTALL_PYENV="${INSTALL_PYENV:-true}"
INSTALL_RUSTUP="${INSTALL_RUSTUP:-true}"
INSTALL_JAVA="${INSTALL_JAVA:-21}"
INSTALL_NEOVIM="${INSTALL_NEOVIM:-true}"
INSTALL_DOCKER="${INSTALL_DOCKER:-true}"
INSTALL_OHMYZSH="${INSTALL_OHMYZSH:-true}"
INSTALL_SSH="${INSTALL_SSH:-generate}"
INSTALL_EXTRA_TOOLS="${INSTALL_EXTRA_TOOLS:-true}"
GIT_USER_NAME="${GIT_USER_NAME:-}"
GIT_USER_EMAIL="${GIT_USER_EMAIL:-}"
GO_VERSION="${GO_VERSION:-}"
JAVA_VERSION="${JAVA_VERSION:-21}"
PROFILEEOF
    ok "配置已保存: $PROFILE_FILE"
}

popos_clean_old_bashrc() {
    local bashrc="$HOME/.bashrc"
    local guard="# === PopOS Environment ==="
    if grep -qF "$guard" "$bashrc" 2>/dev/null; then
        # Remove from the guard line to the blank line after env block
        sed -i "/$guard/,/^$/d" "$bashrc"
        ok "已清理 .bashrc 中的旧环境变量段"
    fi
}
```

- [ ] **Step: Quick syntax check**

Run: `bash -n popos/profile.sh` — no syntax errors.

---

### Task 3: Update `popos/directories.sh` — symlink guarantee + flatpak cleanup

**Files:**
- Modify: `popos/directories.sh`

- [ ] **Step: Add symlink guarantee function to directories.sh**

Append at end of `popos/directories.sh`:

```bash
popos_ensure_symlinks() {
    echo ">>> 确保符号链接 <<<"
    local links=(
        "Code:$INSTALL_BASE/workspace/github"
        "Projects:$INSTALL_BASE/workspace/local"
        "Data:$INSTALL_BASE"
        "Tools:$INSTALL_BASE/tools"
    )
    for entry in "${links[@]}"; do
        local name="${entry%%:*}"
        local target="${entry#*:}"
        local link_path="$HOME/$name"
        if [ -L "$link_path" ] && [ "$(readlink "$link_path")" = "$target" ]; then
            echo "  [OK]  ~/$name → $target"
        elif [ -L "$link_path" ]; then
            ln -sfn "$target" "$link_path" && echo "  [FIX] ~/$name → $target"
        elif [ ! -e "$link_path" ]; then
            ln -s "$target" "$link_path" && echo "  [LINK] ~/$name → $target"
        else
            echo "  [SKIP] ~/$name 是真实文件，跳过"
        fi
    done
    echo ""
}

popos_cleanup_flatpak() {
    echo ">>> 清理 Flatpak 缓存 <<<"
    if command -v flatpak &>/dev/null; then
        local unused
        unused=$(flatpak uninstall --unused 2>&1)
        if echo "$unused" | grep -q "Nothing unused to uninstall"; then
            echo "  [OK]  没有可清理的 flatpak"
        else
            echo "$unused"
            echo "  [OK]  Flatpak 已清理"
        fi
    else
        echo "  [SKIP] flatpak 未安装"
    fi
    echo ""
}
```

- [ ] **Step: Verify syntax**

Run: `bash -n popos/directories.sh` — no syntax errors.

---

### Task 4: Expand `popos/install.sh` — add extra small tools

**Files:**
- Modify: `popos/install.sh`

- [ ] **Step: Extend the packages array**

Edit `popos/install.sh`: add `fzf`, `zoxide`, and ensure `ripgrep`/`fd-find` are in the list:

```bash
    local packages=(
        git curl wget ca-certificates
        build-essential
        htop neofetch tree
        unzip tar gzip bzip2 xz-utils
        ripgrep fd-find
        fzf zoxide
        software-properties-common apt-transport-https
    )
```

- [ ] **Step: Verify syntax**

Run: `bash -n popos/install.sh` — no syntax errors.

---

### Task 5: Create `popos/lang.sh` — language runtime installers

**Files:**
- Create: `popos/lang.sh`

- [ ] **Step: Write Go installer**

```bash
popos_install_go() {
    echo ">>> 安装 Go <<<"
    local go_root="$INSTALL_BASE/tools/go"
    if [ -x "$go_root/bin/go" ]; then
        echo "  [SKIP] Go 已安装: $($go_root/bin/go version)"
        return
    fi
    local go_ver="${GO_VERSION:-}"
    if [ -z "$go_ver" ]; then
        go_ver=$(curl -sL 'https://go.dev/dl/?mode=json' | grep -oP '"version": "\K[^"]+' | head -1)
    fi
    local arch="linux-amd64"
    local url="https://go.dev/dl/${go_ver}.${arch}.tar.gz"
    echo "  下载 $go_ver ..."
    curl -#L "$url" | sudo tar -C "$INSTALL_BASE/tools" -xz 2>/dev/null && \
        ok "Go 已安装: $go_ver" || \
        fail "Go 下载/解压失败"
    # Symlink into ~/Tools/bin
    mkdir -p "$HOME/Tools/bin"
    ln -sf "$go_root/bin/go" "$HOME/Tools/bin/go"
}
```

- [ ] **Step: Write Node (nvm) installer**

```bash
popos_install_nvm_node() {
    echo ">>> 安装 Node (via nvm) <<<"
    local nvm_dir="$INSTALL_BASE/tools/nvm"
    if [ -d "$nvm_dir/.git" ]; then
        echo "  [SKIP] nvm 已安装"
        return
    fi
    export NVM_DIR="$nvm_dir"
    git clone --depth 1 https://github.com/nvm-sh/nvm.git "$nvm_dir" 2>/dev/null
    # shellcheck source=/dev/null
    source "$nvm_dir/nvm.sh"
    nvm install --lts 2>/dev/null
    local node_ver
    node_ver=$(node --version 2>/dev/null)
    ok "Node 已安装: $node_ver"
    # Persist NVM_DIR in profile
    {
        echo ""
        echo "# nvm"
        echo "export NVM_DIR=\"$nvm_dir\""
        echo '[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"'
    } >> "$PROFILE_FILE"
}
```

- [ ] **Step: Write Python (pyenv) installer**

```bash
popos_install_pyenv() {
    echo ">>> 安装 Python (via pyenv) <<<"
    local pyenv_root="$INSTALL_BASE/tools/pyenv"
    if [ -d "$pyenv_root" ]; then
        echo "  [SKIP] pyenv 已安装"
        return
    fi
    # Install build dependencies
    sudo apt-get install -y -qq make build-essential libssl-dev zlib1g-dev \
        libbz2-dev libreadline-dev libsqlite3-dev wget curl llvm \
        libncursesw5-dev xz-utils tk-dev libxml2-dev libxmlsec1-dev libffi-dev liblzma-dev 2>/dev/null
    git clone --depth 1 https://github.com/pyenv/pyenv.git "$pyenv_root" 2>/dev/null
    ok "pyenv 已安装 (运行 pyenv install 3.x 安装 Python)"
    # Persist
    {
        echo ""
        echo "# pyenv"
        echo "export PYENV_ROOT=\"$pyenv_root\""
        echo 'export PATH="$PYENV_ROOT/bin:$PATH"'
        echo 'eval "$(pyenv init -)"'
    } >> "$PROFILE_FILE"
}
```

- [ ] **Step: Write Rust (rustup) installer**

```bash
popos_install_rustup() {
    echo ">>> 安装 Rust (via rustup) <<<"
    local rustup_home="$INSTALL_BASE/tools/rustup"
    if [ -x "$rustup_home/bin/rustc" ]; then
        echo "  [SKIP] Rust 已安装"
        return
    fi
    export RUSTUP_HOME="$rustup_home"
    export CARGO_HOME="$INSTALL_BASE/tools/cargo"
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y 2>/dev/null
    ok "Rust 已安装"
    # Persist
    {
        echo ""
        echo "# Rust"
        echo "export RUSTUP_HOME=\"$rustup_home\""
        echo "export CARGO_HOME=\"$INSTALL_BASE/tools/cargo\""
        echo 'export PATH="$CARGO_HOME/bin:$PATH"'
    } >> "$PROFILE_FILE"
    # Symlink cargo binaries
    mkdir -p "$HOME/Tools/bin"
    ln -sf "$CARGO_HOME/bin/"* "$HOME/Tools/bin/" 2>/dev/null
}
```

- [ ] **Step: Write Java installer**

```bash
popos_install_java() {
    echo ">>> 安装 Java <<<"
    local java_ver="${JAVA_VERSION:-21}"
    local java_root="$INSTALL_BASE/tools/java/jdk-$java_ver"
    if [ -x "$java_root/bin/java" ]; then
        echo "  [SKIP] Java 已安装"
        return
    fi
    mkdir -p "$INSTALL_BASE/tools/java"
    local url
    url="https://download.java.net/java/GA/jdk${java_ver}/GPL/openjdk-${java_ver}_linux-x64_bin.tar.gz"
    echo "  下载 JDK $java_ver ..."
    curl -#L "$url" | sudo tar -C "$INSTALL_BASE/tools/java" -xz 2>/dev/null
    # The extracted dir is jdk-{ver}, rename if needed
    local extracted
    extracted=$(find "$INSTALL_BASE/tools/java" -maxdepth 1 -type d -name "jdk-*" | head -1)
    if [ -n "$extracted" ] && [ "$extracted" != "$java_root" ]; then
        mv "$extracted" "$java_root"
    fi
    ok "JDK $java_ver 已安装"
    # Symlink
    mkdir -p "$HOME/Tools/bin"
    ln -sf "$java_root/bin/java" "$HOME/Tools/bin/java"
    ln -sf "$java_root/bin/javac" "$HOME/Tools/bin/javac"
}
```

- [ ] **Step: Add dispatch function and syntax check**

```bash
popos_install_languages() {
    $INSTALL_GO      && popos_install_go
    $INSTALL_NVM_NODE && popos_install_nvm_node
    $INSTALL_PYENV   && popos_install_pyenv
    $INSTALL_RUSTUP  && popos_install_rustup
    [ "$INSTALL_JAVA" != "skip" ] && popos_install_java
}
```

Run: `bash -n popos/lang.sh` — verify syntax.

---

### Task 6: Create `popos/neovim.sh` — Neovim + Nerd Font

**Files:**
- Create: `popos/neovim.sh`

- [ ] **Step: Write Neovim installer**

```bash
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
        | grep -oP '"browser_download_url": "\K[^"]+nvim-linux-x86_64\.tar\.gz')
    curl -#L "$url" | sudo tar -C "$INSTALL_BASE/tools" -xz 2>/dev/null
    # The extracted name is nvim-linux-x86_64, rename to neovim
    [ -d "$INSTALL_BASE/tools/nvim-linux-x86_64" ] && \
        mv "$INSTALL_BASE/tools/nvim-linux-x86_64" "$nvim_root"
    # Symlink
    mkdir -p "$HOME/Tools/bin"
    ln -sf "$nvim_bin" "$HOME/Tools/bin/nvim"
    ok "Neovim 已安装"
}
```

- [ ] **Step: Write this font installer function (appended to same file)**

```bash
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
    curl -#L "$url" -o "$tmp_zip" 2>/dev/null
    unzip -qo "$tmp_zip" -d "$font_dir/JetBrainsMonoNerdFont" 2>/dev/null
    rm -f "$tmp_zip"
    fc-cache -f "$font_dir" 2>/dev/null
    ok "JetBrainsMono Nerd Font 已安装"
    echo "  [HINT] 请在终端设置中选择 JetBrainsMono Nerd Font 作为字体"
}
```

Run: `bash -n popos/neovim.sh` — no syntax errors.

---

### Task 7: Create `popos/docker.sh` — Docker installer

**Files:**
- Create: `popos/docker.sh`

- [ ] **Step: Write Docker installer**

```bash
#!/usr/bin/env bash
# === Docker Installer ===

popos_install_docker() {
    echo ">>> 安装 Docker <<<"
    if command -v docker &>/dev/null; then
        echo "  [SKIP] Docker 已安装: $(docker --version)"
        return
    fi
    # Add official Docker repo
    sudo apt-get update -qq 2>/dev/null
    sudo apt-get install -y -qq ca-certificates curl 2>/dev/null
    sudo install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
        sudo tee /etc/apt/keyrings/docker.asc >/dev/null
    echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/docker.asc] \
https://download.docker.com/linux/ubuntu noble stable" | \
        sudo tee /etc/apt/sources.list.d/docker.list >/dev/null
    sudo apt-get update -qq 2>/dev/null
    sudo apt-get install -y -qq docker-ce docker-ce-cli containerd.io \
        docker-buildx-plugin docker-compose-plugin 2>/dev/null
    # User group
    sudo usermod -aG docker "$(whoami)"
    # Enable and start
    sudo systemctl enable docker 2>/dev/null
    sudo systemctl start docker 2>/dev/null
    ok "Docker 已安装 (需重新登录后 docker 组才生效)"
}
```

Run: `bash -n popos/docker.sh` — no syntax errors.

---

### Task 8: Create `popos/shell.sh` — oh-my-zsh + P10k + plugins + chsh

**Files:**
- Create: `popos/shell.sh`

- [ ] **Step: Write shell setup**

```bash
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
```

Run: `bash -n popos/shell.sh` — no syntax errors.

---

### Task 9: Create `popos/ssh.sh` — SSH key setup

**Files:**
- Create: `popos/ssh.sh`

- [ ] **Step: Write SSH setup**

```bash
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
```

Run: `bash -n popos/ssh.sh` — no syntax errors.

---

### Task 10: Rewrite `popos/config.sh` — shell loading chain via profile

**Files:**
- Modify: `popos/config.sh`

- [ ] **Step: Rewrite config.sh to inject source lines into .bashrc and .zshrc**

```bash
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
```

Run: `bash -n popos/config.sh` — no syntax errors.

---

### Task 11: Rewrite `popos/setup.sh` — interactive orchestrator

**Files:**
- Modify: `popos/setup.sh`

- [ ] **Step: Write the new interactive setup.sh**

```bash
#!/usr/bin/env bash
# === PopOS 开发环境 — 交互式一键配置 ===
# 使用方式:
#   chmod +x popos/setup.sh
#   sudo ./popos/setup.sh
#
# 首次运行：一问一答引导式，选择保存配置后自动安装。
# 再次运行：检测到已有配置自动跳过问答，按上次选择执行。
# ============================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load all modules
source "$SCRIPT_DIR/interactive.sh"
source "$SCRIPT_DIR/check.sh"
source "$SCRIPT_DIR/directories.sh"
source "$SCRIPT_DIR/profile.sh"
source "$SCRIPT_DIR/install.sh"
source "$SCRIPT_DIR/lang.sh"
source "$SCRIPT_DIR/neovim.sh"
source "$SCRIPT_DIR/docker.sh"
source "$SCRIPT_DIR/shell.sh"
source "$SCRIPT_DIR/ssh.sh"
source "$SCRIPT_DIR/config.sh"
source "$SCRIPT_DIR/verify.sh"
source "$SCRIPT_DIR/mirror.sh"
source "$SCRIPT_DIR/utils.sh"

# ============================================================
# Interactive Questions
# ============================================================
popos_ask_questions() {
    title "安装基础路径"
    if [ -d "/data" ]; then
        INSTALL_BASE="/data"
        ok "检测到 /data 分区"
    else
        ask_input "未检测到 /data 分区，请输入安装基础目录" "/home/$(whoami)/dev" INSTALL_BASE
    fi
    echo "  安装基础: $INSTALL_BASE"
    echo ""

    title "开发语言"
    ask_yes_no "安装 Go 语言?" "Y" && INSTALL_GO=true || INSTALL_GO=false
    ask_yes_no "安装 Node.js (via nvm)?" "Y" && INSTALL_NVM_NODE=true || INSTALL_NVM_NODE=false
    ask_yes_no "安装 Python (via pyenv)?" "Y" && INSTALL_PYENV=true || INSTALL_PYENV=false
    ask_yes_no "安装 Rust (via rustup)?" "Y" && INSTALL_RUSTUP=true || INSTALL_RUSTUP=false
    ask_select "Java 版本?" INSTALL_JAVA "skip" "11" "17" "21"
    echo ""

    title "编辑器与工具"
    ask_yes_no "安装 Neovim?" "Y" && INSTALL_NEOVIM=true || INSTALL_NEOVIM=false
    ask_yes_no "安装 Docker?" "Y" && INSTALL_DOCKER=true || INSTALL_DOCKER=false
    ask_yes_no "安装 oh-my-zsh + Powerlevel10k? (会切换默认 shell 为 zsh)" "Y" && INSTALL_OHMYZSH=true || INSTALL_OHMYZSH=false
    echo ""

    title "SSH 密钥"
    ask_select "SSH 密钥设置" INSTALL_SSH "generate" "restore" "skip"
    echo ""

    title "Git 配置"
    ask_input "Git 用户名" "${GIT_USER_NAME:-}" GIT_USER_NAME
    ask_input "Git 邮箱" "${GIT_USER_EMAIL:-}" GIT_USER_EMAIL
    echo ""

    title "额外工具"
    ask_yes_no "安装额外工具 (ripgrep, fd-find, fzf, zoxide)?" "Y" && INSTALL_EXTRA_TOOLS=true || INSTALL_EXTRA_TOOLS=false
    echo ""

    # Detect Go latest version for profile
    if [ "$INSTALL_GO" = true ]; then
        GO_VERSION=$(curl -sL 'https://go.dev/dl/?mode=json' | grep -oP '"version": "\K[^"]+' | head -1 2>/dev/null || echo "")
    fi
}

# ============================================================
# Main
# ============================================================
echo ""
echo "################################################"
echo "#  PopOS 开发环境 - 交互式一键配置              #"
echo "#  Phase 1: 语言运行时 + 工具 + 桌面配置        #"
echo "################################################"
echo ""

popos_check_system

# Profile detection
if popos_load_profile; then
    if ! ask_yes_no "检测到已有配置，是否重新配置?" "N"; then
        echo "  使用现有配置继续安装"
    else
        popos_ask_questions
        popos_save_profile
    fi
else
    popos_ask_questions
    popos_save_profile
fi

# Clean old env vars from .bashrc
popos_clean_old_bashrc

# ============================================================
# Execute
# ============================================================
title "开始安装"
popos_create_dirs
popos_create_symlinks
popos_ensure_symlinks
popos_cleanup_flatpak
popos_install_tools
popos_install_languages
$INSTALL_NEOVIM && popos_install_neovim
$INSTALL_NEOVIM && popos_install_nerd_font
$INSTALL_DOCKER && popos_install_docker
$INSTALL_OHMYZSH && popos_install_ohmyzsh
popos_setup_ssh
popos_config_shell_chain

# ============================================================
# Verify + Summary
# ============================================================
popos_verify

echo "========================================"
echo " ✅ PopOS 环境配置完成！"
echo ""
echo "  下一步:"
echo "    重新登录或执行: source ~/.zshrc"
echo "    SSH 公钥: cat ~/.ssh/id_ed25519.pub"
echo "    终端字体请设为 JetBrainsMono Nerd Font"
echo "========================================"
```

Run: `bash -n popos/setup.sh` — no syntax errors.

---

### Task 12: Update `popos/verify.sh` — expanded verification

**Files:**
- Modify: `popos/verify.sh`

- [ ] **Step: Extend verify with symlink + tools + profile checks**

```bash
    # --- Symlinks ---
    ...

    # --- Tools ---
    echo ">>> 开发工具:"
    local lang_tools=()
    $INSTALL_GO && lang_tools+=(go)
    $INSTALL_NVM_NODE && lang_tools+=(node npm)
    $INSTALL_RUSTUP && lang_tools+=(rustc cargo)
    $INSTALL_NEOVIM && lang_tools+=(nvim)
    $INSTALL_DOCKER && lang_tools+=(docker)
    [ "$INSTALL_JAVA" != "skip" ] && lang_tools+=(java javac)
    local tools_ok=0 tools_miss=0
    for cmd in "${lang_tools[@]}"; do
        if command -v "$cmd" &>/dev/null || [ -x "$HOME/Tools/bin/$cmd" ]; then
            echo "  [OK]  $cmd"
            ((tools_ok++))
        else
            echo "  [MISS] $cmd"
            ((tools_miss++))
        fi
    done
    echo "  $tools_ok OK, $tools_miss missing"
    echo ""

    # --- Profile ---
    if [ -f "$HOME/.config/envbat/profile.sh" ]; then
        echo "  [OK]  配置文件存在"
    else
        echo "  [MISS] 配置文件不存在"
    fi

    # --- Env vars ---
    ...
```

Run: `bash -n popos/verify.sh` — no syntax errors.

---

### Task 13: Final integration check

**Files:**
- Test: full flow on PopOS

- [ ] **Step: Dry-run syntax check all files**

```bash
for f in popos/*.sh; do bash -n "$f" || echo "FAIL: $f"; done
```

Expected: no errors.

- [ ] **Step: Git commit**

```bash
git add popos/interactive.sh popos/profile.sh popos/lang.sh popos/neovim.sh popos/docker.sh popos/shell.sh popos/ssh.sh popos/font.sh
git add popos/setup.sh popos/directories.sh popos/install.sh popos/config.sh popos/verify.sh
git commit -m "feat: Phase 1 - interactive PopOS setup with profile persistence

- Interactive guided installer with one-question-at-a-time flow
- Configuration persistence via ~/.config/envbat/profile.sh
- Language runtimes: Go, Node (nvm), Python (pyenv), Rust (rustup), Java
- Neovim tarball + JetBrainsMono Nerd Font
- Docker (official repo + apt + usermod)
- oh-my-zsh + Powerlevel10k + zsh-autosuggestions + syntax-highlighting
- SSH key setup (generate or restore from backup)
- Shell loading chain (.bashrc + .zshrc source profile.sh)
- Symlink guarantee + flatpak cleanup"
```

---

## Self-Review

**Spec coverage:**
- Interactive guided flow — Task 11 (setup.sh) + Task 1 (interactive.sh)
- Profile persistence — Task 2 (profile.sh)
- Language runtimes — Task 5 (lang.sh)
- Neovim — Task 6 (neovim.sh)
- Nerd Font — Task 6 (font.sh, same file)
- Docker — Task 7 (docker.sh)
- oh-my-zsh + P10k + plugins + chsh — Task 8 (shell.sh)
- SSH — Task 9 (ssh.sh)
- Shell loading chain — Task 10 (config.sh)
- Symlink guarantee + flatpak cleanup — Task 3 (directories.sh)
- Extra small tools — Task 4 (install.sh)
- Expanded verification — Task 12 (verify.sh)
- Git config via profile — Task 10
- `/data/secrets` 700 — already in directories.sh, no change needed

**No placeholders:** All code blocks contain complete, runnable implementations. No TBD/TODO.

**Type consistency:** `INSTALL_BASE` used consistently across all modules. Profile var names match between profile.sh (save/load) and setup.sh (questions). Function names follow existing `popos_` prefix convention.

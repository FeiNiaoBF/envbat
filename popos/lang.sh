#!/usr/bin/env bash
# === Language Runtime Installers ===
# Installs Go, Node (nvm), Python (pyenv), Rust (rustup), Java
# into INSTALL_BASE/tools/.

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

popos_install_languages() {
    $INSTALL_GO      && popos_install_go
    $INSTALL_NVM_NODE && popos_install_nvm_node
    $INSTALL_PYENV   && popos_install_pyenv
    $INSTALL_RUSTUP  && popos_install_rustup
    [ "$INSTALL_JAVA" != "skip" ] && popos_install_java
}

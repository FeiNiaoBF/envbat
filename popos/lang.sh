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
        go_ver=$(curl -sL 'https://go.dev/dl/?mode=json' | grep -oP '"version": "\K[^"]+' | head -1 || true)
    fi
    if [ -z "$go_ver" ]; then
        fail "无法获取 Go 最新版本"
        return 1
    fi
    local arch="linux-amd64"
    local url="https://go.dev/dl/${go_ver}.${arch}.tar.gz"
    echo "  下载 $go_ver ..."
    if curl -#L "$url" | tar -C "$INSTALL_BASE/tools" -xz; then
        ok "Go 已安装: $go_ver"
    else
        fail "Go 下载/解压失败"
        return 1
    fi
    if [ ! -x "$go_root/bin/go" ]; then
        fail "Go 安装后未找到可执行文件"
        return 1
    fi
    if ! mkdir -p "$HOME/Tools/bin" || ! ln -sf "$go_root/bin/go" "$HOME/Tools/bin/go"; then
        fail "Go 命令链接创建失败"
        return 1
    fi
}

popos_install_nvm_node() {
    echo ">>> 安装 Node (via nvm) <<<"
    local nvm_dir="$INSTALL_BASE/tools/nvm"
    if [ -s "$nvm_dir/nvm.sh" ]; then
        echo "  [SKIP] nvm 已安装"
        return
    fi
    export NVM_DIR="$nvm_dir"
    if [ -e "$nvm_dir" ]; then
        fail "nvm 目录存在但安装不完整，请先移走: $nvm_dir"
        return 1
    fi
    if ! git clone --depth 1 https://github.com/nvm-sh/nvm.git "$nvm_dir"; then
        fail "nvm 下载失败"
        return 1
    fi
    if [ ! -s "$nvm_dir/nvm.sh" ]; then
        fail "nvm.sh 不存在"
        return 1
    fi
    # shellcheck source=/dev/null
    source "$nvm_dir/nvm.sh"
    if ! nvm install --lts; then
        fail "Node LTS 安装失败"
        return 1
    fi
    local node_ver
    if ! node_ver=$(node --version 2>/dev/null); then
        fail "Node 安装后无法执行"
        return 1
    fi
    ok "Node 已安装: $node_ver"
}

popos_install_pyenv() {
    echo ">>> 安装 Python (via pyenv) <<<"
    local pyenv_root="$INSTALL_BASE/tools/pyenv"
    if [ -x "$pyenv_root/bin/pyenv" ]; then
        echo "  [SKIP] pyenv 已安装"
        return
    fi
    # Install build dependencies
    if ! sudo apt-get install -y -qq make build-essential libssl-dev zlib1g-dev \
        libbz2-dev libreadline-dev libsqlite3-dev wget curl llvm \
        libncursesw5-dev xz-utils tk-dev libxml2-dev libxmlsec1-dev libffi-dev liblzma-dev; then
        fail "pyenv 构建依赖安装失败"
        return 1
    fi
    if [ -e "$pyenv_root" ]; then
        fail "pyenv 目录存在但安装不完整，请先移走: $pyenv_root"
        return 1
    fi
    if ! git clone --depth 1 https://github.com/pyenv/pyenv.git "$pyenv_root"; then
        fail "pyenv 下载失败"
        return 1
    fi
    ok "pyenv 已安装 (运行 pyenv install 3.x 安装 Python)"
}

popos_install_rustup() {
    echo ">>> 安装 Rust (via rustup) <<<"
    local rustup_home="$INSTALL_BASE/tools/rustup"
    export RUSTUP_HOME="$rustup_home"
    export CARGO_HOME="$INSTALL_BASE/tools/cargo"
    if [ -x "$CARGO_HOME/bin/rustc" ]; then
        echo "  [SKIP] Rust 已安装"
        return
    fi
    if ! curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y; then
        fail "Rust 安装失败"
        return 1
    fi
    if [ ! -x "$CARGO_HOME/bin/rustc" ] || [ ! -x "$CARGO_HOME/bin/cargo" ]; then
        fail "Rust 安装后缺少 rustc/cargo"
        return 1
    fi
    ok "Rust 已安装"
}

popos_install_java() {
    echo ">>> 安装 Java <<<"
    local java_ver="${INSTALL_JAVA:-21}"
    local java_root="$INSTALL_BASE/tools/java/jdk-$java_ver"
    if [ -x "$java_root/bin/java" ]; then
        echo "  [SKIP] Java 已安装"
        return
    fi
    if ! mkdir -p "$INSTALL_BASE/tools/java"; then
        fail "无法创建 Java 安装目录"
        return 1
    fi
    local url="https://download.oracle.com/java/${java_ver}/latest/jdk-${java_ver}_linux-x64_bin.tar.gz"
    echo "  下载 JDK $java_ver ..."
    if ! curl -#L "$url" | tar -C "$INSTALL_BASE/tools/java" -xz; then
        fail "JDK 下载/解压失败"
        return 1
    fi
    # The extracted dir is jdk-{ver}, rename if needed
    local extracted
    extracted=$(find "$INSTALL_BASE/tools/java" -maxdepth 1 -type d -name "jdk-${java_ver}*" | head -1)
    if [ -z "$extracted" ]; then
        fail "未找到 JDK 解压目录"
        return 1
    fi
    if [ -n "$extracted" ] && [ "$extracted" != "$java_root" ]; then
        if ! mv "$extracted" "$java_root"; then
            fail "JDK 安装目录重命名失败"
            return 1
        fi
    fi
    ok "JDK $java_ver 已安装"
    # Symlink
    if [ ! -x "$java_root/bin/java" ] || [ ! -x "$java_root/bin/javac" ]; then
        fail "JDK 安装后缺少 java/javac"
        return 1
    fi
    if ! mkdir -p "$HOME/Tools/bin" || \
        ! ln -sf "$java_root/bin/java" "$HOME/Tools/bin/java" || \
        ! ln -sf "$java_root/bin/javac" "$HOME/Tools/bin/javac"; then
        fail "Java 命令链接创建失败"
        return 1
    fi
}

popos_install_uv() {
    echo ">>> 安装 uv (Python 包管理器) <<<"
    if command -v uv &>/dev/null; then
        echo "  [SKIP] uv 已安装: $(uv --version 2>/dev/null)"
        return 0
    fi
    if ! curl -LsSf https://astral.sh/uv/install.sh | sh; then
        fail "uv 安装失败"
        return 1
    fi
    # 确保 PATH 能找到 uv
    if [ -f "$HOME/.local/bin/uv" ]; then
        export PATH="$HOME/.local/bin:$PATH"
        if ! mkdir -p "$HOME/Tools/bin" || ! ln -sf "$HOME/.local/bin/uv" "$HOME/Tools/bin/uv"; then
            warn "uv 命令链接创建失败（非致命）"
        fi
    fi
    if command -v uv &>/dev/null; then
        ok "uv 已安装: $(uv --version 2>/dev/null)"
    else
        warn "uv 已安装但不在当前 PATH 中，登出再登入后生效"
    fi
}

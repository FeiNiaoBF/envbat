#!/usr/bin/env bash
# === Mise-managed Language Runtime Installers ===

_popos_export_mise_env() {
    export MISE_DATA_DIR="$INSTALL_BASE/tools/mise"
    export MISE_CONFIG_DIR="$HOME/.config/mise"
    export MISE_CACHE_DIR="$INSTALL_BASE/cache/mise"
    export MISE_RUSTUP_HOME="$MISE_DATA_DIR/rustup"
    export MISE_CARGO_HOME="$MISE_DATA_DIR/cargo"
    export RUSTUP_HOME="$MISE_RUSTUP_HOME"
    export CARGO_HOME="$MISE_CARGO_HOME"
    export PATH="$MISE_DATA_DIR/shims:$CARGO_HOME/bin:$INSTALL_BASE/tools/bin:$PATH"
}

popos_mise_is_available() {
    local mise_bin="$INSTALL_BASE/tools/bin/mise"
    [ -x "$mise_bin" ] && "$mise_bin" --version >/dev/null 2>&1
}

popos_install_mise() {
    echo ">>> 安装 mise <<<"
    local mise_bin="$INSTALL_BASE/tools/bin/mise"
    local mise_version
    _popos_export_mise_env

    if [ -x "$mise_bin" ] && mise_version=$("$mise_bin" --version 2>/dev/null); then
        echo "  [SKIP] mise 已安装: $mise_version"
        return 0
    fi
    if ! mkdir -p "$(dirname "$mise_bin")"; then
        fail "无法创建 mise 安装目录"
        return 1
    fi
    if ! curl -LsSf https://mise.run | env MISE_INSTALL_PATH="$mise_bin" sh; then
        fail "mise 安装失败"
        return 1
    fi
    if [ ! -x "$mise_bin" ] || ! mise_version=$("$mise_bin" --version 2>/dev/null); then
        fail "mise 安装结果缺失或不可执行"
        return 1
    fi
    ok "mise 已安装: $mise_version"
}

popos_mise_use() {
    local tool="$1" selector="$2"
    local mise_bin="$INSTALL_BASE/tools/bin/mise"
    local output
    _popos_export_mise_env
    if [ ! -x "$mise_bin" ]; then
        fail "mise 不可用，无法安装 $tool"
        return 1
    fi
    if ! output=$("$mise_bin" use --global "$tool@$selector" 2>&1); then
        [ -n "$output" ] && echo "$output"
        fail "mise 安装失败: $tool@$selector"
        return 1
    fi
    if ! "$mise_bin" where "$tool" >/dev/null 2>&1; then
        fail "mise 未能解析 $tool"
        return 1
    fi
    ok "$tool 已由 mise 管理: $selector"
}

popos_mise_unuse() {
    local tool="$1"
    local mise_bin="$INSTALL_BASE/tools/bin/mise"
    local output
    _popos_export_mise_env
    if [ ! -x "$mise_bin" ]; then
        return 0
    fi
    if ! "$mise_bin" current "$tool" >/dev/null 2>&1; then
        return 0
    fi
    if ! output=$("$mise_bin" unuse --global "$tool" 2>&1); then
        [ -n "$output" ] && echo "$output"
        fail "mise 全局配置移除失败: $tool"
        return 1
    fi
}

popos_install_uv() {
    echo ">>> 安装 uv (Python 包管理器) <<<"
    local uv_bin_dir="$INSTALL_BASE/tools/bin"
    local uv_version

    if [ -x "$uv_bin_dir/uv" ] && [ -x "$uv_bin_dir/uvx" ] && \
        uv_version=$("$uv_bin_dir/uv" --version 2>/dev/null); then
        export PATH="$uv_bin_dir:$PATH"
        echo "  [SKIP] uv 已安装: $uv_version"
        return 0
    fi

    if ! mkdir -p "$uv_bin_dir"; then
        fail "无法创建 uv 安装目录: $uv_bin_dir"
        return 1
    fi
    if ! curl -LsSf https://astral.sh/uv/install.sh | \
        env UV_INSTALL_DIR="$uv_bin_dir" UV_NO_MODIFY_PATH=1 sh; then
        fail "uv 安装失败"
        return 1
    fi

    if [ ! -x "$uv_bin_dir/uv" ] || [ ! -x "$uv_bin_dir/uvx" ]; then
        fail "uv 安装结果不完整（缺少 uv 或 uvx）"
        return 1
    fi
    if ! uv_version=$("$uv_bin_dir/uv" --version 2>/dev/null); then
        fail "uv 安装后无法执行"
        return 1
    fi
    export PATH="$uv_bin_dir:$PATH"
    ok "uv 已安装: $uv_version"
}

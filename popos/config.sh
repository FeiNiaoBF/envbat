#!/usr/bin/env bash
# === PopOS: Environment Variables ===
# Source this from setup-popos.sh only.

popos_config_env() {
    echo "========================================"
    echo " [3/5] 配置环境变量"
    echo "========================================"

    local bashrc="$HOME/.bashrc"
    local guard="# === PopOS Environment ==="

    if grep -qF "$guard" "$bashrc" 2>/dev/null; then
        echo "  [SKIP] 环境变量段已存在 (~/.bashrc)"
        echo ""
        return
    fi

    cat >> "$bashrc" << 'ENVEOF'

# === PopOS Environment ===
export DATA_HOME="/data"
export CODE_HOME="$DATA_HOME/workspace/github"
export TOOLS_HOME="$DATA_HOME/tools"
export HF_HOME="$DATA_HOME/models/huggingface"
export CARGO_HOME="$DATA_HOME/tools/cargo"
export XDG_DATA_HOME="$DATA_HOME/temp/xdg-data"
export XDG_CACHE_HOME="$DATA_HOME/temp/xdg-cache"
export TMPDIR="$DATA_HOME/temp"

# Extend PATH with tools/bin
if [ -d "$TOOLS_HOME/bin" ]; then
    export PATH="$TOOLS_HOME/bin:$PATH"
fi
ENVEOF

    echo "  [OK] 环境变量已追加到 ~/.bashrc"
    echo "  [HINT] 执行 source ~/.bashrc 或重启终端即可生效"
    # 自动 source 使当前会话立即生效
    source "$bashrc" 2>/dev/null && echo "  [OK] 已自动 source ~/.bashrc，环境变量当前会话已生效"
    echo ""
}

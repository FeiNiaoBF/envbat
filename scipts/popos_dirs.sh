#!/usr/bin/env bash
# === PopOS: Directory Structure + Symlinks ===
# Source this from setup-popos.sh only.

DATA_HOME="/data"

popos_create_dirs() {
    echo "========================================"
    echo " [2/5] 创建目录结构"
    echo "========================================"

    local dirs=(
        "$DATA_HOME/workspace/github"
        "$DATA_HOME/workspace/local"
        "$DATA_HOME/workspace/experiments"

        "$DATA_HOME/datasets/raw"
        "$DATA_HOME/datasets/processed"
        "$DATA_HOME/datasets/cache"

        "$DATA_HOME/models/huggingface"
        "$DATA_HOME/models/fine_tuned"
        "$DATA_HOME/models/checkpoints"

        "$DATA_HOME/envs/conda"
        "$DATA_HOME/envs/docker"

        "$DATA_HOME/tools/bin"
        "$DATA_HOME/tools/npm-global"
        "$DATA_HOME/tools/cargo"

        "$DATA_HOME/runs/logs"
        "$DATA_HOME/runs/outputs"
        "$DATA_HOME/runs/mlruns"

        "$DATA_HOME/library"
        "$DATA_HOME/shared"

        "$DATA_HOME/backups/system"
        "$DATA_HOME/backups/dotfiles"
        "$DATA_HOME/backups/home"

        "$DATA_HOME/secrets"
        "$DATA_HOME/temp"
        "$DATA_HOME/archives"
    )

    local count=0
    for d in "${dirs[@]}"; do
        if [ ! -d "$d" ]; then
            sudo mkdir -p "$d" && { echo "  [CREATE] $d"; ((count++)); } || echo "  [FAIL]   $d"
        else
            echo "  [EXISTS] $d"
        fi
    done

    # Ownership
    local user
    user="$(whoami)"
    sudo chown -R "$user:$user" "$DATA_HOME" 2>/dev/null && echo "  [OK] 权限已设为 $user"

    # Secrets 权限收紧
    chmod 700 "$DATA_HOME/secrets" 2>/dev/null && echo "  [OK] secrets 已设为 700"

    echo "  创建 $count 个新目录"
    echo ""
}

popos_create_symlinks() {
    echo ">>> 符号链接 <<<"

    # Map: symlink_name:target_path
    local links=(
        "Code:$DATA_HOME/workspace/github"
        "Projects:$DATA_HOME/workspace/local"
        "Experiments:$DATA_HOME/workspace/experiments"
        "Data:$DATA_HOME"
        "Datasets:$DATA_HOME/datasets"
        "Models:$DATA_HOME/models"
        "Tools:$DATA_HOME/tools"
        "Library:$DATA_HOME/library"
        "Shared:$DATA_HOME/shared"
        "Backups:$DATA_HOME/backups"
    )

    for entry in "${links[@]}"; do
        local name="${entry%%:*}"
        local target="${entry#*:}"
        local link_path="$HOME/$name"

        if [ -L "$link_path" ]; then
            local current
            current="$(readlink "$link_path")"
            if [ "$current" = "$target" ]; then
                echo "  [OK]  ~/$name → $target"
            else
                ln -sfn "$target" "$link_path"
                echo "  [FIX] ~/$name → $target (原指向 $current)"
            fi
        elif [ -e "$link_path" ]; then
            echo "  [SKIP] ~/$name 是真实文件/目录，跳过"
        else
            ln -s "$target" "$link_path"
            echo "  [LINK] ~/$name → $target"
        fi
    done
    echo ""
}

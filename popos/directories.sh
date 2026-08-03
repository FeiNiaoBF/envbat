#!/usr/bin/env bash
# === PopOS: Directory Structure + Symlinks ===

DATA_HOME="${INSTALL_BASE:-/data}"

popos_create_dirs() {
    DATA_HOME="${INSTALL_BASE:-/data}"
    local user
    user="$(whoami)"
    local dirs=(
        "$DATA_HOME/workspace/github" "$DATA_HOME/workspace/local" "$DATA_HOME/workspace/obsidian" "$DATA_HOME/workspace/books"
        "$DATA_HOME/apps"
        "$DATA_HOME/tools/bin" "$DATA_HOME/tools/mise" "$DATA_HOME/tools/fonts"
        "$DATA_HOME/cache/mise"
        "$DATA_HOME/secrets"
    )

    echo ">>> 创建目录结构 <<<"
    if ! sudo mkdir -p "$DATA_HOME" || ! sudo chown "$user:$user" "$DATA_HOME"; then
        fail "无法准备安装基础目录: $DATA_HOME"
        return 1
    fi

    local d failures=0 created=0
    for d in "${dirs[@]}"; do
        if [ -d "$d" ]; then
            echo "  [EXISTS] $d"
            if ! sudo chown "$user:$user" "$d"; then
                echo "  [FAIL]   无法修正目录所有者: $d"
                failures=$((failures + 1))
            fi
        elif mkdir -p "$d"; then
            echo "  [CREATE] $d"
            created=$((created + 1))
        else
            echo "  [FAIL]   $d"
            failures=$((failures + 1))
        fi
    done
    if ! chmod 700 "$DATA_HOME/secrets"; then
        fail "无法设置 secrets 权限"
        failures=$((failures + 1))
    fi
    echo "  创建 $created 个新目录"
    [ "$failures" -eq 0 ]
}

popos_prune_legacy_dirs() {
    echo ">>> 清理遗留目录（仅空目录） <<<"
    local legacy=(
        "$DATA_HOME/workspace/experiments"
        "$DATA_HOME/datasets" "$DATA_HOME/models" "$DATA_HOME/envs" "$DATA_HOME/runs"
        "$DATA_HOME/library" "$DATA_HOME/shared" "$DATA_HOME/archives"
        "$DATA_HOME/temp"
        "$DATA_HOME/backups"
    )
    local d pruned=0 kept=0
    for d in "${legacy[@]}"; do
        if [ ! -e "$d" ]; then
            continue
        fi
        if rmdir "$d" 2>/dev/null; then
            echo "  [PRUNE] $d"
            pruned=$((pruned + 1))
        else
            echo "  [KEEP]  $d (非空，保留)"
            kept=$((kept + 1))
        fi
    done
    echo "  清理 $pruned 个空目录，保留 $kept 个非空目录"
    [ "$kept" -eq 0 ] || warn "存在非空遗留目录，请人工检查后处理"
}

popos_ensure_symlinks() {
    echo ">>> 确保符号链接 <<<"
    local links=(
        "Code:$INSTALL_BASE/workspace/github"
        "Projects:$INSTALL_BASE/workspace/local"
        "Data:$INSTALL_BASE"
        "Tools:$INSTALL_BASE/tools"
    )
    local entry name target link_path failures=0
    for entry in "${links[@]}"; do
        name="${entry%%:*}"
        target="${entry#*:}"
        link_path="$HOME/$name"
        if [ ! -d "$target" ]; then
            echo "  [FAIL] 目标目录不存在: $target"
            failures=$((failures + 1))
        elif [ -L "$link_path" ] && [ "$(readlink "$link_path")" = "$target" ]; then
            echo "  [OK]   ~/$name → $target"
        elif [ -L "$link_path" ]; then
            if ln -sfn "$target" "$link_path"; then
                echo "  [FIX]  ~/$name → $target"
            else
                failures=$((failures + 1))
            fi
        elif [ ! -e "$link_path" ]; then
            if ln -s "$target" "$link_path"; then
                echo "  [LINK] ~/$name → $target"
            else
                failures=$((failures + 1))
            fi
        else
            echo "  [FAIL] ~/$name 已是普通文件或目录，请先人工处理"
            failures=$((failures + 1))
        fi
    done
    [ "$failures" -eq 0 ]
}

popos_cleanup_flatpak() {
    echo ">>> 清理 Flatpak 缓存 <<<"
    if ! command -v flatpak &>/dev/null; then
        echo "  [SKIP] flatpak 未安装"
        return 0
    fi
    local output
    if ! output=$(flatpak uninstall --unused -y 2>&1); then
        echo "$output"
        warn "Flatpak 清理失败"
        return 1
    fi
    [ -n "$output" ] && echo "$output"
    ok "Flatpak 清理完成"
}

#!/usr/bin/env bash
# === Shell Loading Chain ===

_popos_configure_profile_loader() {
    local rc_file="$1"
    local temp_file body_file
    if ! touch "$rc_file"; then
        fail "无法创建或写入 $rc_file"
        return 1
    fi
    if ! temp_file=$(mktemp "${rc_file}.envbat.XXXXXX") || ! body_file=$(mktemp "${rc_file}.body.XXXXXX"); then
        rm -f -- "${temp_file:-}" "${body_file:-}"
        fail "无法创建 rc 临时文件"
        return 1
    fi

    if ! awk '
        $0 == "# === envbat profile ===" { managed=1; next }
        $0 == "# === end envbat profile ===" { managed=0; next }
        managed { next }
        legacy_if {
            if ($0 ~ /^[[:space:]]*fi[[:space:]]*$/) legacy_if=0
            next
        }
        /^[[:space:]]*if .*\.config\/envbat\/profile\.sh.*then[[:space:]]*$/ { legacy_if=1; next }
        /\.config\/envbat\/profile\.sh/ { next }
        $0 == "# === envbat ===" { next }
        $0 == "# envbat — load persisted profile" { next }
        { lines[++count]=$0 }
        END {
            start=1
            while (start <= count && lines[start] ~ /^[[:space:]]*$/) start++
            while (count > 0 && lines[count] ~ /^[[:space:]]*$/) count--
            for (i=start; i<=count; i++) print lines[i]
        }
    ' "$rc_file" > "$body_file"; then
        rm -f -- "$temp_file" "$body_file"
        fail "清理旧 envbat 加载块失败: $rc_file"
        return 1
    fi

    if ! cat > "$temp_file" <<'EOF'
# === envbat profile ===
[ -f "$HOME/.config/envbat/profile.sh" ] && source "$HOME/.config/envbat/profile.sh"
# === end envbat profile ===

EOF
    then
        rm -f -- "$temp_file" "$body_file"
        fail "写入 envbat 加载块失败: $rc_file"
        return 1
    fi
    if ! cat "$body_file" >> "$temp_file" || ! mv -f "$temp_file" "$rc_file"; then
        rm -f -- "$temp_file" "$body_file"
        fail "更新 rc 文件失败: $rc_file"
        return 1
    fi
    rm -f -- "$body_file"
}

popos_config_shell_chain() {
    echo ">>> 配置 Shell 加载链 <<<"
    if ! _popos_configure_profile_loader "$HOME/.bashrc"; then
        return 1
    fi
    if ! _popos_configure_profile_loader "$HOME/.zshrc"; then
        return 1
    fi

    if [ -n "${GIT_USER_NAME:-}" ] && ! git config --global user.name "$GIT_USER_NAME"; then
        fail "Git user.name 设置失败"
        return 1
    fi
    if [ -n "${GIT_USER_EMAIL:-}" ] && ! git config --global user.email "$GIT_USER_EMAIL"; then
        fail "Git user.email 设置失败"
        return 1
    fi
    ok "Shell 加载链已配置"
}

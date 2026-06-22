#!/usr/bin/env bash
# === PopOS setup verification ===

_popos_verify_required_file() {
    local label="$1" path="$2"
    if [ -e "$path" ]; then
        echo "  [OK]   $label"
        return 0
    fi
    echo "  [FAIL] $label: $path"
    return 1
}

_popos_verify_shell_loader() {
    local rc_file="$1"
    if [ -f "$rc_file" ] && \
        grep -Fq '# === envbat profile ===' "$rc_file" && \
        grep -Fq "[ -f \"\$HOME/.config/envbat/profile.sh\" ] && source \"\$HOME/.config/envbat/profile.sh\"" "$rc_file"; then
        echo "  [OK]   $rc_file 加载 envbat profile"
        return 0
    fi
    echo "  [FAIL] $rc_file 缺少 envbat profile 加载块"
    return 1
}

_popos_verify_optional_command() {
    local label="$1" command_name="$2"
    if command -v "$command_name" >/dev/null 2>&1; then
        echo "  [OK]   $label"
    else
        echo "  [WARN] $label 不可用"
    fi
}

_popos_verify_optional_path() {
    local label="$1" path="$2"
    if [ -e "$path" ]; then
        echo "  [OK]   $label"
    else
        echo "  [WARN] $label marker 缺失: $path"
    fi
}

popos_verify() {
    local failures=0 path command_name
    local profile="$HOME/.config/envbat/profile.sh"
    local base="${INSTALL_BASE:-/data}"

    echo "========================================"
    echo " [5/5] 验证配置"
    echo "========================================"
    echo ">>> Required invariants"

    if [ -f "$profile" ] && grep -Eq '^ENVBAT_PROFILE_SCHEMA=2$' "$profile"; then
        echo "  [OK]   profile schema v2"
    else
        echo "  [FAIL] profile 缺失或不是 schema v2"
        failures=$((failures + 1))
    fi

    for path in "$base" "$base/workspace/github" "$base/tools/bin" "$base/temp"; do
        if ! _popos_verify_required_file "核心目录" "$path"; then
            failures=$((failures + 1))
        fi
    done

    if ! _popos_verify_shell_loader "$HOME/.bashrc"; then failures=$((failures + 1)); fi
    if ! _popos_verify_shell_loader "$HOME/.zshrc"; then failures=$((failures + 1)); fi

    for command_name in git curl wget gcc make unzip tar python3 zsh; do
        if command -v "$command_name" >/dev/null 2>&1; then
            echo "  [OK]   $command_name"
        else
            echo "  [FAIL] 必需命令缺失: $command_name"
            failures=$((failures + 1))
        fi
    done

    echo ""
    echo ">>> Optional selections"
    if [ "${INSTALL_EXTRA_TOOLS:-false}" = true ]; then
        for command_name in rg fdfind fzf zoxide; do
            _popos_verify_optional_command "$command_name" "$command_name"
        done
    else
        echo "  [SKIP] extra tools disabled"
    fi

    if [ "${INSTALL_OHMYZSH:-false}" = true ]; then
        _popos_verify_optional_path "oh-my-zsh" "$HOME/.oh-my-zsh/oh-my-zsh.sh"
        _popos_verify_optional_path "Powerlevel10k" "$HOME/.oh-my-zsh/custom/themes/powerlevel10k/powerlevel10k.zsh-theme"
        _popos_verify_optional_path "zsh-autosuggestions" "$HOME/.oh-my-zsh/custom/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh"
        _popos_verify_optional_path "zsh-syntax-highlighting" "$HOME/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
    else
        echo "  [SKIP] oh-my-zsh disabled"
    fi

    if [ "${INSTALL_GO:-false}" = true ]; then _popos_verify_optional_command "Go" go; fi
    if [ "${INSTALL_NVM_NODE:-false}" = true ]; then _popos_verify_optional_path "nvm" "$base/tools/nvm/nvm.sh"; fi
    if [ "${INSTALL_PYENV:-false}" = true ]; then _popos_verify_optional_path "pyenv" "$base/tools/pyenv/bin/pyenv"; fi
    if [ "${INSTALL_RUSTUP:-false}" = true ]; then _popos_verify_optional_path "rustc" "$base/tools/cargo/bin/rustc"; fi
    if [ "${INSTALL_NEOVIM:-false}" = true ]; then _popos_verify_optional_command "Neovim" nvim; fi
    if [ "${INSTALL_DOCKER:-false}" = true ]; then _popos_verify_optional_command "Docker" docker; fi
    if [ "${INSTALL_JAVA:-skip}" != skip ]; then _popos_verify_optional_command "Java" java; fi

    if [ "${INSTALL_CHINESE:-false}" = true ]; then
        _popos_verify_optional_command "fcitx5" fcitx5
        _popos_verify_optional_path "fcitx5 autostart" "$HOME/.config/autostart/org.fcitx.Fcitx5.desktop"
        if [ -f "$HOME/.xinputrc" ] && grep -Fq fcitx5 "$HOME/.xinputrc"; then
            echo "  [OK]   im-config 使用 fcitx5"
        else
            echo "  [WARN] im-config marker 缺失"
        fi
    else
        echo "  [SKIP] Chinese input disabled"
    fi

    echo ""
    echo "  required failures: $failures"
    [ "$failures" -eq 0 ]
}

popos_summary() {
    local base="${INSTALL_BASE:-/data}" sym_ok=0 name
    echo "========================================"
    echo " 系统状态摘要"
    echo "========================================"
    if [ -d "$base" ]; then
        df -h "$base" 2>/dev/null | awk 'NR==2 {printf "  安装盘: %s / %s (%s)\n", $3, $2, $5}' || true
    fi
    df -h / 2>/dev/null | awk 'NR==2 {printf "  系统盘: %s / %s (%s)\n", $3, $2, $5}' || true
    free -h 2>/dev/null | awk 'NR==2 {printf "  内存:   %s / %s\n", $3, $2}' || true
    echo "  Shell: ${SHELL:-unknown}"

    for name in Code Projects Data Tools; do
        if [ -L "$HOME/$name" ]; then sym_ok=$((sym_ok + 1)); fi
    done
    echo "  符号链接: $sym_ok/4"
    if command -v ufw >/dev/null 2>&1; then
        echo "  防火墙: $(sudo ufw status 2>/dev/null | head -1 || echo unknown)"
    else
        echo "  防火墙: not installed"
    fi
    if command -v systemctl >/dev/null 2>&1; then
        echo "  Fail2ban: $(systemctl is-active fail2ban 2>/dev/null || echo inactive)"
    fi
}

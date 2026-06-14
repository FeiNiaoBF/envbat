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

#!/usr/bin/env bash
# === PopOS: Power Settings (Interactive) ===
# 独立使用:
#   chmod +x popos/popos-power.sh
#   ./popos/popos-power.sh
#
# 交互式设置空闲延时与锁屏延时，适合插电/电池场景。
# 幂等 — 重复执行可调整。
#
# 概念说明:
#   空闲延时 (idle-delay)  → 多久无操作后黑屏/屏保 (省电)
#   锁屏延时 (lock-delay)  → 黑屏后再过多久才锁定 (安全)
#   总等待 = 空闲 + 锁屏。设 0 = 从不。
# ============================================================
set -euo pipefail

# ---- ANSI colour ----
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Colour

ok()   { echo -e "  ${GREEN}[OK]${NC} $1"; }
skip() { echo -e "  ${YELLOW}[SKIP]${NC} $1"; }
warn() { echo -e "  ${RED}[WARN]${NC} $1"; }
info() { echo -e "  ${CYAN}$1${NC}"; }

# ---- helpers ----
seconds_to_display() {
    local raw="$1" s
    if [[ "$raw" =~ ([0-9]+)$ ]]; then
        s="${BASH_REMATCH[1]}"
    else
        echo "未知"
        return 0
    fi
    if [ "$s" -eq 0 ]; then
        echo "从不"
    else
        local m r
        m=$((s / 60))
        r=$((s % 60))
        if [[ $m -gt 0 && $r -gt 0 ]]; then
            echo "${m}分${r}秒"
        elif [[ $m -gt 0 ]]; then
            echo "${m}分钟"
        else
            echo "${r}秒"
        fi
    fi
}

gget() {
    gsettings get "$1" "$2" 2>/dev/null || echo "(无法读取)"
}

gset() {
    if gsettings set "$1" "$2" "$3" 2>/dev/null; then
        [ -n "$4" ] && ok "$4"
        return 0
    fi
    [ -n "$5" ] && warn "$5"
    return 1
}

read_minutes() {
    local prompt=$1 default=$2 var_name=$3
    local input
    while true; do
        read -r -p "  $prompt (分钟, 0=从不, 默认=${default}): " input
        input="${input:-$default}"
        if [[ "$input" =~ ^[0-9]+$ ]]; then
            printf -v "$var_name" "%s" "$input"
            return 0
        fi
        warn "请输入正整数或0"
    done
}

# ===== 主函数 =====
popos_power_settings() {
    echo ""

    if ! command -v gsettings >/dev/null 2>&1; then
        warn "gsettings 不可用"
        return 1
    fi
    echo "========================================"
    echo " PopOS 电源管理 — 交互设置"
    echo "========================================"
    echo ""

    # ---- 1. 显示当前设置 ----
    echo "--- 当前设置 ---"
    local idle_raw lock_raw
    idle_raw=$(gget org.gnome.desktop.session idle-delay)
    lock_raw=$(gget org.gnome.desktop.screensaver lock-delay)

    # 提取数值
    local idle_sec=0 lock_sec=0
    if [[ "$idle_raw" =~ ([0-9]+)$ ]]; then idle_sec="${BASH_REMATCH[1]}"; fi
    if [[ "$lock_raw" =~ ([0-9]+)$ ]]; then lock_sec="${BASH_REMATCH[1]}"; fi

    echo "  空闲延时:    $(seconds_to_display "$idle_raw") (idle-delay)"
    echo "  锁屏延时:    $(seconds_to_display "$lock_raw") (lock-delay)"
    echo "  总等待锁屏:  $(seconds_to_display "$(( idle_sec + lock_sec ))")"
    echo ""

    # ---- 2. 省电与安全说明 ----
    echo "--- 策略说明 ---"
    info "  省电: 空闲后黑屏 → 减少耗电"
    info "  安全: 黑屏后再锁定 → 需密码解锁"
    info "  建议插电: 空闲5-15分, 锁屏5分 (总等待10-20分)"
    info "  建议离席: 空闲2-5分, 锁屏1-2分 (总等待3-7分)"
    echo ""

    # ---- 3. 交互输入 ----
    echo "--- 请输入数值 ---"
    echo "  (0 = 从不, 纯回车=默认值)"
    echo ""

    local idle_min lock_min
    read_minutes "空闲后黑屏" 10 idle_min
    read_minutes "黑屏后锁定" 5 lock_min

    echo ""

    # ---- 4. 应用设置 ----
    echo "--- 应用设置 ---"

    local idle_sec_new lock_sec_new
    idle_sec_new=$((idle_min * 60))
    lock_sec_new=$((lock_min * 60))
    local failures=0

    # 空闲延时
    if [[ "$idle_min" == "0" ]]; then
        if ! gset org.gnome.desktop.session idle-delay 0 \
            "空闲延时已设为 从不 (屏幕常亮)" \
            "空闲延时设置失败"; then failures=$((failures + 1)); fi
        # 同时关闭空闲 dim
        if ! gset org.gnome.settings-daemon.plugins.power idle-dim false \
            "" "idle-dim 设置失败"; then failures=$((failures + 1)); fi
    else
        if ! gset org.gnome.desktop.session idle-delay "$idle_sec_new" \
            "空闲延时已设为 ${idle_min} 分钟" \
            "空闲延时设置失败"; then failures=$((failures + 1)); fi
        if ! gset org.gnome.settings-daemon.plugins.power idle-dim true \
            "" "idle-dim 设置失败"; then failures=$((failures + 1)); fi
    fi

    # 锁屏延时
    if [[ "$lock_min" == "0" ]]; then
        if ! gset org.gnome.desktop.screensaver lock-delay 0 \
            "锁屏延时已设为 从不 (黑屏但不锁)" \
            "锁屏延时设置失败"; then failures=$((failures + 1)); fi
    else
        if ! gset org.gnome.desktop.screensaver lock-delay "$lock_sec_new" \
            "锁屏延时已设为 ${lock_min} 分钟" \
            "锁屏延时设置失败"; then failures=$((failures + 1)); fi
    fi

    # 确保锁屏功能启用
    if ! gset org.gnome.desktop.screensaver lock-enabled true \
        "锁屏功能已启用" \
        "锁屏功能启用失败"; then failures=$((failures + 1)); fi

    echo ""

    # ---- 5. 验证结果 ----
    echo "--- 验证结果 ---"
    local new_idle new_lock
    new_idle=$(gget org.gnome.desktop.session idle-delay)
    new_lock=$(gget org.gnome.desktop.screensaver lock-delay)
    local nidle nlock
    nidle=0
    nlock=0
    if [[ "$new_idle" =~ ([0-9]+)$ ]]; then nidle="${BASH_REMATCH[1]}"; fi
    if [[ "$new_lock" =~ ([0-9]+)$ ]]; then nlock="${BASH_REMATCH[1]}"; fi

    echo "  空闲延时:  $(seconds_to_display "$new_idle")"
    echo "  锁屏延时:  $(seconds_to_display "$new_lock")"
    echo "  总等待锁屏: $(seconds_to_display "$(( nidle + nlock ))")"

    if [[ "$nidle" == "$idle_sec_new" && "$nlock" == "$lock_sec_new" ]]; then
        ok "设置已生效"
    else
        warn "设置可能未完全生效，请检查 gsettings 权限"
        failures=$((failures + 1))
    fi
    echo ""
    echo "========================================"
    if [ "$failures" -gt 0 ]; then
        echo " 设置完成但有 $failures 项失败"
    else
        echo " 设置完成"
    fi
    echo "========================================"
    echo ""
    [ "$failures" -eq 0 ]
}

# ===== 入口 =====
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    popos_power_settings
fi

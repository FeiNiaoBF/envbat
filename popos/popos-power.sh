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
    local s=$1
    if [[ "$s" == "0" || "$s" == "uint32 0" ]]; then
        echo "从不"
    else
        local m=$(( s / 60 ))
        local r=$(( s % 60 ))
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
    gsettings set "$1" "$2" "$3" 2>/dev/null && ok "$4" || warn "$5"
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
    echo "========================================"
    echo " PopOS 电源管理 — 交互设置"
    echo "========================================"
    echo ""

    # ---- 1. 显示当前设置 ----
    echo "--- 当前设置 ---"
    local idle_raw lock_raw dim_raw
    idle_raw=$(gget org.gnome.desktop.session idle-delay)
    lock_raw=$(gget org.gnome.desktop.screensaver lock-delay)
    dim_raw=$(gget org.gnome.settings-daemon.plugins.power idle-dim)

    # 提取数值
    local idle_sec=0 lock_sec=0
    idle_sec=$(echo "$idle_raw" | grep -oP '\d+' | head -1)
    lock_sec=$(echo "$lock_raw" | grep -oP '\d+' | head -1)
    idle_sec=${idle_sec:-0}
    lock_sec=${lock_sec:-0}

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

    local idle_sec_new=$(( idle_min * 60 ))
    local lock_sec_new=$(( lock_min * 60 ))

    # 空闲延时
    if [[ "$idle_min" == "0" ]]; then
        gset org.gnome.desktop.session idle-delay 0 \
            "空闲延时已设为 从不 (屏幕常亮)" \
            "空闲延时设置失败"
        # 同时关闭空闲 dim
        gset org.gnome.settings-daemon.plugins.power idle-dim false \
            "" ""
    else
        gset org.gnome.desktop.session idle-delay "$idle_sec_new" \
            "空闲延时已设为 ${idle_min} 分钟" \
            "空闲延时设置失败"
        gset org.gnome.settings-daemon.plugins.power idle-dim true \
            "" ""
    fi

    # 锁屏延时
    if [[ "$lock_min" == "0" ]]; then
        gset org.gnome.desktop.screensaver lock-delay 0 \
            "锁屏延时已设为 从不 (黑屏但不锁)" \
            "锁屏延时设置失败"
    else
        gset org.gnome.desktop.screensaver lock-delay "$lock_sec_new" \
            "锁屏延时已设为 ${lock_min} 分钟" \
            "锁屏延时设置失败"
    fi

    # 确保锁屏功能启用
    gset org.gnome.desktop.screensaver lock-enabled true \
        "锁屏功能已启用" \
        ""

    echo ""

    # ---- 5. 验证结果 ----
    echo "--- 验证结果 ---"
    local new_idle new_lock
    new_idle=$(gget org.gnome.desktop.session idle-delay)
    new_lock=$(gget org.gnome.desktop.screensaver lock-delay)
    local nidle nlock
    nidle=$(echo "$new_idle" | grep -oP '\d+' | head -1)
    nlock=$(echo "$new_lock" | grep -oP '\d+' | head -1)
    nidle=${nidle:-0}
    nlock=${nlock:-0}

    echo "  空闲延时:  $(seconds_to_display "$new_idle")"
    echo "  锁屏延时:  $(seconds_to_display "$new_lock")"
    echo "  总等待锁屏: $(seconds_to_display "$(( nidle + nlock ))")"

    if [[ "$nidle" == "$idle_sec_new" && "$nlock" == "$lock_sec_new" ]]; then
        ok "设置已生效"
    else
        warn "设置可能未完全生效，请检查 gsettings 权限"
    fi
    echo ""
    echo "========================================"
    echo " 完成！如需调整请重新运行本脚本"
    echo "========================================"
    echo ""
}

# ===== 入口 =====
popos_power_settings

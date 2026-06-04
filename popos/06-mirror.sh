#!/usr/bin/env bash
# === 镜像源切换 ===
# 自动检测国家，国内使用华为云镜像，海外使用官方源
# 依赖: curl
#
# 使用方式:
#   popos_setup_mirror                    # 只切换源，不升级不清缓存
#   popos_setup_mirror true               # 切换源 + 升级软件
#   popos_setup_mirror true true          # 切换源 + 升级软件 + 清理缓存
#
# 注意: 会调用 linuxmirrors.cn 交互脚本，但已启用 --pure-mode 减少交互
# ============================================================

popos_setup_mirror() {
    local upgrade_software=${1:-false}
    local clean_cache=${2:-false}

    echo "检测网络环境..."

    local country
    country=$(curl -s ipinfo.io/country 2>/dev/null || echo "")

    if [ -z "$country" ]; then
        echo "警告: 无法检测国家，将使用官方源"
    else
        echo "检测到国家: $country"
    fi

    if [ "$country" = "CN" ]; then
        echo "国内网络，使用 Huawei Cloud 镜像源 ..."
        bash <(curl -sSL https://linuxmirrors.cn/main.sh) \
            --source mirrors.huaweicloud.com \
            --protocol https \
            --use-intranet-source false \
            --backup true \
            --upgrade-software "$upgrade_software" \
            --clean-cache "$clean_cache" \
            --ignore-backup-tips \
            --install-epel false \
            --pure-mode
    else
        echo "海外网络，使用官方源 ..."
        bash <(curl -sSL https://linuxmirrors.cn/main.sh) \
            --use-official-source true \
            --protocol https \
            --use-intranet-source false \
            --backup true \
            --upgrade-software "$upgrade_software" \
            --clean-cache "$clean_cache" \
            --ignore-backup-tips \
            --install-epel false \
            --pure-mode
    fi

    return 0
}

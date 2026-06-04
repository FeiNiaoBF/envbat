#!/usr/bin/env bash
# === PopOS 开发环境一键配置 ===
# 使用方式:
#   chmod +x scipts/setup-popos.sh
#   sudo ./scipts/setup-popos.sh
#
# 或在 ~/.bashrc 后手动 source:
#   source ~/.bashrc
#
# 模块文件 (scipts/ 下):
#   popos_check.sh   — 系统环境检查
#   popos_dirs.sh    — 目录结构 + 符号链接
#   popos_config.sh  — 环境变量注入
#   popos_install.sh — 基础工具安装
#   popos_verify.sh  — 验收确认
#
# 注意: 需要 sudo 时脚本会自动请求，建议直接以 sudo 运行。
# ============================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 加载各模块
# shellcheck source=popos_check.sh
source "$SCRIPT_DIR/popos_check.sh"
# shellcheck source=popos_dirs.sh
source "$SCRIPT_DIR/popos_dirs.sh"
# shellcheck source=popos_config.sh
source "$SCRIPT_DIR/popos_config.sh"
# shellcheck source=popos_install.sh
source "$SCRIPT_DIR/popos_install.sh"
# shellcheck source=popos_verify.sh
source "$SCRIPT_DIR/popos_verify.sh"

# ----- 主流程 -----
echo ""
echo "################################################"
echo "#  PopOS 开发环境 - 一键配置                    #"
echo "################################################"
echo ""

popos_check_system
popos_create_dirs
popos_create_symlinks
popos_config_env
popos_install_tools
popos_verify

echo "========================================"
echo " ✅ PopOS 环境配置完成！"
echo ""
echo " 下一步:"
echo "    source ~/.bashrc"
echo "    或重启终端加载环境变量"
echo "========================================"

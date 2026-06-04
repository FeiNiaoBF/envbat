#!/usr/bin/env bash
# === PopOS 开发环境一键配置 ===
# 使用方式:
#   chmod +x popos/setup.sh
#   sudo ./popos/setup.sh
#
# 或在 ~/.bashrc 后手动 source:
#   source ~/.bashrc
#
# 模块文件 (popos/ 下):
#   check.sh        — 系统环境检查
#   directories.sh  — 目录结构 + 符号链接
#   config.sh       — 环境变量注入
#   install.sh      — 基础工具安装
#   verify.sh       — 验收确认
#   mirror.sh       — [工具] 镜像源切换（自动识别国内/海外）
#   utils.sh        — [工具] 实用函数集（智能安装/系统更新/systemctl/暂停）
#
# 注意:
#   - mirror.sh/utils.sh 仅 source 不自动执行，供交互式使用
#   - 需要 sudo 时脚本会自动请求，建议直接以 sudo 运行。
# ============================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 加载各模块
# shellcheck source=check.sh
source "$SCRIPT_DIR/check.sh"
# shellcheck source=directories.sh
source "$SCRIPT_DIR/directories.sh"
# shellcheck source=config.sh
source "$SCRIPT_DIR/config.sh"
# shellcheck source=install.sh
source "$SCRIPT_DIR/install.sh"
# shellcheck source=verify.sh
source "$SCRIPT_DIR/verify.sh"

# 实用工具模块（仅 source，不自动执行，交互式使用）
# shellcheck source=mirror.sh
source "$SCRIPT_DIR/mirror.sh"
# shellcheck source=utils.sh
source "$SCRIPT_DIR/utils.sh"

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

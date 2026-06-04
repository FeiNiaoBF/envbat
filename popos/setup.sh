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
#   01-check.sh        — 系统环境检查
#   02-directories.sh  — 目录结构 + 符号链接
#   03-config.sh       — 环境变量注入
#   04-install.sh      — 基础工具安装
#   05-verify.sh       — 验收确认
#   06-mirror.sh       — [工具] 镜像源切换（自动识别国内/海外）
#   07-utils.sh        — [工具] 实用函数集（智能安装/系统更新/systemctl/暂停）
#
# 注意:
#   - 06/07 模块仅 source 不自动执行，供交互式使用
#   - 需要 sudo 时脚本会自动请求，建议直接以 sudo 运行。
# ============================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 加载各模块
# shellcheck source=01-check.sh
source "$SCRIPT_DIR/01-check.sh"
# shellcheck source=02-directories.sh
source "$SCRIPT_DIR/02-directories.sh"
# shellcheck source=03-config.sh
source "$SCRIPT_DIR/03-config.sh"
# shellcheck source=04-install.sh
source "$SCRIPT_DIR/04-install.sh"
# shellcheck source=05-verify.sh
source "$SCRIPT_DIR/05-verify.sh"

# 实用工具模块（仅 source，不自动执行，交互式使用）
# shellcheck source=06-mirror.sh
source "$SCRIPT_DIR/06-mirror.sh"
# shellcheck source=07-utils.sh
source "$SCRIPT_DIR/07-utils.sh"

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

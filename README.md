# envbat

跨平台环境配置自动化脚本集。

## 目录结构

```
envbat/
├── README.md
├── windows/              # Windows 环境配置
│   ├── setup.ps1         # ── 入口：依次执行 01→02
│   ├── 01-check.ps1      # 检测已安装的编程语言环境
│   └── 02-download.ps1   # 下载选取的编程语言安装包
└── popos/                # Pop!_OS 环境配置
    ├── setup.sh           # ── 入口：依次执行 check→verify（mirror/utils 仅 source）
    ├── check.sh           # 检测系统环境
    ├── directories.sh     # 创建目录结构 + 符号链接
    ├── config.sh          # 配置环境变量
    ├── install.sh         # 安装基础工具
    ├── verify.sh          # 验证配置结果
    ├── mirror.sh          # [工具] 镜像源切换（自动识别国内/海外）
    ├── utils.sh           # [工具] 实用函数集（智能安装/更新/systemctl/暂停）
    └── popos-power.sh     # [独立] 交互式电源管理（空闲/锁屏延时）
```

## 使用方式

### Windows

```powershell
# 以管理员身份运行
.\windows\setup.ps1
```

### PopOS

```bash
chmod +x popos/setup.sh
sudo ./popos/setup.sh

# 电源管理（独立工具，不需 root）
chmod +x popos/popos-power.sh
./popos/popos-power.sh
```

### Backup & Restore (PopOS)

Backup your configuration, package list, and system settings:

```bash
# 备份
./popos/backup.sh

# 恢复最新备份（全部）
./popos/restore.sh

# 恢复最新备份（逐项确认）
./popos/restore.sh -i

# 恢复指定备份
./popos/restore.sh -d 2026-06-14T1530+0800
```

## 设计原则

- **模块化** — 每个文件单一职责，入口脚本串联流程
- **自修复** — 检测已有状态，只做需要的操作
- **幂等** — 重复执行不会破坏已有配置

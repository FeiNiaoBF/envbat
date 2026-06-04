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
    ├── setup.sh           # ── 入口：依次执行 01→05
    ├── 01-check.sh        # 检测系统环境
    ├── 02-directories.sh  # 创建目录结构 + 符号链接
    ├── 03-config.sh       # 配置环境变量
    ├── 04-install.sh      # 安装基础工具
    └── 05-verify.sh       # 验证配置结果
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
```

## 设计原则

- **模块化** — 每个文件单一职责，入口脚本串联流程
- **自修复** — 检测已有状态，只做需要的操作
- **幂等** — 重复执行不会破坏已有配置

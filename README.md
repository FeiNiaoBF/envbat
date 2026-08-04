# envbat

跨平台环境配置自动化脚本集。

## 目录结构

```
envbat/
├── README.md
├── windows/              # Windows 环境配置
│   ├── setup.ps1         # ── 入口：交互式安装编排器
│   ├── check.ps1         # 检测已安装的编程语言环境
│   ├── download.ps1      # 下载选取的编程语言安装包
│   ├── install.ps1       # 自动安装/解压各语言运行时
│   ├── config.ps1        # 配置 PATH / JAVA_HOME
│   └── verify.ps1        # 验证安装结果
└── popos/                # Pop!_OS 环境配置
    ├── setup.sh           # ── 入口：初始化 / repair / reconfigure
    ├── runner.sh          # 阶段执行器：OK/SKIP/WARN/FAIL 汇总
    ├── check.sh           # 检测系统环境
    ├── directories.sh     # 创建目录结构 + 符号链接 + 清理遗留空目录
    ├── config.sh          # 配置环境变量
    ├── install.sh         # 安装基础工具
    ├── lang.sh            # mise 管理 Go / Node / Python / Rust / Java；uv 独立安装
    ├── shell.sh           # zsh / oh-my-zsh / Powerlevel10k
    ├── security.sh        # UFW / Fail2ban / 自动安全更新
    ├── locale.sh          # 中文 locale / fcitx5 输入法
    ├── docker.sh          # Docker 官方源与插件
    ├── backup.sh          # staging 校验后原子发布备份（支持 --target / --install-cron）
    ├── restore.sh         # manifest v2 校验后的安全恢复
    ├── manifest.py        # manifest、校验和与路径验证
    ├── verify.sh          # 验证配置结果
    └── popos-power.sh     # [独立] 交互式电源管理（空闲/锁屏延时）
```

## 数据目录布局（/data）

大分类设计：仅 5 个一级目录，规划写进 README 而非空目录。

```
/data/
├── workspace/   # 个人数据（唯一不可再生区）
│   ├── github/      GitHub 克隆
│   ├── local/       本地项目
│   ├── obsidian/    Obsidian 知识库
│   └── books/       电子书
├── apps/        # 应用软件（flatpak / appimage / resilio）
├── tools/       # 工具链（mise 运行时 / fonts / bin）
├── cache/       # 可再生缓存（mise 缓存 / 临时文件，可随时删）
└── secrets/     # 密钥（权限 700，备份时排除）
```

规划备忘（将来需要时再建，用官方变量配置，不自己造目录体系）：

- AI 训练流水线：`models/` `datasets/` `runs/` `envs/`，对应 `HF_HOME`、`CONDA_ENVS_PATH`、docker `data-root`
- 环境一律由官方机制管理：mise（`MISE_DATA_DIR`）、conda（`CONDA_ENVS_PATH`）、docker（`data-root`）

备份目标位于系统盘 `/backup`（数据盘与系统盘互备，无外部介质下的现实方案）。

## 使用方式

### Windows

```powershell
# 以管理员身份运行
.\windows\setup.ps1
```

### PopOS

```bash
chmod +x popos/setup.sh
./popos/setup.sh   # 脚本内部自动调用 sudo

# 修复/补装模式：复用 ~/.config/envbat/profile.sh，不重新问答
./popos/setup.sh --repair

# 重新配置：以当前选择为默认值，确认后保存并执行
./popos/setup.sh --reconfigure

# 电源管理（独立工具，不需 root）
chmod +x popos/popos-power.sh
./popos/popos-power.sh
```

语言运行时统一由 mise 管理：Go 使用 `latest`，Node.js 使用 `lts`，Python 使用 `latest`，Rust 使用 `stable`，Java 使用所选的 Temurin 11/17/21。mise 二进制位于官方默认位置 `~/.local/bin/mise`，长期运行时和 shims 位于 `$INSTALL_BASE/tools/mise`（`MISE_DATA_DIR`），可删除缓存位于 `$INSTALL_BASE/cache/mise`，配置位于 `~/.config/mise/config.toml`。交互式 shell 使用 `mise activate`，IDE 和非交互命令使用 shims；项目可通过仓库内的 `mise.toml` 覆盖全局版本。

profile 不再覆盖 `XDG_DATA_HOME` 或 `XDG_CACHE_HOME`，其他应用使用系统默认的 `~/.local/share` 和 `~/.cache`；只有 mise 通过专用变量使用 `/data`。旧 nvm、pyenv、rustup 和 Go 目录不会自动删除，但 schema 4 profile 不再把它们加入 `PATH`。`uv` 和 `uvx` 默认由 mise 管理；独立安装分支（`popos_install_uv`）安装到官方默认位置 `~/.local/bin`。

### Backup & Restore (PopOS)

备份用户配置、包列表和系统设置到系统盘 `/backup`：

```bash
# 首次准备备份目录（一次）
sudo mkdir -p /backup && sudo chown $USER:$USER /backup

# 备份（默认 /backup/envbat）
./popos/backup.sh

# 备份到自定义位置
./popos/backup.sh --target /path/to/backup

# 安装每日 workspace 数据备份 cron（rsync 到 /backup/workspace）
./popos/backup.sh --install-cron

# 备份会生成:
#   MANIFEST.txt    给人阅读
#   manifest.json   给 restore 脚本读取

# 恢复最新备份（默认恢复用户态内容）
./popos/restore.sh

# 高级恢复模式（额外提供系统配置和 apt 包恢复选项）
./popos/restore.sh -i

# 恢复指定备份
./popos/restore.sh -d 2026-06-14T1530+0800
```

Restore 默认策略：

- 默认恢复 dotfiles、envbat profile、mise 配置、Neovim、oh-my-zsh custom、目录结构和缺失的 Git 仓库
- `.ssh` 必须单独确认
- 不默认恢复 apt sources、hosts、hostname、crontab、netplan
- 不默认执行完整 apt 包列表恢复
- 结束时询问是否运行 `./popos/setup.sh --repair`

备份与恢复契约：

- 备份目标在系统盘 `/backup`（默认），与数据盘 `/data` 互备；`secrets/` 与 `cache/` 在目录树导出中显式排除
- profile 使用 `ENVBAT_PROFILE_SCHEMA=4`；schema 2 的语言选择自动迁移到 mise，其他旧 profile 保守迁移，缺失的新选项默认关闭
- 备份先写入权限为 `700` 的 staging 目录，归档和 manifest 权限为 `600`
- dotfiles 和 manifest 成功并通过 SHA-256 校验后，才更新 `latest`
- `manifest.json` 当前 schema 为 v2；restore 明确拒绝 v1、缺失文件和校验和损坏
- 恢复写入前创建安全快照；dotfiles、mise、Neovim、oh-my-zsh custom 和 SSH 使用临时目标替换
- Git 只 clone 不存在的仓库，不 pull 或覆盖已有路径
- netplan 仅备份供人工检查，不自动恢复

阶段状态含义：

- `OK`：阶段成功
- `SKIP`：用户禁用、备份缺失或不适用
- `WARN`：可选阶段失败，流程继续
- `FAIL`：必需阶段失败，流程停止

仅有 `WARN` 时进程退出码仍为 `0`，最终标题显示 `COMPLETED WITH WARNINGS`；存在 required `FAIL` 时退出码为 `1`。

Windows backup/restore 将在后续阶段补齐；当前 Windows 只覆盖轻量开发环境初始化。

## 设计原则

- **模块化** — 每个文件单一职责，入口脚本串联流程
- **自修复** — 检测已有状态，只做需要的操作
- **幂等** — 重复执行不会破坏已有配置

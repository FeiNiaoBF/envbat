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
    ├── directories.sh     # 创建目录结构 + 符号链接
    ├── config.sh          # 配置环境变量
    ├── install.sh         # 安装基础工具
    ├── lang.sh            # Go / Node / pyenv / Rust / Java
    ├── shell.sh           # zsh / oh-my-zsh / Powerlevel10k
    ├── security.sh        # UFW / Fail2ban / 自动安全更新
    ├── locale.sh          # 中文 locale / fcitx5 输入法
    ├── docker.sh          # Docker 官方源与插件
    ├── backup.sh          # staging 校验后原子发布备份
    ├── restore.sh         # manifest v2 校验后的安全恢复
    ├── manifest.py        # manifest、校验和与路径验证
    ├── verify.sh          # 验证配置结果
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
./popos/setup.sh   # 脚本内部自动调用 sudo

# 修复/补装模式：复用 ~/.config/envbat/profile.sh，不重新问答
./popos/setup.sh --repair

# 重新配置：以当前选择为默认值，确认后保存并执行
./popos/setup.sh --reconfigure

# 电源管理（独立工具，不需 root）
chmod +x popos/popos-power.sh
./popos/popos-power.sh
```

### Backup & Restore (PopOS)

备份用户配置、包列表和系统设置：

```bash
# 备份
./popos/backup.sh

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

- 默认恢复 dotfiles、envbat profile、Neovim、oh-my-zsh custom、目录结构和缺失的 Git 仓库
- `.ssh` 必须单独确认
- 不默认恢复 apt sources、hosts、hostname、crontab、netplan
- 不默认执行完整 apt 包列表恢复
- 结束时询问是否运行 `./popos/setup.sh --repair`

备份与恢复契约：

- profile 使用 `ENVBAT_PROFILE_SCHEMA=2`；旧 profile 自动备份并保守迁移，新增选项默认关闭
- 备份先写入权限为 `700` 的 staging 目录，归档和 manifest 权限为 `600`
- dotfiles 和 manifest 成功并通过 SHA-256 校验后，才更新 `latest`
- `manifest.json` 当前 schema 为 v2；restore 明确拒绝 v1、缺失文件和校验和损坏
- 恢复写入前创建安全快照；dotfiles、Neovim、oh-my-zsh custom 和 SSH 使用临时目标替换
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

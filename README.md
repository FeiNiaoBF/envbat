# 自动化脚本

我已经对Windows电脑的环境配置又爱又恨，他好烦啊，每次的环境配置都不一样，让我好痛苦，我打算自己写一个可以很好控制环境配置的自动化脚本好点，顺便学学脚本

# 主要内容

## 检测目前环境

1. 可以检查目前电脑上是否有以下语言的环境
    1. C/C++
    2. Golang
    3. Java
    4. Python
    5. …
2. 可以在自定义的盘符里安装一个新的文件夹来放置envs
    
    
3. 可以在不同的环境中下载最新的版本来安装
    
    使用了 `Invoke-WebRequest` 来下载压缩包。你可以使用 PowerShell 中的 `Expand-Archive` 来自动解压这些包。
   
    自动化安装压缩包并配置环境变量
    
5. 最后可以检验安装是否成功

# 在Window上的脚本
使用[PowerShell](https://learn.microsoft.com/en-us/powershell/)来做这个自动化


# PopOS 环境配置

在 Linux (Pop!_OS) 上的开发环境一键配置脚本。

## 使用方式

```bash
# 1. 克隆仓库
git clone git@github.com:FeiNiaoBF/envbat.git
cd envbat

# 2. 赋予执行权限
chmod +x scipts/setup-popos.sh

# 3. 运行（需要 sudo）
sudo ./scipts/setup-popos.sh

# 4. 加载环境变量
source ~/.bashrc
```

## 目录结构

脚本会在 `/data` 下创建统一的数据目录结构：

| 目录 | 用途 |
|------|------|
| `/data/workspace/` | 代码仓库（github/）、本地项目（local/）、实验（experiments/） |
| `/data/datasets/` | 数据集（raw/、processed/、cache/） |
| `/data/models/` | 模型文件（huggingface/、fine_tuned/、checkpoints/） |
| `/data/envs/` | 虚拟环境（conda/、docker/） |
| `/data/tools/` | 自定义工具（bin/、npm-global/、cargo/） |
| `/data/runs/` | 运行日志与输出（logs/、outputs/、mlruns/） |
| `/data/library/` | 文档与书籍 |
| `/data/shared/` | 跨机器共享文件 |
| `/data/backups/` | 备份（system/、dotfiles/、home/） |
| `/data/secrets/` | 加密凭证（权限 700） |
| `/data/temp/` | 临时文件 |
| `/data/archives/` | 压缩包归档 |

脚本还会在 `~` 下创建符号链接方便访问：

```
~/Code       → /data/workspace/github
~/Projects   → /data/workspace/local
~/Experiments → /data/workspace/experiments
~/Data       → /data/
~/Datasets   → /data/datasets
~/Models     → /data/models
~/Tools      → /data/tools
~/Library    → /data/library
~/Shared     → /data/shared
~/Backups    → /data/backups
```

## 环境变量

追加到 `~/.bashrc`：

- `DATA_HOME=/data`
- `CODE_HOME=/data/workspace/github`
- `TOOLS_HOME=/data/tools`
- `HF_HOME=/data/models/huggingface`
- `CARGO_HOME=/data/tools/cargo`
- `TMPDIR=/data/temp`

## 脚本模块

| 文件 | 功能 |
|------|------|
| `scipts/setup-popos.sh` | 入口脚本，依次执行各模块 |
| `scipts/popos_check.sh` | 系统环境检查 |
| `scipts/popos_dirs.sh` | 创建目录结构 + 符号链接 |
| `scipts/popos_config.sh` | 配置环境变量 |
| `scipts/popos_install.sh` | 安装基础工具（git、curl、build-essential 等） |
| `scipts/popos_verify.sh` | 验证配置结果 |

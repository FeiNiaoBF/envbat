# envbat PopOS 脚本修复设计

## 背景

envbat PopOS 安装脚本经实际 PopOS 24.04 LTS 裸机部署后，发现 8 个在生产环境中暴露的问题。本文档记录修复方案。

## 问题清单

| # | 问题 | 根因 | 影响 |
|---|------|------|------|
| 1 | Sudo 运行导致 /data/tools 全部 root 所有 | setup.sh 注释误导用户用 sudo 执行 | 工具不可用、profile 写入 root home |
| 2 | profile.sh 缺失 nvm/pyenv/Rust PATH 段 | 安装函数用 `>>` 追加但 sudo 下写入 root 的 profile | 命令找不到 |
| 3 | Java 下载 URL 失效 | download.java.net 已不提供 GA 构建 | Java 安装失败 |
| 4 | Rustup skip check 用错路径 | 检查 `$rustup_home/bin/rustc` 但实际在 `$CARGO_HOME/bin/` | 重复安装 |
| 5 | Java 解压目录名含小版本号 | Oracle JDK 21.0.11 解压出 `jdk-21.0.11` 而非 `jdk-21` | 重命名逻辑触不到 |
| 6 | Docker codename 硬编码 `noble` | 代码写死 ubuntu codename | PopOS 换 base 时兼容性 |
| 7 | fd 无别名 | PopOS 包名 `fd-find`，二进制 `fdfind` | 用户习惯 `fd` 找不到 |
| 8 | .bashrc/.zshrc 不自加载 profile.sh | 安装完需要用户手动 source | 新终端会话工具不可用 |

## 修复方案（中等优化）

### 1. Sudo 守卫（setup.sh）

在 `set -euo pipefail` 之后增加：

```bash
if [ "$(id -u)" -eq 0 ]; then
    echo "错误: 不要使用 sudo 运行此脚本。脚本内部会在需要时自动调用 sudo。"
    echo "正确用法: ./popos/setup.sh"
    exit 1
fi
```

同时更新 setup.sh 头部注释。

### 2. Profile 集中写入（profile.sh + lang.sh + shell.sh）

**思路**：`popos_save_profile` 一次性写出完整 profile，安装函数不再独立追加。

改动点：
- `popos_save_profile` 模板扩展：在环境变量段之后加入 nvm/pyenv/Rust 的配置段
- 安装函数 (`popos_install_nvm_node` 等) 只做安装，不写 profile
- `popos_save_profile` 末尾自动将 `source ~/.config/envbat/profile.sh` 加入 `.bashrc` 和 `.zshrc`（如果还未存在）
- shell 函数 `popos_install_ohmyzsh` 不再写 `fzf` 到 profile

### 3. Java URL 修复（lang.sh）

```bash
# 旧 (404):
url="https://download.java.net/java/GA/jdk${java_ver}/GPL/openjdk-${java_ver}_linux-x64_bin.tar.gz"

# 新:
url="https://download.oracle.com/java/${java_ver}/latest/jdk-${java_ver}_linux-x64_bin.tar.gz"
```

目录重命名逻辑改为更健壮的 glob：

```bash
extracted=$(find "$INSTALL_BASE/tools/java" -maxdepth 1 -type d -name "jdk-${java_ver}*" | head -1)
```

### 4. Rust skip check 修复（lang.sh）

```bash
# 旧 (错误路径):
if [ -x "$rustup_home/bin/rustc" ]; then
# 新 (正确路径):
if [ -x "$CARGO_HOME/bin/rustc" ]; then
```

### 5. Docker 仓库动态检测（docker.sh）

```bash
# 旧:
echo "deb [arch=amd64 ...] https://download.docker.com/linux/ubuntu noble stable"
# 新:
distro_codename=$(lsb_release -cs 2>/dev/null || echo "noble")
arch=$(dpkg --print-architecture 2>/dev/null || echo "amd64")
echo "deb [arch=${arch} signed-by=...] https://download.docker.com/linux/ubuntu ${distro_codename} stable"
```

### 6. fd 别名（install.sh）

在 `popos_install_tools` 末尾加入：

```bash
# fd 别名 (PopOS 的 fd-find 包安装为 fdfind)
if command -v fdfind &>/dev/null && ! command -v fd &>/dev/null; then
    sudo ln -sf "$(which fdfind)" /usr/local/bin/fd 2>/dev/null && echo "  [OK] fd 别名已创建"
fi
```

## 不变的部分

- 函数签名、调用链不变
- setup.sh 的执行流程不变
- verify.sh 只更新 env var 检查逻辑（现有 PATH 段自动生效）
- Windows 脚本不涉及

## 验证

修复后重新运行完整 `setup.sh`：
1. Go/Node/Rust/Java/Neovim 均可用
2. `source ~/.bashrc` 后无需手动 source profile
3. `popos_summary` 显示 6 个 env vars 均为 `[OK]`
4. docker 可安装成功
5. `fd --version` 可用

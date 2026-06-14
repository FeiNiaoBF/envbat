# envbat PopOS 安全加固 + 中文环境 + Chrome 模块设计

## 背景

PopOS 裸机安装后缺少日常使用必要的安全防护、中文输入支持和浏览器。新增三个模块填补这些缺口。

## 新增模块

### 1. 安全加固 (`popos/security.sh`)

**函数**: `popos_install_security()`

- **UFW 防火墙**: 默认拒绝入站，放行 SSH，立即启用
- **Fail2ban**: SSH 暴力破解防护（5 次失败封 10 分钟）
- **unattended-upgrades**: 自动安装安全更新

### 2. 中文环境 (`popos/locale.sh`)

**函数**: `popos_setup_locale()`

- `locale-gen zh_CN.UTF-8` + `update-locale`
- 安装 fcitx5 + fcitx5-rime 输入法
- 设 im-config 为 fcitx5
- 自动启动 fcitx5

### 3. Chrome 浏览器 (`popos/install.sh`)

**函数**: `popos_install_chrome()`

- 添加 Google Chrome 官方仓库（GPG key + sources.list）
- apt install google-chrome-stable

## 交互式问答

在 `popos_ask_questions` 尾追加：

| 变量 | 问题 | 默认 |
|------|------|------|
| INSTALL_UFW | 开启 UFW 防火墙？ | Y |
| INSTALL_FAIL2BAN | 安装 Fail2ban？ | Y |
| INSTALL_AUTO_UPDATES | 开启自动安全更新？ | Y |
| INSTALL_CHINESE | 配置中文 locale + fcitx5？ | Y |
| INSTALL_CHROME | 安装 Google Chrome？ | Y |

## setup.sh 执行流程

```
popos_install_tools
popos_install_languages
popos_install_security       # 新增
popos_setup_locale           # 新增
INSTALL_CHROME → popos_install_chrome   # 新增
popos_install_neovim
...
```

## 文件改动清单

| 文件 | 操作 |
|------|------|
| `popos/security.sh` | **创建** |
| `popos/locale.sh` | **创建** |
| `popos/install.sh` | **修改** — 追加 `popos_install_chrome` |
| `popos/setup.sh` | **修改** — 追加 source + 问答 + 执行链 |
| `popos/profile.sh` | **修改** — profile 模板加 INSTALL_UFW/FAIL2BAN/AUTO_UPDATES/CHINESE/CHROME 变量持久化 |

## 验证

Setup 跑完后：
- `sudo ufw status` → active，22/tcp ALLOW
- `sudo fail2ban-client status sshd` → running
- `sudo systemctl status unattended-upgrades` → active
- `locale -a | grep zh_CN` → zh_CN.UTF-8
- `fcitx5 --version` → 有输出
- `google-chrome --version` → 有输出

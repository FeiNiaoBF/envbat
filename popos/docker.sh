#!/usr/bin/env bash
# === Docker Installer ===

popos_install_docker() {
    echo ">>> 安装 Docker <<<"
    if command -v docker &>/dev/null; then
        echo "  [SKIP] Docker 已安装: $(docker --version)"
        return
    fi
    # Add official Docker repo
    if ! sudo apt-get update -qq; then
        fail "apt update 失败"
        return 1
    fi
    if ! sudo apt-get install -y -qq ca-certificates curl; then
        fail "Docker 前置依赖安装失败"
        return 1
    fi
    if ! sudo install -m 0755 -d /etc/apt/keyrings; then
        fail "Docker keyring 目录创建失败"
        return 1
    fi
    if ! curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo tee /etc/apt/keyrings/docker.asc >/dev/null; then
        fail "Docker GPG key 下载失败"
        return 1
    fi
    local distro_codename
    distro_codename=$(
        # shellcheck source=/dev/null
        . /etc/os-release 2>/dev/null
        echo "${UBUNTU_CODENAME:-}"
    )
    if [ -z "$distro_codename" ]; then
        distro_codename=$(lsb_release -cs 2>/dev/null || echo "noble")
    fi
    local arch
    arch=$(dpkg --print-architecture 2>/dev/null || echo "amd64")
    if ! echo "deb [arch=${arch} signed-by=/etc/apt/keyrings/docker.asc] \
https://download.docker.com/linux/ubuntu ${distro_codename} stable" | \
        sudo tee /etc/apt/sources.list.d/docker.list >/dev/null; then
        fail "Docker apt 源写入失败"
        return 1
    fi
    if ! sudo apt-get update -qq; then
        fail "Docker apt 源更新失败 (${distro_codename})"
        return 1
    fi
    if ! sudo apt-get install -y -qq docker-ce docker-ce-cli containerd.io \
        docker-buildx-plugin docker-compose-plugin; then
        fail "Docker 安装失败"
        return 1
    fi
    # User group
    if ! sudo usermod -aG docker "$(whoami)"; then
        fail "用户加入 docker 组失败"
        return 1
    fi
    if ! sudo systemctl enable --now docker; then
        fail "Docker 服务启用失败"
        return 1
    fi
    if ! command -v docker &>/dev/null; then
        fail "Docker 安装后命令不可用"
        return 1
    fi
    ok "Docker 已安装 (需重新登录后 docker 组才生效)"
}

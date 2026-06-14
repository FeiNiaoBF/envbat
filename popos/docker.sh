#!/usr/bin/env bash
# === Docker Installer ===

popos_install_docker() {
    echo ">>> 安装 Docker <<<"
    if command -v docker &>/dev/null; then
        echo "  [SKIP] Docker 已安装: $(docker --version)"
        return
    fi
    # Add official Docker repo
    sudo apt-get update -qq 2>/dev/null
    sudo apt-get install -y -qq ca-certificates curl 2>/dev/null
    sudo install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
        sudo tee /etc/apt/keyrings/docker.asc >/dev/null
    local distro_codename
    distro_codename=$(lsb_release -cs 2>/dev/null || echo "noble")
    local arch
    arch=$(dpkg --print-architecture 2>/dev/null || echo "amd64")
    echo "deb [arch=${arch} signed-by=/etc/apt/keyrings/docker.asc] \
https://download.docker.com/linux/ubuntu ${distro_codename} stable" | \
        sudo tee /etc/apt/sources.list.d/docker.list >/dev/null
    sudo apt-get update -qq 2>/dev/null
    sudo apt-get install -y -qq docker-ce docker-ce-cli containerd.io \
        docker-buildx-plugin docker-compose-plugin 2>/dev/null
    # User group
    sudo usermod -aG docker "$(whoami)"
    # Enable and start
    sudo systemctl enable docker 2>/dev/null
    sudo systemctl start docker 2>/dev/null
    ok "Docker 已安装 (需重新登录后 docker 组才生效)"
}

#!/usr/bin/env bash
# === PopOS: Security Hardening ===
# UFW firewall + Fail2ban + unattended-upgrades

popos_install_security() {
    echo "========================================"
    echo " 安装安全加固"
    echo "========================================"

    if [ "${INSTALL_UFW:-false}" = true ]; then
        echo ">>> UFW 防火墙 <<<"
        if command -v ufw &>/dev/null && sudo ufw status 2>/dev/null | grep -q active; then
            echo "  [SKIP] UFW 已启用"
        else
            sudo apt-get install -y -qq ufw 2>/dev/null
            sudo ufw default deny incoming 2>/dev/null
            sudo ufw allow ssh 2>/dev/null
            sudo ufw --force enable 2>/dev/null
            ok "UFW 已启用 (只放行 SSH)"
        fi
    fi

    if [ "${INSTALL_FAIL2BAN:-false}" = true ]; then
        echo ">>> Fail2ban <<<"
        if systemctl is-active --quiet fail2ban 2>/dev/null; then
            echo "  [SKIP] Fail2ban 已在运行"
        else
            sudo apt-get install -y -qq fail2ban 2>/dev/null
            sudo tee /etc/fail2ban/jail.local >/dev/null <<'EOF'
[DEFAULT]
bantime = 600
maxretry = 5
[sshd]
enabled = true
EOF
            sudo systemctl enable --now fail2ban 2>/dev/null
            ok "Fail2ban 已启用 (SSH 5 次失败封 10 分钟)"
        fi
    fi

    if [ "${INSTALL_AUTO_UPDATES:-false}" = true ]; then
        echo ">>> 自动安全更新 <<<"
        if systemctl is-active --quiet unattended-upgrades 2>/dev/null; then
            echo "  [SKIP] unattended-upgrades 已在运行"
        else
            sudo apt-get install -y -qq unattended-upgrades 2>/dev/null
            sudo dpkg-reconfigure -f noninteractive --priority=low unattended-upgrades 2>/dev/null
            ok "自动安全更新已开启"
        fi
    fi
    echo ""
}

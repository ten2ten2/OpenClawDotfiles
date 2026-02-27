#!/usr/bin/env bash

apt_basics(){
  log "系统更新 + 基础工具"
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -y
  apt-get upgrade -y
  apt-get install -y \
    ca-certificates curl gnupg lsb-release \
    ufw fail2ban unattended-upgrades \
    chrony git jq htop vim
  systemctl enable --now chrony || true
}

set_identity(){
  log "设置主机名/时区"
  hostnamectl set-hostname "$HOSTNAME_FQDN" || true
  timedatectl set-timezone "$TIMEZONE" || true
}

create_admin(){
  log "创建/确认管理员用户：$ADMIN_USER"
  if ! id -u "$ADMIN_USER" >/dev/null 2>&1; then
    adduser --disabled-password --gecos "" "$ADMIN_USER"
    usermod -aG sudo "$ADMIN_USER"
  fi

  if [[ -n "$SSH_PUBKEY" ]]; then
    log "写入 $ADMIN_USER 的 SSH 公钥"
    install -d -m 700 "/home/$ADMIN_USER/.ssh"
    echo "$SSH_PUBKEY" > "/home/$ADMIN_USER/.ssh/authorized_keys"
    chmod 600 "/home/$ADMIN_USER/.ssh/authorized_keys"
    chown -R "$ADMIN_USER:$ADMIN_USER" "/home/$ADMIN_USER/.ssh"
  else
    warn "未设置 SSH_PUBKEY：将跳过禁密码/禁 root 远程，避免锁死"
  fi
}

ssh_hardening(){
  log "SSH 加固"
  [[ -n "$SSH_PUBKEY" ]] || { echo "  跳过（SSH_PUBKEY 为空）"; return 0; }

  install -d /etc/ssh/sshd_config.d
  cat >/etc/ssh/sshd_config.d/99-openclaw.conf <<CFG
Port ${SSH_PORT}
PermitRootLogin no
PasswordAuthentication no
KbdInteractiveAuthentication no
PubkeyAuthentication yes
X11Forwarding no
AllowUsers ${ADMIN_USER}
ClientAliveInterval 300
ClientAliveCountMax 2
MaxAuthTries 4
CFG

  systemctl restart ssh || systemctl restart sshd
}

firewall(){
  log "UFW：仅放行 SSH"
  ufw default deny incoming
  ufw default allow outgoing
  ufw allow "${SSH_PORT}/tcp"
  ufw --force enable
  ufw status verbose || true
}

fail2ban_cfg(){
  log "fail2ban：启用 sshd 保护"
  cat >/etc/fail2ban/jail.d/sshd.local <<'CFG'
[sshd]
enabled = true
bantime  = 1h
findtime = 10m
maxretry = 5
CFG
  systemctl enable --now fail2ban
}

unattended_upgrades(){
  log "启用 unattended-upgrades"
  dpkg-reconfigure -f noninteractive unattended-upgrades || true
}

swap_and_sysctl(){
  log "配置 swap(${SWAP_GB}GB) + sysctl"

  if ! swapon --show | grep -q "/swapfile"; then
    fallocate -l "${SWAP_GB}G" /swapfile || dd if=/dev/zero of=/swapfile bs=1G count="${SWAP_GB}"
    chmod 600 /swapfile
    mkswap /swapfile
    swapon /swapfile
    grep -q '^/swapfile ' /etc/fstab || echo '/swapfile none swap sw 0 0' >> /etc/fstab
  fi

  cat >/etc/sysctl.d/99-openclaw.conf <<'CFG'
vm.overcommit_memory=1
vm.swappiness=10
vm.vfs_cache_pressure=50
net.core.somaxconn=4096
net.ipv4.tcp_max_syn_backlog=4096
net.ipv4.ip_local_port_range=10240 65535
fs.file-max=1048576
fs.inotify.max_user_watches=524288
fs.inotify.max_user_instances=1024
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr
CFG

  sysctl --system
}

disable_thp(){
  log "关闭 THP"
  cat >/etc/systemd/system/disable-thp.service <<'CFG'
[Unit]
Description=Disable Transparent Huge Pages (THP)
After=network.target

[Service]
Type=oneshot
ExecStart=/bin/sh -c 'test -f /sys/kernel/mm/transparent_hugepage/enabled && echo never > /sys/kernel/mm/transparent_hugepage/enabled || true; test -f /sys/kernel/mm/transparent_hugepage/defrag && echo never > /sys/kernel/mm/transparent_hugepage/defrag || true'
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
CFG

  systemctl daemon-reload
  systemctl enable --now disable-thp.service
}

raise_limits(){
  log "提高 nofile"

  cat >/etc/security/limits.d/99-openclaw.conf <<'CFG'
* soft nofile 65535
* hard nofile 65535
root soft nofile 65535
root hard nofile 65535
CFG

  install -d /etc/systemd/system.conf.d
  cat >/etc/systemd/system.conf.d/99-openclaw.conf <<'CFG'
[Manager]
DefaultLimitNOFILE=65535
CFG

  systemctl daemon-reexec || true
}

#!/usr/bin/env bash

install_docker_latest(){
  log "安装 Docker（官方 APT 仓库）"

  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  chmod a+r /etc/apt/keyrings/docker.gpg

  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" \
    > /etc/apt/sources.list.d/docker.list

  apt-get update -y
  apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

  systemctl enable --now docker
  systemctl is-active --quiet docker || die "Docker 服务未成功启动"

  install -d /etc/docker
  cat >/etc/docker/daemon.json <<'CFG'
{
  "log-driver": "json-file",
  "log-opts": { "max-size": "10m", "max-file": "3" },
  "live-restore": true
}
CFG

  systemctl restart docker
  usermod -aG docker "$ADMIN_USER" || true
}

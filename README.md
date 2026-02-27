# OpenClawDotfiles (Linode + Cloudflare Tunnel)

目标：从 Linode 新建 VM 开始，到安装 OpenClaw 前，把主机底座配置好：
- SSH 加固（推荐 key-only）
- UFW + fail2ban
- swap + sysctl + THP off + nofile
- Docker（官方仓库）
- cloudflared（官方仓库）
- 生成 pgvector(Postgres) + Valkey 的 infra compose（可选启动）
- Web 后台仅通过 Cloudflare Tunnel 暴露（不开放 80/443）

## 1. 服务器上准备 bootstrap.env（不入库）
```bash
sudo mkdir -p /opt/openclaw
sudo cp templates/bootstrap.env.example /opt/openclaw/bootstrap.env
sudo chmod 600 /opt/openclaw/bootstrap.env
sudo vim /opt/openclaw/bootstrap.env
```

## 2. 执行主机底座脚本
### Linode 4GB
```bash
sudo bash scripts/linode/prep_4gb.sh
# 可选：顺便启动 pgvector+valkey
START_INFRA=1 sudo -E bash scripts/linode/prep_4gb.sh
```

### Linode 8GB
```bash
sudo bash scripts/linode/prep_8gb.sh
START_INFRA=1 sudo -E bash scripts/linode/prep_8gb.sh
```

## 3. 配置 Cloudflare Tunnel（单 Web 后台）
```bash
sudo bash scripts/cloudflare/setup_tunnel.sh
```
## ⚠️ 安全提示
- 不要提交 /opt/openclaw/bootstrap.env
- 不要提交 /etc/cloudflared/.json 或 ~/.cloudflared/.json
- 数据库/Valkey 不开放公网端口（只走 Docker 内网/localhost）

# Migration Notes

## 变化
- 移除：`scripts/linode/prep_4gb.sh`
- 移除：`scripts/linode/prep_8gb.sh`
- 移除：`scripts/linode/prep_common.sh`
- 新入口：`scripts/ubuntu/prep.sh`
- 新巡检：`scripts/ubuntu/doctor.sh`

## 新执行方式
```bash
sudo bash scripts/ubuntu/prep.sh
# 可选：START_INFRA=1 sudo -E bash scripts/ubuntu/prep.sh
```

## Tunnel 配置
```bash
sudo bash scripts/cloudflare/setup_tunnel.sh
```

## 兼容性说明
本仓库不再提供 Linode 专用入口脚本。请统一使用 Ubuntu 通用入口。

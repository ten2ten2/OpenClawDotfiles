# Preflight Checks

`scripts/ubuntu/prep.sh` 会先执行预检查。

## 阻断项（默认）
- Ubuntu 24.04+
- root/sudo 权限
- `apt-get update` 可用
- `systemd` 可用
- 关键仓库连通：Docker APT、Cloudflare APT
- 资源满足最低阈值：
  - RAM >= 4 GiB
  - CPU >= 2 cores
  - Disk Free >= 80 GiB

## 告警项
- 根盘是 HDD（ROTA=1）时提示 RAG/索引/checkpoint 风险
- CPU 推荐值输出：
  - `OPENCLAW_WORKERS_RECOMMENDED`
  - `POSTGRES_MAX_PARALLEL_WORKERS_PER_GATHER_RECOMMENDED`

## 行为控制
- `PREFLIGHT_STRICT=1` 且 `ALLOW_WEAK_HOST=0`：失败即退出
- `ALLOW_WEAK_HOST=1`：失败项降级为告警（仅测试建议）

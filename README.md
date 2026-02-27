# openclaw-prepare (Ubuntu Generic)

Initialize an Ubuntu 24.04+ server to an "OpenClaw-ready" state.

## Goals
- Generic Ubuntu host bootstrap (not tied to any cloud vendor)
- Preflight-first checks: system/permissions/network/resources
- Host hardening (SSH/UFW/fail2ban/unattended-upgrades)
- Install Docker + cloudflared from official repositories
- Generate pgvector (Postgres) + Valkey infra (optional immediate start)
- Expose the web admin only through Cloudflare Tunnel

## Minimum Requirements (Blocking by Default)
- Ubuntu `24.04+`
- `apt-get update` must work (public internet or reachable mirror)
- root or sudo privileges
- systemd available, and Docker installation allowed
- Minimum resources:
  - RAM `>= 4 GiB`
  - CPU `>= 2 cores`
  - Disk Free `>= 80 GiB`

## Quick Start

### 1) Clone the repository (on the target server)
```bash
git clone <YOUR_REPO_URL> OpenClawDotfiles
cd OpenClawDotfiles
```

### 2) Prepare `bootstrap.env` (on the target server)
```bash
sudo mkdir -p /opt/openclaw
sudo cp templates/bootstrap.env.example /opt/openclaw/bootstrap.env
sudo chmod 600 /opt/openclaw/bootstrap.env
sudo vim /opt/openclaw/bootstrap.env
```

### 3) Run the main entry script
```bash
sudo bash scripts/ubuntu/prep.sh
```

Optional: start infra immediately after bootstrap
```bash
START_INFRA=1 sudo -E bash scripts/ubuntu/prep.sh
```

### 4) Configure Cloudflare Tunnel
```bash
sudo bash scripts/cloudflare/setup_tunnel.sh
```

## Execution Flow
1. Read `/opt/openclaw/bootstrap.env`
2. Run preflight checks: OS, apt, permissions, systemd, connectivity, minimum resources
3. Detect RAM tier (S/M/L/XL) and apply defaults
4. Apply host hardening + install Docker/cloudflared
5. Generate `/opt/openclaw/infra` (`compose`/`.env`/`db-init`)
6. If `START_INFRA=1`, run `docker compose up -d`
7. Print recommended values:
- `OPENCLAW_WORKERS_RECOMMENDED`
- `POSTGRES_MAX_PARALLEL_WORKERS_PER_GATHER_RECOMMENDED`

## RAM Tiers
See [docs/tuning-matrix.md](docs/tuning-matrix.md).

You can force a tier via `FORCE_RAM_TIER=S|M|L|XL`.

## Preflight Rules
See [docs/preflight-checks.md](docs/preflight-checks.md).

Key switches:
- `PREFLIGHT_STRICT=1`: block on critical failures
- `ALLOW_WEAK_HOST=1`: allow low-spec hosts to continue (testing only)

## Doctor (Check Only, No Changes)
```bash
sudo bash scripts/ubuntu/doctor.sh
```

## Common Paths
- Bootstrap config: `/opt/openclaw/bootstrap.env`
- Infra directory: `/opt/openclaw/infra`
- Tunnel config: `/etc/cloudflared/config.yml`
- Tunnel credentials: `/etc/cloudflared/<UUID>.json`

## Security Notes
- Do not commit `/opt/openclaw/bootstrap.env`
- Do not commit `~/.cloudflared/*.json` or `/etc/cloudflared/*.json`
- Do not expose database/Valkey ports publicly
- Keep OpenClaw web admin bound to `127.0.0.1` or Docker internal networking

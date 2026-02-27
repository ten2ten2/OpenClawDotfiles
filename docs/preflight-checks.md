# Preflight Checks

`scripts/ubuntu/prep.sh` runs preflight checks first.

## Blocking Checks (Default)
- Ubuntu 24.04+
- root/sudo privileges
- `apt-get update` works
- `systemd` is available
- Required repository connectivity: Docker APT, Cloudflare APT
- Minimum resource thresholds:
  - RAM >= 4 GiB
  - CPU >= 2 cores
  - Disk Free >= 80 GiB

## Warnings
- If root disk is HDD (ROTA=1), warn about RAG/index/checkpoint risk
- Print CPU-based recommendations:
  - `OPENCLAW_WORKERS_RECOMMENDED`
  - `POSTGRES_MAX_PARALLEL_WORKERS_PER_GATHER_RECOMMENDED`

## Behavior Controls
- `PREFLIGHT_STRICT=1` and `ALLOW_WEAK_HOST=0`: exit on failures
- `ALLOW_WEAK_HOST=1`: downgrade failures to warnings (testing only)

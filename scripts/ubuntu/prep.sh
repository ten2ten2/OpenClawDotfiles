#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
BOOTSTRAP_ENV="${BOOTSTRAP_ENV:-/opt/openclaw/bootstrap.env}"
START_INFRA="${START_INFRA:-0}"

log(){ echo -e "\n[+] $*\n"; }
warn(){ echo -e "\n[!] $*\n" >&2; }
die(){ echo -e "\n[x] $*\n" >&2; exit 1; }
need_root(){ [[ ${EUID:-$(id -u)} -eq 0 ]] || die "请用 sudo/root 运行"; }

load_env(){
  [[ -f "$BOOTSTRAP_ENV" ]] || die "未找到 $BOOTSTRAP_ENV（请从 templates/bootstrap.env.example 复制并填写）"

  set -a
  # shellcheck disable=SC1090
  source "$BOOTSTRAP_ENV"
  set +a

  : "${ADMIN_USER:?ADMIN_USER 未设置}"
  : "${TIMEZONE:=America/Los_Angeles}"
  : "${HOSTNAME_FQDN:=openclaw-1}"
  : "${SSH_PORT:=22}"
  : "${OPENCLAW_BASE:=/opt/openclaw}"
  : "${SSH_PUBKEY:=}"

  : "${POSTGRES_DB:=openclaw}"
  : "${POSTGRES_USER:=openclaw}"
  : "${POSTGRES_PASSWORD:=CHANGE_ME_STRONG}"
  : "${PGVECTOR_IMAGE:=pgvector/pgvector:pg18-trixie}"
  : "${VALKEY_IMAGE:=valkey/valkey:9}"

  : "${PREFLIGHT_STRICT:=1}"
  : "${ALLOW_WEAK_HOST:=0}"
  : "${MIN_RAM_GB:=4}"
  : "${MIN_CPU_CORES:=2}"
  : "${MIN_DISK_FREE_GB:=80}"
  : "${FORCE_RAM_TIER:=}"
}

# shellcheck source=./lib/preflight.sh
source "${SCRIPT_DIR}/lib/preflight.sh"
# shellcheck source=./lib/tuning.sh
source "${SCRIPT_DIR}/lib/tuning.sh"
# shellcheck source=./lib/system.sh
source "${SCRIPT_DIR}/lib/system.sh"
# shellcheck source=./lib/docker.sh
source "${SCRIPT_DIR}/lib/docker.sh"
# shellcheck source=./lib/cloudflared.sh
source "${SCRIPT_DIR}/lib/cloudflared.sh"
# shellcheck source=./lib/infra.sh
source "${SCRIPT_DIR}/lib/infra.sh"

print_summary(){
  local pg_parallel
  pg_parallel=$(( CPU_CORES > 1 ? CPU_CORES / 2 : 1 ))

  cat <<SUM
==================== Summary ====================
Host checks:
  OS: Ubuntu ${OS_VERSION}
  RAM: ${RAM_GB} GiB | CPU: ${CPU_CORES} cores | Disk Free: ${DISK_FREE_GB} GiB
  RAM Tier: ${RAM_TIER}

Recommended:
  OPENCLAW_WORKERS_RECOMMENDED=${OPENCLAW_WORKERS_RECOMMENDED}
  POSTGRES_MAX_PARALLEL_WORKERS_PER_GATHER_RECOMMENDED=${pg_parallel}

Applied defaults (overrideable via bootstrap.env):
  SWAP_GB=${SWAP_GB}
  POSTGRES_MEM_LIMIT=${POSTGRES_MEM_LIMIT}
  POSTGRES_SHM_SIZE=${POSTGRES_SHM_SIZE}
  VALKEY_MEM_LIMIT=${VALKEY_MEM_LIMIT}
  VALKEY_MAXMEM=${VALKEY_MAXMEM}
  PG_SHARED_BUFFERS=${PG_SHARED_BUFFERS}
  PG_EFFECTIVE_CACHE_SIZE=${PG_EFFECTIVE_CACHE_SIZE}
  PG_WORK_MEM=${PG_WORK_MEM}
  PG_MAINTENANCE_WORK_MEM=${PG_MAINTENANCE_WORK_MEM}
  PG_MAX_CONNECTIONS=${PG_MAX_CONNECTIONS}
=================================================
SUM
}

main(){
  need_root
  load_env

  run_preflight
  apply_ram_tier_defaults

  apt_basics
  set_identity
  create_admin
  ssh_hardening
  firewall
  fail2ban_cfg
  unattended_upgrades

  swap_and_sysctl
  disable_thp
  raise_limits

  install_docker_latest
  install_cloudflared_latest

  render_infra
  maybe_start_infra

  print_summary

  log "完成。下一步：sudo bash scripts/cloudflare/setup_tunnel.sh"
}

main "$@"

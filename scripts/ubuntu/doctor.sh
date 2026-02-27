#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOOTSTRAP_ENV="${BOOTSTRAP_ENV:-/opt/openclaw/bootstrap.env}"

log(){ echo -e "\n[+] $*\n"; }
warn(){ echo -e "\n[!] $*\n" >&2; }
die(){ echo -e "\n[x] $*\n" >&2; exit 1; }

load_env(){
  [[ -f "$BOOTSTRAP_ENV" ]] || die "未找到 $BOOTSTRAP_ENV"
  set -a
  # shellcheck disable=SC1090
  source "$BOOTSTRAP_ENV"
  set +a

  : "${PREFLIGHT_STRICT:=1}"
  : "${ALLOW_WEAK_HOST:=0}"
  : "${MIN_RAM_GB:=4}"
  : "${MIN_CPU_CORES:=2}"
  : "${MIN_DISK_FREE_GB:=80}"
}

# shellcheck source=./lib/preflight.sh
source "${SCRIPT_DIR}/lib/preflight.sh"

main(){
  load_env
  run_preflight
  log "Doctor 检查通过"
}

main "$@"

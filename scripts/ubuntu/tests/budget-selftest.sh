#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

append_warning(){ :; }

# shellcheck source=../lib/budget.sh
source "${SCRIPT_DIR}/../lib/budget.sh"

assert_eq(){
  local got="$1"
  local expected="$2"
  local label="$3"
  if [[ "$got" != "$expected" ]]; then
    echo "[x] ${label}: expected '${expected}', got '${got}'" >&2
    exit 1
  fi
}

run_case(){
  local ram="$1"
  local cpu="$2"

  RAM_GB="$ram"
  CPU_CORES="$cpu"
  OPENCLAW_AGENT_TARGET=10
  OPENCLAW_WORKER_PER_AGENTS=2

  USER_SET_OPENCLAW_MEM_GB=0
  USER_SET_POSTGRES_MEM_GB=0
  USER_SET_REDIS_MEM_GB=0
  USER_SET_OS_RESERVE_GB=0
  USER_SET_OPENCLAW_CPU_QUOTA=0
  USER_SET_POSTGRES_CPU_QUOTA=0
  USER_SET_REDIS_CPU_QUOTA=0
  USER_SET_SWAP_GB=0
  USER_SET_PG_SHARED_BUFFERS=0
  USER_SET_PG_EFFECTIVE_CACHE_SIZE=0
  USER_SET_PG_WORK_MEM=0
  USER_SET_PG_MAINTENANCE_WORK_MEM=0
  USER_SET_PG_MAX_CONNECTIONS=0
  USER_SET_PG_MAX_WORKER_PROCESSES=0
  USER_SET_PG_MAX_PARALLEL_WORKERS=0
  USER_SET_PG_MAX_PARALLEL_WORKERS_PER_GATHER=0
  USER_SET_PG_MAX_PARALLEL_MAINTENANCE_WORKERS=0
  USER_SET_POSTGRES_SHM_SIZE=0
  USER_SET_VALKEY_MAXMEM=0
  USER_SET_POSTGRES_MEM_LIMIT=0
  USER_SET_VALKEY_MEM_LIMIT=0

  apply_dynamic_budget

  echo "[+] case ${ram}GB/${cpu}C"
  echo "    OS_RESERVE_GB=${OS_RESERVE_GB} OPENCLAW=${OPENCLAW_MEM_GB} POSTGRES=${POSTGRES_MEM_GB} REDIS=${REDIS_MEM_GB}"
  echo "    CPU quotas: OPENCLAW=${OPENCLAW_CPU_QUOTA} POSTGRES=${POSTGRES_CPU_QUOTA} REDIS=${REDIS_CPU_QUOTA}"

  assert_eq "$OPENCLAW_WORKERS_RECOMMENDED" "5" "OPENCLAW_WORKERS_RECOMMENDED"
  awk -v p="$POSTGRES_MEM_GB" 'BEGIN{exit !(p>=1.0)}' || { echo "[x] POSTGRES_MEM_GB floor violated" >&2; exit 1; }
}

run_case 4 2
run_case 8 4
run_case 16 4

echo "[+] budget self-test passed"

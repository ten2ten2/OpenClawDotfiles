#!/usr/bin/env bash

# Tracks whether a value was explicitly set by the user in bootstrap.env.
# Values set by RAM tiers should still be overrideable by dynamic budgets.
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

OS_RESERVE_GB_CALC="0"
SVC_GB_CALC="0"
OPENCLAW_MEM_GB_CALC="0"
POSTGRES_MEM_GB_CALC="0"
REDIS_MEM_GB_CALC="0"

OPENCLAW_CPU_SHARES=2048
POSTGRES_CPU_SHARES=1536
REDIS_CPU_SHARES=512

mark_user_overrides(){
  local key
  for key in \
    OPENCLAW_MEM_GB POSTGRES_MEM_GB REDIS_MEM_GB OS_RESERVE_GB \
    OPENCLAW_CPU_QUOTA POSTGRES_CPU_QUOTA REDIS_CPU_QUOTA \
    SWAP_GB \
    PG_SHARED_BUFFERS PG_EFFECTIVE_CACHE_SIZE PG_WORK_MEM PG_MAINTENANCE_WORK_MEM \
    PG_MAX_CONNECTIONS PG_MAX_WORKER_PROCESSES PG_MAX_PARALLEL_WORKERS \
    PG_MAX_PARALLEL_WORKERS_PER_GATHER PG_MAX_PARALLEL_MAINTENANCE_WORKERS \
    POSTGRES_SHM_SIZE VALKEY_MAXMEM POSTGRES_MEM_LIMIT VALKEY_MEM_LIMIT
  do
    if [[ -n "${!key:-}" ]]; then
      eval "USER_SET_${key}=1"
    fi
  done
}

clamp_num(){
  awk -v v="$1" -v lo="$2" -v hi="$3" 'BEGIN{if(v<lo)v=lo; if(v>hi)v=hi; printf "%.4f", v}'
}

num_min(){
  awk -v a="$1" -v b="$2" 'BEGIN{printf "%.4f", (a<b?a:b)}'
}

num_max(){
  awk -v a="$1" -v b="$2" 'BEGIN{printf "%.4f", (a>b?a:b)}'
}

gb_to_mb_int(){
  awk -v g="$1" 'BEGIN{printf "%d", (g*1024)}'
}

ceil_div(){
  local n="$1"
  local d="$2"
  echo $(( (n + d - 1) / d ))
}

clamp_int(){
  local v="$1"
  local lo="$2"
  local hi="$3"
  if (( v < lo )); then
    v="$lo"
  fi
  if (( v > hi )); then
    v="$hi"
  fi
  echo "$v"
}

apply_dynamic_budget(){
  local os_reserve svc redis openclaw postgres
  local r="$RAM_GB"
  local c="$CPU_CORES"
  local postgres_mb redis_mb openclaw_mb
  local shared_buffers_mb effective_cache_mb maintenance_work_mb
  local postgres_cpu_quota redis_cpu_quota openclaw_cpu_quota
  local ratio workers

  os_reserve="$(num_max 0.8 "$(awk -v r="$r" 'BEGIN{printf "%.4f", 0.20*r}')")"
  os_reserve="$(num_min "$os_reserve" 4.0)"

  svc="$(awk -v r="$r" -v o="$os_reserve" 'BEGIN{printf "%.4f", r-o}')"
  redis="$(clamp_num "$(awk -v r="$r" 'BEGIN{printf "%.4f", 0.06*r}')" 0.25 1.0)"
  openclaw="$(clamp_num "$(awk -v s="$svc" 'BEGIN{printf "%.4f", 0.40*s}')" 1.2 6.0)"
  postgres="$(awk -v s="$svc" -v o="$openclaw" -v rd="$redis" 'BEGIN{printf "%.4f", s-o-rd}')"

  if awk -v p="$postgres" 'BEGIN{exit !(p<1.0)}'; then
    openclaw="$(num_max 1.0 "$(awk -v s="$svc" -v rd="$redis" 'BEGIN{printf "%.4f", s-rd-1.0}')")"
    postgres="$(awk -v s="$svc" -v o="$openclaw" -v rd="$redis" 'BEGIN{printf "%.4f", s-o-rd}')"
  fi

  if awk -v p="$postgres" 'BEGIN{exit !(p<1.0)}'; then
    append_warning "Host is in degraded memory mode: unable to reserve 1.0GiB for Postgres after OpenClaw protection"
  fi

  OS_RESERVE_GB_CALC="$os_reserve"
  SVC_GB_CALC="$svc"
  OPENCLAW_MEM_GB_CALC="$openclaw"
  POSTGRES_MEM_GB_CALC="$postgres"
  REDIS_MEM_GB_CALC="$redis"

  if (( USER_SET_OS_RESERVE_GB == 0 )); then OS_RESERVE_GB="$os_reserve"; fi
  if (( USER_SET_OPENCLAW_MEM_GB == 0 )); then OPENCLAW_MEM_GB="$openclaw"; fi
  if (( USER_SET_POSTGRES_MEM_GB == 0 )); then POSTGRES_MEM_GB="$postgres"; fi
  if (( USER_SET_REDIS_MEM_GB == 0 )); then REDIS_MEM_GB="$redis"; fi

  openclaw_mb="$(gb_to_mb_int "$OPENCLAW_MEM_GB")"
  postgres_mb="$(gb_to_mb_int "$POSTGRES_MEM_GB")"
  redis_mb="$(gb_to_mb_int "$REDIS_MEM_GB")"

  if (( USER_SET_POSTGRES_MEM_LIMIT == 0 )); then POSTGRES_MEM_LIMIT="${postgres_mb}m"; fi
  if (( USER_SET_VALKEY_MEM_LIMIT == 0 )); then VALKEY_MEM_LIMIT="${redis_mb}m"; fi

  if (( USER_SET_VALKEY_MAXMEM == 0 )); then
    # keep valkey maxmemory below cgroup limit for allocator overhead
    VALKEY_MAXMEM="$(( redis_mb * 85 / 100 ))mb"
  fi

  if (( USER_SET_PG_SHARED_BUFFERS == 0 )); then
    shared_buffers_mb="$(awk -v p="$POSTGRES_MEM_GB" 'BEGIN{v=int(0.25*p*1024); if(v>2048)v=2048; if(v<128)v=128; printf "%d", v}')"
    PG_SHARED_BUFFERS="${shared_buffers_mb}MB"
  else
    shared_buffers_mb="$(echo "$PG_SHARED_BUFFERS" | tr -dc '0-9' || true)"
    shared_buffers_mb="${shared_buffers_mb:-256}"
  fi

  if (( USER_SET_PG_EFFECTIVE_CACHE_SIZE == 0 )); then
    effective_cache_mb="$(awk -v r="$RAM_GB" 'BEGIN{v=int(0.70*r*1024); if(v<256)v=256; printf "%d", v}')"
    PG_EFFECTIVE_CACHE_SIZE="${effective_cache_mb}MB"
  fi

  if (( USER_SET_PG_WORK_MEM == 0 )); then PG_WORK_MEM="8MB"; fi

  if (( USER_SET_PG_MAINTENANCE_WORK_MEM == 0 )); then
    maintenance_work_mb="$(awk -v p="$POSTGRES_MEM_GB" 'BEGIN{v=int(0.15*p*1024); if(v>1024)v=1024; if(v<64)v=64; printf "%d", v}')"
    PG_MAINTENANCE_WORK_MEM="${maintenance_work_mb}MB"
  fi

  if (( USER_SET_PG_MAX_CONNECTIONS == 0 )); then PG_MAX_CONNECTIONS="50"; fi

  if (( USER_SET_PG_MAX_WORKER_PROCESSES == 0 )); then
    PG_MAX_WORKER_PROCESSES="$(clamp_int "$CPU_CORES" 4 16)"
  fi
  if (( USER_SET_PG_MAX_PARALLEL_WORKERS == 0 )); then
    PG_MAX_PARALLEL_WORKERS="$(clamp_int $(( CPU_CORES / 2 )) 2 8)"
  fi
  if (( USER_SET_PG_MAX_PARALLEL_WORKERS_PER_GATHER == 0 )); then
    PG_MAX_PARALLEL_WORKERS_PER_GATHER="$(clamp_int $(( CPU_CORES / 4 )) 1 4)"
  fi
  if (( USER_SET_PG_MAX_PARALLEL_MAINTENANCE_WORKERS == 0 )); then
    PG_MAX_PARALLEL_MAINTENANCE_WORKERS="$(clamp_int $(( CPU_CORES / 4 )) 1 4)"
  fi

  if (( USER_SET_POSTGRES_SHM_SIZE == 0 )); then
    POSTGRES_SHM_SIZE="$(( shared_buffers_mb < 256 ? 256 : shared_buffers_mb ))mb"
  fi

  ratio="${OPENCLAW_WORKER_PER_AGENTS:-2}"
  (( ratio > 0 )) || ratio=2
  workers="$(ceil_div "${OPENCLAW_AGENT_TARGET:-10}" "$ratio")"
  OPENCLAW_WORKERS_RECOMMENDED="$workers"

  openclaw_cpu_quota="$(awk -v c="$c" 'BEGIN{v=(c<1.5?c:1.5); printf "%.2f", v}')"
  postgres_cpu_quota="$(awk -v c="$c" 'BEGIN{v=(c<1.2?c:1.2); printf "%.2f", v}')"
  redis_cpu_quota="${REDIS_CPU_QUOTA_DEFAULT:-0.30}"

  if (( USER_SET_OPENCLAW_CPU_QUOTA == 0 )); then OPENCLAW_CPU_QUOTA="$openclaw_cpu_quota"; fi
  if (( USER_SET_POSTGRES_CPU_QUOTA == 0 )); then POSTGRES_CPU_QUOTA="$postgres_cpu_quota"; fi
  if (( USER_SET_REDIS_CPU_QUOTA == 0 )); then REDIS_CPU_QUOTA="$redis_cpu_quota"; fi

  if (( USER_SET_SWAP_GB == 0 )); then
    SWAP_GB="$(awk -v r="$RAM_GB" 'BEGIN{v=int(0.5*r); if(v<2)v=2; if(v>16)v=16; printf "%d", v}')"
  fi

  OPENCLAW_MEM_LIMIT="${openclaw_mb}m"
}

#!/usr/bin/env bash

RAM_TIER=""

apply_tier_s(){
  : "${SWAP_GB:=2}"
  : "${POSTGRES_MEM_LIMIT:=1100m}"
  : "${POSTGRES_SHM_SIZE:=256mb}"
  : "${VALKEY_MEM_LIMIT:=256m}"
  : "${VALKEY_MAXMEM:=192mb}"
  : "${PG_SHARED_BUFFERS:=256MB}"
  : "${PG_EFFECTIVE_CACHE_SIZE:=768MB}"
  : "${PG_WORK_MEM:=16MB}"
  : "${PG_MAINTENANCE_WORK_MEM:=128MB}"
  : "${PG_MAX_CONNECTIONS:=80}"
}

apply_tier_m(){
  : "${SWAP_GB:=4}"
  : "${POSTGRES_MEM_LIMIT:=2200m}"
  : "${POSTGRES_SHM_SIZE:=512mb}"
  : "${VALKEY_MEM_LIMIT:=512m}"
  : "${VALKEY_MAXMEM:=384mb}"
  : "${PG_SHARED_BUFFERS:=512MB}"
  : "${PG_EFFECTIVE_CACHE_SIZE:=2048MB}"
  : "${PG_WORK_MEM:=16MB}"
  : "${PG_MAINTENANCE_WORK_MEM:=256MB}"
  : "${PG_MAX_CONNECTIONS:=120}"
}

apply_tier_l(){
  : "${SWAP_GB:=8}"
  : "${POSTGRES_MEM_LIMIT:=5000m}"
  : "${POSTGRES_SHM_SIZE:=1gb}"
  : "${VALKEY_MEM_LIMIT:=1024m}"
  : "${VALKEY_MAXMEM:=768mb}"
  : "${PG_SHARED_BUFFERS:=1536MB}"
  : "${PG_EFFECTIVE_CACHE_SIZE:=6144MB}"
  : "${PG_WORK_MEM:=32MB}"
  : "${PG_MAINTENANCE_WORK_MEM:=512MB}"
  : "${PG_MAX_CONNECTIONS:=200}"
}

apply_tier_xl(){
  : "${SWAP_GB:=8}"
  : "${POSTGRES_MEM_LIMIT:=9000m}"
  : "${POSTGRES_SHM_SIZE:=2gb}"
  : "${VALKEY_MEM_LIMIT:=2048m}"
  : "${VALKEY_MAXMEM:=1536mb}"
  : "${PG_SHARED_BUFFERS:=3072MB}"
  : "${PG_EFFECTIVE_CACHE_SIZE:=12288MB}"
  : "${PG_WORK_MEM:=32MB}"
  : "${PG_MAINTENANCE_WORK_MEM:=1024MB}"
  : "${PG_MAX_CONNECTIONS:=300}"
}

detect_tier(){
  if [[ -n "${FORCE_RAM_TIER:-}" ]]; then
    case "$FORCE_RAM_TIER" in
      S|M|L|XL) RAM_TIER="$FORCE_RAM_TIER"; return 0 ;;
      *) die "FORCE_RAM_TIER only supports S/M/L/XL" ;;
    esac
  fi

  if (( RAM_GB >= 32 )); then
    RAM_TIER="XL"
  elif (( RAM_GB >= 16 )); then
    RAM_TIER="L"
  elif (( RAM_GB >= 8 )); then
    RAM_TIER="M"
  else
    RAM_TIER="S"
  fi
}

apply_ram_tier_defaults(){
  detect_tier

  case "$RAM_TIER" in
    S) apply_tier_s ;;
    M) apply_tier_m ;;
    L) apply_tier_l ;;
    XL) apply_tier_xl ;;
    *) die "Unknown RAM_TIER: $RAM_TIER" ;;
  esac
}

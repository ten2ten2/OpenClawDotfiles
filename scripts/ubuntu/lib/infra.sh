#!/usr/bin/env bash

render_infra(){
  log "Generate ${OPENCLAW_BASE}/infra (pgvector + valkey)"

  local infra_dir="${OPENCLAW_BASE}/infra"
  install -d -m 750 "${infra_dir}/db-init" "${OPENCLAW_BASE}/data" "${OPENCLAW_BASE}/backups"

  cp "${REPO_ROOT}/templates/infra/db-init/01-pgvector.sql" "${infra_dir}/db-init/01-pgvector.sql"

  cat >"${infra_dir}/.env" <<CFG
POSTGRES_DB=${POSTGRES_DB}
POSTGRES_USER=${POSTGRES_USER}
POSTGRES_PASSWORD=${POSTGRES_PASSWORD}

PGVECTOR_IMAGE=${PGVECTOR_IMAGE}
VALKEY_IMAGE=${VALKEY_IMAGE}

POSTGRES_SHM_SIZE=${POSTGRES_SHM_SIZE}
POSTGRES_MEM_LIMIT=${POSTGRES_MEM_LIMIT}
VALKEY_MEM_LIMIT=${VALKEY_MEM_LIMIT}
VALKEY_MAXMEM=${VALKEY_MAXMEM}

PG_SHARED_BUFFERS=${PG_SHARED_BUFFERS}
PG_EFFECTIVE_CACHE_SIZE=${PG_EFFECTIVE_CACHE_SIZE}
PG_WORK_MEM=${PG_WORK_MEM}
PG_MAINTENANCE_WORK_MEM=${PG_MAINTENANCE_WORK_MEM}
PG_MAX_CONNECTIONS=${PG_MAX_CONNECTIONS}
CFG
  chmod 600 "${infra_dir}/.env"

  cp "${REPO_ROOT}/templates/infra/docker-compose.infra.yml.example" "${infra_dir}/docker-compose.infra.yml"
}

maybe_start_infra(){
  [[ "${START_INFRA}" == "1" ]] || return 0

  log "Start infra (pgvector + valkey)"
  ( cd "${OPENCLAW_BASE}/infra" && docker compose -f docker-compose.infra.yml up -d )
  docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'
}

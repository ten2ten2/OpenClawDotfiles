#!/usr/bin/env bash

OS_VERSION=""
RAM_GB=0
CPU_CORES=0
DISK_FREE_GB=0
DISK_ROTA=""
OPENCLAW_WORKERS_RECOMMENDED=1

PREFLIGHT_WARNINGS=()
PREFLIGHT_FAILURES=()

append_warning(){
  PREFLIGHT_WARNINGS+=("$1")
}

append_failure(){
  PREFLIGHT_FAILURES+=("$1")
}

fail_or_warn(){
  local message="$1"
  if [[ "${PREFLIGHT_STRICT:-1}" == "1" && "${ALLOW_WEAK_HOST:-0}" != "1" ]]; then
    append_failure "$message"
  else
    append_warning "$message"
  fi
}

check_os(){
  local os_id
  local os_version

  [[ -f /etc/os-release ]] || die "Cannot find /etc/os-release; unable to detect OS"
  # shellcheck disable=SC1091
  source /etc/os-release

  os_id="${ID:-unknown}"
  os_version="${VERSION_ID:-unknown}"

  [[ "$os_id" == "ubuntu" ]] || fail_or_warn "Current OS is not Ubuntu (ID=${os_id})"

  if command -v dpkg >/dev/null 2>&1; then
    dpkg --compare-versions "$os_version" ge "24.04" || fail_or_warn "Ubuntu version is too old: ${os_version} (requires 24.04+)"
  else
    fail_or_warn "Missing dpkg; unable to compare Ubuntu version"
  fi

  OS_VERSION="$os_version"
}

check_systemd(){
  [[ -d /run/systemd/system ]] || fail_or_warn "No systemd runtime detected (/run/systemd/system missing)"
  command -v systemctl >/dev/null 2>&1 || fail_or_warn "Missing systemctl; unable to manage services"
}

check_apt_update(){
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -y >/dev/null 2>&1 || fail_or_warn "apt-get update failed (check internet, DNS, or mirror)"
}

check_network_egress(){
  local docker_repo_url="https://download.docker.com/linux/ubuntu/dists/"
  local cf_repo_url="https://pkg.cloudflare.com/cloudflared/dists/any/InRelease"

  curl -fsSLI --connect-timeout 8 "$docker_repo_url" >/dev/null 2>&1 || fail_or_warn "Cannot reach Docker APT repository: $docker_repo_url"
  curl -fsSLI --connect-timeout 8 "$cf_repo_url" >/dev/null 2>&1 || fail_or_warn "Cannot reach Cloudflare APT repository: $cf_repo_url"
}

collect_resources(){
  local mem_kb
  local root_src
  local root_pk
  local root_dev

  mem_kb="$(awk '/MemTotal/ {print $2}' /proc/meminfo)"
  RAM_GB=$(( mem_kb / 1024 / 1024 ))

  CPU_CORES="$(nproc --all)"

  DISK_FREE_GB="$(df -BG --output=avail / | tail -1 | tr -dc '0-9')"

  root_src="$(findmnt -n -o SOURCE / || true)"
  root_pk="$(lsblk -n -o PKNAME "$root_src" 2>/dev/null | head -n1 || true)"
  if [[ -n "$root_pk" ]]; then
    root_dev="/dev/${root_pk}"
  else
    root_dev="$root_src"
  fi
  DISK_ROTA="$(lsblk -n -d -o ROTA "$root_dev" 2>/dev/null | head -n1 || true)"

  if [[ "$CPU_CORES" -gt 1 ]]; then
    OPENCLAW_WORKERS_RECOMMENDED=$((CPU_CORES - 1))
  fi
}

check_min_resources(){
  (( RAM_GB >= MIN_RAM_GB )) || fail_or_warn "Insufficient RAM: ${RAM_GB}GiB (minimum ${MIN_RAM_GB}GiB)"
  (( CPU_CORES >= MIN_CPU_CORES )) || fail_or_warn "Insufficient CPU cores: ${CPU_CORES} (minimum ${MIN_CPU_CORES})"
  (( DISK_FREE_GB >= MIN_DISK_FREE_GB )) || fail_or_warn "Insufficient free disk space: ${DISK_FREE_GB}GiB (minimum ${MIN_DISK_FREE_GB}GiB)"
}

check_disk_risk(){
  [[ "$DISK_ROTA" != "1" ]] || append_warning "Root disk appears to be HDD (ROTA=1); RAG writes/indexing/PG checkpoints may be unstable"
}

print_preflight_report(){
  local item

  log "Preflight check results"
  echo "  OS_VERSION=${OS_VERSION}"
  echo "  RAM_GB=${RAM_GB}"
  echo "  CPU_CORES=${CPU_CORES}"
  echo "  DISK_FREE_GB=${DISK_FREE_GB}"
  echo "  DISK_ROTA=${DISK_ROTA:-unknown}"

  if (( ${#PREFLIGHT_WARNINGS[@]} > 0 )); then
    echo ""
    echo "Warnings:"
    for item in "${PREFLIGHT_WARNINGS[@]}"; do
      echo "  - $item"
    done
  fi

  if (( ${#PREFLIGHT_FAILURES[@]} > 0 )); then
    echo ""
    echo "Failures:"
    for item in "${PREFLIGHT_FAILURES[@]}"; do
      echo "  - $item"
    done
    die "Preflight failed; fix reported failures first"
  fi
}

run_preflight(){
  check_os
  check_systemd
  check_apt_update
  check_network_egress
  collect_resources
  check_min_resources
  check_disk_risk
  print_preflight_report
}

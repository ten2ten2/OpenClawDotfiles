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

  [[ -f /etc/os-release ]] || die "找不到 /etc/os-release，无法识别系统"
  # shellcheck disable=SC1091
  source /etc/os-release

  os_id="${ID:-unknown}"
  os_version="${VERSION_ID:-unknown}"

  [[ "$os_id" == "ubuntu" ]] || fail_or_warn "当前系统不是 Ubuntu（ID=${os_id}）"

  if command -v dpkg >/dev/null 2>&1; then
    dpkg --compare-versions "$os_version" ge "24.04" || fail_or_warn "Ubuntu 版本过旧：${os_version}（需要 24.04+）"
  else
    fail_or_warn "缺少 dpkg，无法比较 Ubuntu 版本"
  fi

  OS_VERSION="$os_version"
}

check_systemd(){
  [[ -d /run/systemd/system ]] || fail_or_warn "未检测到 systemd 运行环境（/run/systemd/system 不存在）"
  command -v systemctl >/dev/null 2>&1 || fail_or_warn "缺少 systemctl，无法管理服务"
}

check_apt_update(){
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -y >/dev/null 2>&1 || fail_or_warn "apt-get update 失败（检查外网、DNS 或镜像源）"
}

check_network_egress(){
  local docker_repo_url="https://download.docker.com/linux/ubuntu/dists/"
  local cf_repo_url="https://pkg.cloudflare.com/cloudflared/dists/any/InRelease"

  curl -fsSLI --connect-timeout 8 "$docker_repo_url" >/dev/null 2>&1 || fail_or_warn "无法访问 Docker APT 仓库：$docker_repo_url"
  curl -fsSLI --connect-timeout 8 "$cf_repo_url" >/dev/null 2>&1 || fail_or_warn "无法访问 Cloudflare APT 仓库：$cf_repo_url"
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
  (( RAM_GB >= MIN_RAM_GB )) || fail_or_warn "内存不足：${RAM_GB}GiB（最低 ${MIN_RAM_GB}GiB）"
  (( CPU_CORES >= MIN_CPU_CORES )) || fail_or_warn "CPU 核心不足：${CPU_CORES}（最低 ${MIN_CPU_CORES}）"
  (( DISK_FREE_GB >= MIN_DISK_FREE_GB )) || fail_or_warn "可用磁盘不足：${DISK_FREE_GB}GiB（最低 ${MIN_DISK_FREE_GB}GiB）"
}

check_disk_risk(){
  [[ "$DISK_ROTA" != "1" ]] || append_warning "根盘疑似 HDD（ROTA=1），RAG 写入/索引/PG checkpoint 可能抖动"
}

print_preflight_report(){
  local item

  log "Preflight 检查结果"
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
    die "Preflight 未通过，请先修复失败项"
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

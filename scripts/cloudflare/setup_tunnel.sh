#!/usr/bin/env bash
set -euo pipefail

###############################################################################
# Cloudflare Tunnel (single web admin endpoint, no reverse proxy)
# - Reads /opt/openclaw/bootstrap.env (not committed)
# - Forwards https://CF_HOSTNAME to local CF_LOCAL_URL (must be 127.0.0.1 or Docker internal network)
# - Installs as a systemd service: cloudflared
###############################################################################

BOOTSTRAP_ENV="${BOOTSTRAP_ENV:-/opt/openclaw/bootstrap.env}"

die(){ echo -e "\n[!] $*\n" >&2; exit 1; }
need_root(){ [[ $EUID -eq 0 ]] || die "Please run with sudo"; }
log(){ echo -e "\n[+] $*\n"; }

load_env(){
  [[ -f "$BOOTSTRAP_ENV" ]] || die "Could not find $BOOTSTRAP_ENV (copy from templates/bootstrap.env.example and fill with real values)"
  set -a
  # shellcheck disable=SC1090
  source "$BOOTSTRAP_ENV"
  set +a

  : "${CF_RUN_USER:?CF_RUN_USER is not set}"
  : "${CF_TUNNEL_NAME:?CF_TUNNEL_NAME is not set}"
  : "${CF_HOSTNAME:?CF_HOSTNAME is not set}"
  : "${CF_LOCAL_URL:?CF_LOCAL_URL is not set}"
}

get_tunnel_uuid(){
  sudo -u "${CF_RUN_USER}" -H bash -lc \
    "cloudflared tunnel list --output json" \
    | jq -r ".[] | select(.name==\"${CF_TUNNEL_NAME}\") | .id" \
    | head -n1
}

main(){
  need_root
  load_env

  command -v cloudflared >/dev/null 2>&1 || die "cloudflared is not installed (run scripts/ubuntu/prep.sh first)"
  command -v jq >/dev/null 2>&1 || die "jq is missing (installed by the prep script)"

  log "Cloudflare login (an auth URL will be printed; open it in a browser to finish authorization)"
  sudo -u "${CF_RUN_USER}" -H bash -lc "cloudflared tunnel login"

  log "Create tunnel: ${CF_TUNNEL_NAME}"
  set +e
  out="$(sudo -u "${CF_RUN_USER}" -H bash -lc "cloudflared tunnel create ${CF_TUNNEL_NAME}" 2>&1)"
  rc=$?
  set -e

  UUID=""
  if [[ $rc -eq 0 ]]; then
    echo "$out"
    UUID="$(echo "$out" | grep -Eo '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}' | head -n1)"
  else
    echo "$out"
    UUID="$(get_tunnel_uuid || true)"
  fi
  [[ -n "$UUID" ]] || die "Failed to resolve Tunnel UUID (you can run: cloudflared tunnel list)"

  log "Write /etc/cloudflared/config.yml"
  install -d /etc/cloudflared

  cred="/home/${CF_RUN_USER}/.cloudflared/${UUID}.json"
  [[ -f "$cred" ]] || die "Credentials file not found: $cred (verify CF_RUN_USER home and login flow)"
  install -m 600 "$cred" "/etc/cloudflared/${UUID}.json"

  cat >/etc/cloudflared/config.yml <<EOF
tunnel: ${UUID}
credentials-file: /etc/cloudflared/${UUID}.json

ingress:
  - hostname: ${CF_HOSTNAME}
    service: ${CF_LOCAL_URL}
  - service: http_status:404
EOF

  log "Create/update DNS route: ${CF_HOSTNAME} -> Tunnel"
  sudo -u "${CF_RUN_USER}" -H bash -lc "cloudflared tunnel route dns ${CF_TUNNEL_NAME} ${CF_HOSTNAME}" || true

  log "Install and start systemd service"
  cloudflared --config /etc/cloudflared/config.yml service install || true
  systemctl enable --now cloudflared
  systemctl status cloudflared --no-pager

  log "Done. Access: https://${CF_HOSTNAME}"
  echo "Note: web admin must bind only to 127.0.0.1 (or Docker ports mapped only to 127.0.0.1)"
}

main "$@"

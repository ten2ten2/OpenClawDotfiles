#!/usr/bin/env bash

install_cloudflared_latest(){
  log "Install cloudflared (official APT repository)"

  install -m 0755 -d /usr/share/keyrings
  curl -fsSL https://pkg.cloudflare.com/cloudflare-main.gpg | tee /usr/share/keyrings/cloudflare-main.gpg >/dev/null

  echo "deb [signed-by=/usr/share/keyrings/cloudflare-main.gpg] https://pkg.cloudflare.com/cloudflared any main" \
    > /etc/apt/sources.list.d/cloudflared.list

  apt-get update -y
  apt-get install -y cloudflared
}

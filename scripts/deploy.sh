#!/usr/bin/env bash
set -Eeuo pipefail

[[ "${EUID}" -eq 0 ]] || { echo "Run as root: sudo $0"; exit 1; }

say(){ printf '\n== %s ==\n' "$*"; }
die(){ echo "ERROR: $*" >&2; exit 1; }
ok(){ echo "[OK] $*"; }

trap 'rc=$?; if [[ $rc -ne 0 ]]; then echo; echo "Northstar deployment stopped with exit code $rc."; fi' EXIT

echo "========================================"
echo " Project Northstar v1.1.3 - NEW VPS"
echo "========================================"
echo
echo "This creates a NEW independent server."
echo "It does NOT restore x-ui.db or secrets from another VPS."
echo

say "Preflight"

source /etc/os-release
case "${ID:-}" in
  ubuntu|debian) ;;
  *) die "Supported targets are Ubuntu/Debian. Detected: ${ID:-unknown}" ;;
esac

if command -v x-ui >/dev/null 2>&1 || command -v xray >/dev/null 2>&1 || [[ -e /etc/x-ui || -e /usr/local/x-ui ]]; then
  die "Existing x-ui/Xray installation detected. Use a clean VPS."
fi

command -v apache2 >/dev/null 2>&1 && die "Apache is already installed. Use a clean VPS."
[[ -e /opt/northstar ]] && die "/opt/northstar already exists."

for port in 80 443; do
  ss -lnt 2>/dev/null | awk '{print $4}' | grep -Eq "[:.]${port}$" && die "TCP port ${port} is already in use."
done

ok "Clean VPS preflight passed"

read -rp "Server name [Northstar-02]: " SERVER_NAME
SERVER_NAME="${SERVER_NAME:-Northstar-02}"

while :; do
  read -rp "Domain (DNS must already point to this VPS): " DOMAIN
  [[ "$DOMAIN" =~ ^([A-Za-z0-9](-*[A-Za-z0-9])*\.)+[A-Za-z]{2,}$ ]] && break
  echo "Enter a valid FQDN, e.g. vpn2.example.com"
done

read -rp "Let's Encrypt email: " LE_EMAIL
[[ "$LE_EMAIL" == *"@"* ]] || die "A valid email is required."

read -rp "Subscription local port [2096]: " SUB_PORT
SUB_PORT="${SUB_PORT:-2096}"
[[ "$SUB_PORT" =~ ^[0-9]+$ ]] && (( SUB_PORT >= 1 && SUB_PORT <= 65535 )) || die "Invalid subscription port."

SUB_PATH="/ns-$(openssl rand -hex 6)/"

echo
echo "Server:                $SERVER_NAME"
echo "Domain:                $DOMAIN"
echo "Subscription URI path: $SUB_PATH"
echo
echo "3X-UI will generate panel username, password, local port and web path."
echo
read -rp "Deploy? [y/N]: " CONFIRM
[[ "$CONFIRM" =~ ^[Yy]$ ]] || exit 0

say "Base packages"
echo "APT may wait while Ubuntu finishes background package maintenance."
export DEBIAN_FRONTEND=noninteractive

apt-get -o DPkg::Lock::Timeout=1800 update
apt-get -o DPkg::Lock::Timeout=1800 install -y \
  ca-certificates curl git jq nano nginx certbot python3-certbot-nginx \
  socat unzip tar openssl

ok "Base packages installed"

say "DNS check"
PUBLIC_IP="$(curl -4 -fsS --max-time 10 https://api.ipify.org || true)"
[[ -n "$PUBLIC_IP" ]] || die "Could not determine public IPv4."
DOMAIN_IPS="$(getent ahostsv4 "$DOMAIN" | awk '{print $1}' | sort -u || true)"
[[ -n "$DOMAIN_IPS" ]] || die "Domain $DOMAIN does not resolve to IPv4."
grep -Fxq "$PUBLIC_IP" <<<"$DOMAIN_IPS" || {
  echo "VPS IPv4: $PUBLIC_IP"
  echo "Domain IPv4:"
  echo "$DOMAIN_IPS"
  die "DNS does not point $DOMAIN to this VPS."
}
ok "$DOMAIN resolves to this VPS ($PUBLIC_IP)"

say "Download 3X-UI installer"
XUI_INSTALLER="/tmp/3x-ui-install.sh"
curl --fail --location --silent --show-error \
  https://raw.githubusercontent.com/MHSanaei/3x-ui/master/install.sh \
  -o "$XUI_INSTALLER"
[[ -s "$XUI_INSTALLER" ]] || die "Downloaded 3X-UI installer is empty."
head -n1 "$XUI_INSTALLER" | grep -q '^#!/bin/bash' || die "Downloaded 3X-UI installer is invalid."
ok "3X-UI installer downloaded"

say "Install 3X-UI"
export XUI_NONINTERACTIVE=1
export XUI_SSL_MODE=none
bash "$XUI_INSTALLER"

say "Verify 3X-UI"

systemctl daemon-reload

echo "Waiting for x-ui systemd service..."

XUI_SERVICE_READY=0

for _ in $(seq 1 30); do
  systemctl daemon-reload

  if systemctl cat x-ui.service >/dev/null 2>&1; then
    XUI_SERVICE_READY=1
    break
  fi

  sleep 2
done

[[ "$XUI_SERVICE_READY" -eq 1 ]] \
  || die "x-ui.service was not created within 60 seconds."

systemctl enable x-ui >/dev/null
systemctl restart x-ui

for _ in $(seq 1 30); do
  if systemctl is-active --quiet x-ui; then
    break
  fi
  sleep 2
done

systemctl is-active --quiet x-ui \
  || die "x-ui.service did not become active."

ok "x-ui.service is active"

source /etc/x-ui/install-result.env
[[ -n "${XUI_PANEL_PORT:-}" ]] || die "XUI_PANEL_PORT missing."
[[ -n "${XUI_WEB_BASE_PATH:-}" ]] || die "XUI_WEB_BASE_PATH missing."
[[ -n "${XUI_USERNAME:-}" ]] || die "XUI_USERNAME missing."
[[ -n "${XUI_PASSWORD:-}" ]] || die "XUI_PASSWORD missing."

PANEL_PORT="$XUI_PANEL_PORT"
PANEL_PATH="/${XUI_WEB_BASE_PATH#/}"
PANEL_PATH="${PANEL_PATH%/}/"

[[ -x /usr/local/x-ui/x-ui ]] || die "3X-UI binary not found."
/usr/local/x-ui/x-ui setting -listenIP "127.0.0.1" >/dev/null 2>&1 || die "Failed to bind panel to loopback."
systemctl restart x-ui
sleep 2
systemctl is-active --quiet x-ui || die "x-ui failed after loopback bind."
ss -lnt | awk '{print $4}' | grep -Eq "127\.0\.0\.1:${PANEL_PORT}$|\[::1\]:${PANEL_PORT}$" || die "Panel is not listening on loopback:${PANEL_PORT}."
ok "3X-UI active on 127.0.0.1:${PANEL_PORT}"

mkdir -p /opt/northstar/{backups/daily,backups/scripts,configs/nginx,docs,scripts}

say "Initial Nginx HTTP configuration"
cat > /opt/northstar/configs/nginx/northstar.conf <<EOF
server {
    listen 80;
    server_name ${DOMAIN};

    location / {
        default_type text/plain;
        return 200 "Project Northstar bootstrap\n";
    }
}
EOF
rm -f /etc/nginx/sites-enabled/default
ln -sfn /opt/northstar/configs/nginx/northstar.conf /etc/nginx/sites-enabled/northstar.conf
nginx -t
systemctl enable --now nginx

say "Let's Encrypt"
certbot certonly --nginx -d "$DOMAIN" -m "$LE_EMAIL" --agree-tos --non-interactive
[[ -s "/etc/letsencrypt/live/${DOMAIN}/fullchain.pem" ]] || die "fullchain.pem not found."
[[ -s "/etc/letsencrypt/live/${DOMAIN}/privkey.pem" ]] || die "privkey.pem not found."
ok "Let's Encrypt certificate issued"

say "Production Nginx"
cat > /opt/northstar/configs/nginx/northstar.conf <<EOF
server {
    listen 80;
    server_name ${DOMAIN};
    return 301 https://\$host\$request_uri;
}

server {
    listen 443 ssl http2;
    server_name ${DOMAIN};

    ssl_certificate     /etc/letsencrypt/live/${DOMAIN}/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/${DOMAIN}/privkey.pem;

    ssl_session_timeout 1d;
    ssl_session_cache shared:SSL:10m;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_prefer_server_ciphers off;

    location ${PANEL_PATH} {
        proxy_pass http://127.0.0.1:${PANEL_PORT};
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$http_host;
        proxy_set_header X-Forwarded-Host \$http_host;
        proxy_set_header X-Forwarded-Port \$server_port;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header Range \$http_range;
        proxy_set_header If-Range \$http_if_range;
        proxy_redirect off;
    }

    location ${SUB_PATH} {
        proxy_pass http://127.0.0.1:${SUB_PORT};
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$http_host;
        proxy_set_header X-Forwarded-Host \$http_host;
        proxy_set_header X-Forwarded-Port \$server_port;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header Range \$http_range;
        proxy_set_header If-Range \$http_if_range;
        proxy_redirect off;
    }

    location / {
        default_type text/plain;
        return 200 "Project Northstar is running\n";
    }
}
EOF
nginx -t
systemctl reload nginx
curl -fsS --max-time 10 "https://${DOMAIN}/" | grep -q 'Project Northstar is running' || die "Public HTTPS verification failed."
ok "Public HTTPS is working"

cat > /opt/northstar/server.env <<EOF
SERVER_NAME=${SERVER_NAME}
DOMAIN=${DOMAIN}
PANEL_PORT=${PANEL_PORT}
SUB_PORT=${SUB_PORT}
PANEL_PATH=${PANEL_PATH}
SUB_PATH=${SUB_PATH}
EOF
chmod 600 /opt/northstar/server.env

say "Install Northstar tools"
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
cp -a "${REPO_DIR}/scripts/backup.sh" /opt/northstar/backups/scripts/backup.sh
cp -a "${REPO_DIR}/scripts/verify-new-vps.sh" /opt/northstar/scripts/verify.sh
cp -a "${REPO_DIR}/docs/." /opt/northstar/docs/
chmod 700 /opt/northstar/backups/scripts/backup.sh /opt/northstar/scripts/verify.sh

say "Final base verification"
systemctl is-active --quiet x-ui || die "x-ui is not active."
systemctl is-active --quiet nginx || die "nginx is not active."
nginx -t >/dev/null 2>&1 || die "nginx configuration is invalid."

echo
echo "========================================"
echo " NORTHSTAR BASE DEPLOYMENT COMPLETE"
echo "========================================"
echo
echo "Server:       $SERVER_NAME"
echo "Domain:       $DOMAIN"
echo "Panel:        https://${DOMAIN}${PANEL_PATH}"
echo "Subscription: https://${DOMAIN}${SUB_PATH}<SUB_ID>"
echo
echo "3X-UI credentials:"
echo "  Username: ${XUI_USERNAME}"
echo "  Password: ${XUI_PASSWORD}"
echo
echo "Credentials are also stored root-only in /etc/x-ui/install-result.env"
echo
echo "NEXT:"
echo "  1. Open the panel."
echo "  2. Configure Subscription settings:"
echo "       Port:     ${SUB_PORT}"
echo "       URI Path: ${SUB_PATH}"
echo "  3. Create Reality, Hysteria2 and XHTTP inbounds using docs/INBOUNDS.md."
echo "  4. Run: /opt/northstar/scripts/verify.sh"
echo "  5. Run: /opt/northstar/backups/scripts/backup.sh"
echo
echo "IMPORTANT: inbound ports are intentionally NOT auto-created."

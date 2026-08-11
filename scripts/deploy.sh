#!/usr/bin/env bash
set -Eeuo pipefail

[[ "${EUID}" -eq 0 ]] || { echo "Run as root: sudo $0"; exit 1; }

say(){ printf '\n== %s ==\n' "$*"; }
die(){ echo "ERROR: $*" >&2; exit 1; }
rand_path(){ tr -dc 'A-Za-z0-9' </dev/urandom | head -c "${1:-16}"; }

echo "========================================"
echo " Project Northstar v1.1 — NEW VPS"
echo "========================================"
echo
echo "This creates a NEW independent server."
echo "It does NOT restore x-ui.db or secrets from another VPS."
echo

read -rp "Server name [Northstar-02]: " SERVER_NAME
SERVER_NAME="${SERVER_NAME:-Northstar-02}"

while :; do
  read -rp "Domain (DNS must already point to this VPS): " DOMAIN
  [[ "$DOMAIN" =~ ^[A-Za-z0-9.-]+\.[A-Za-z]{2,}$ ]] && break
  echo "Enter a valid FQDN, e.g. vpn2.example.com"
done

read -rp "Let's Encrypt email: " LE_EMAIL
[[ "$LE_EMAIL" == *"@"* ]] || die "A valid email is required."

read -rp "Panel local port [2053]: " PANEL_PORT
PANEL_PORT="${PANEL_PORT:-2053}"

read -rp "Subscription local port [2096]: " SUB_PORT
SUB_PORT="${SUB_PORT:-2096}"

PANEL_PATH="/$(rand_path 20)/"
SUB_PATH="/ns-$(rand_path 12)/"

echo
echo "Server:       $SERVER_NAME"
echo "Domain:       $DOMAIN"
echo "Panel:        https://$DOMAIN$PANEL_PATH"
echo "Subscription: https://$DOMAIN$SUB_PATH<SUB_ID>"
echo
read -rp "Deploy? [y/N]: " CONFIRM
[[ "$CONFIRM" =~ ^[Yy]$ ]] || exit 0

say "Base packages"
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y ca-certificates curl git jq nano nginx certbot python3-certbot-nginx \
  socat unzip tar openssl ufw

say "Install 3X-UI"
if ! command -v x-ui >/dev/null 2>&1; then
  export XUI_NONINTERACTIVE=1
  export XUI_INIT_WEB_BASE_PATH="$PANEL_PATH"
  bash <(curl -Ls https://raw.githubusercontent.com/MHSanaei/3x-ui/master/install.sh)
else
  echo "3X-UI already installed; leaving existing installation intact."
fi

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

echo
echo "========================================"
echo " NORTHSTAR BASE DEPLOYMENT COMPLETE"
echo "========================================"
echo "Server:       $SERVER_NAME"
echo "Domain:       $DOMAIN"
echo "Panel:        https://$DOMAIN$PANEL_PATH"
echo "Subscription: https://$DOMAIN$SUB_PATH<SUB_ID>"
echo
echo "3X-UI generated credentials (if freshly installed):"
echo "  /etc/x-ui/install-result.env"
echo
echo "NEXT:"
echo "  1. Open the panel and configure Subscription settings:"
echo "       Port: $SUB_PORT"
echo "       URI Path: $SUB_PATH"
echo "  2. Create Reality, Hysteria2 and XHTTP inbounds using docs/INBOUNDS.md."
echo "  3. Run: /opt/northstar/scripts/verify.sh"
echo "  4. Run: /opt/northstar/backups/scripts/backup.sh"
echo
echo "IMPORTANT: inbound ports are intentionally NOT auto-created."

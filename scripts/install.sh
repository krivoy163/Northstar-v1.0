#!/usr/bin/env bash
set -Eeuo pipefail

if [[ "${EUID}" -ne 0 ]]; then
    echo "Run as root." >&2
    exit 1
fi

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
BACKUP="${1:-}"

echo "== Project Northstar installer =="

export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y \
    ca-certificates curl git jq nano nginx certbot python3-certbot-nginx \
    socat unzip tar openssl

if ! command -v x-ui >/dev/null 2>&1; then
    echo "== Installing 3X-UI =="
    XUI_NONINTERACTIVE=1 bash <(curl -Ls https://raw.githubusercontent.com/mhsanaei/3x-ui/master/install.sh)
else
    echo "== 3X-UI already installed =="
fi

mkdir -p /opt/northstar/{backups/daily,configs/nginx,docs,scripts}

cp -a "${REPO_DIR}/docs/." /opt/northstar/docs/
cp -a "${REPO_DIR}/scripts/." /opt/northstar/scripts/
chmod +x /opt/northstar/scripts/*.sh

systemctl enable nginx x-ui >/dev/null 2>&1 || true

if [[ -n "$BACKUP" ]]; then
    echo "== Backup supplied; restoring =="
    /opt/northstar/scripts/restore.sh "$BACKUP"
else
    echo
    echo "Base installation complete."
    echo "Next:"
    echo "  sudo /opt/northstar/scripts/restore.sh /path/to/northstar-backup.tar.gz"
fi

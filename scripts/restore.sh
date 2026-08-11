#!/usr/bin/env bash
set -Eeuo pipefail

[[ "${EUID}" -eq 0 ]] || { echo "Run as root." >&2; exit 1; }

ARCHIVE="${1:-}"
[[ -n "$ARCHIVE" && -f "$ARCHIVE" ]] || {
  echo "Usage: $0 /path/to/northstar-YYYY-MM-DD_HH-MM-SS.tar.gz" >&2
  exit 1
}

TMP="$(mktemp -d)"
STAMP="$(date +'%Y-%m-%d_%H-%M-%S')"
trap 'rm -rf "$TMP"' EXIT

echo "== Inspecting archive =="
tar -tzf "$ARCHIVE" >/dev/null
tar -xzf "$ARCHIVE" -C "$TMP"

[[ -f "$TMP/x-ui.db" ]] || { echo "ERROR: x-ui.db missing from backup." >&2; exit 1; }
[[ -d "$TMP/configs" ]] || { echo "ERROR: configs/ missing from backup." >&2; exit 1; }

mkdir -p /opt/northstar/backups/pre-restore /opt/northstar/backups/daily

echo "== Saving current state =="
if [[ -f /etc/x-ui/x-ui.db ]]; then
  cp -a /etc/x-ui/x-ui.db "/opt/northstar/backups/pre-restore/x-ui-${STAMP}.db"
fi
if [[ -d /opt/northstar/configs ]]; then
  tar -czf "/opt/northstar/backups/pre-restore/configs-${STAMP}.tar.gz" -C /opt/northstar configs
fi

echo "== Stopping services =="
systemctl stop nginx 2>/dev/null || true
systemctl stop x-ui 2>/dev/null || true

echo "== Restoring x-ui.db =="
mkdir -p /etc/x-ui
install -m 600 "$TMP/x-ui.db" /etc/x-ui/x-ui.db

echo "== Restoring Northstar configs =="
rm -rf /opt/northstar/configs
cp -a "$TMP/configs" /opt/northstar/configs

if [[ -d "$TMP/docs" ]]; then
  echo "== Restoring documentation snapshot =="
  rm -rf /opt/northstar/docs
  cp -a "$TMP/docs" /opt/northstar/docs
fi

if [[ -d "$TMP/letsencrypt" ]]; then
  echo "== Restoring Let's Encrypt state =="
  rm -rf /etc/letsencrypt
  cp -a "$TMP/letsencrypt" /etc/letsencrypt
fi

if [[ -f /opt/northstar/configs/nginx/northstar.conf ]]; then
  rm -f /etc/nginx/sites-enabled/default
  ln -sfn /opt/northstar/configs/nginx/northstar.conf /etc/nginx/sites-enabled/northstar.conf
fi

echo "== Starting 3X-UI =="
systemctl daemon-reload
systemctl enable x-ui nginx >/dev/null 2>&1 || true
systemctl start x-ui
sleep 3

echo "== Validating Nginx =="
if nginx -t; then
  systemctl start nginx
else
  echo "ERROR: nginx -t failed; nginx remains stopped." >&2
  exit 1
fi

echo
echo "Restore completed."
echo "Run: /opt/northstar/scripts/verify.sh"

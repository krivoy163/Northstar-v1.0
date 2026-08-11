#!/bin/bash
set -e

DATE=$(date +"%Y-%m-%d_%H-%M-%S")
DEST="/opt/northstar/backups/daily/$DATE"

mkdir -p "$DEST"

echo "== Backup x-ui =="
cp /etc/x-ui/x-ui.db "$DEST/"

echo "== Backup nginx =="
cp -r /opt/northstar/configs "$DEST/"

echo "== Backup Let's Encrypt =="
cp -a /etc/letsencrypt "$DEST/"

echo "== Backup Project Northstar =="
cp -a /opt/northstar/docs "$DEST/"

echo "== Creating archive =="

tar -czf "/opt/northstar/backups/daily/northstar-$DATE.tar.gz" -C "$DEST" .

rm -rf "$DEST"

echo
echo "Backup completed:"
echo "/opt/northstar/backups/daily/northstar-$DATE.tar.gz"

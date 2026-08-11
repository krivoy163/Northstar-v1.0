# Project Northstar v1.0

Personal multi-protocol VPN infrastructure based on Ubuntu, Nginx, 3X-UI and Xray.
Две инструкции по настройке лежат в корне проекта

## Production stack

- Ubuntu Server
- Nginx + Let's Encrypt
- 3X-UI / Xray
- VLESS Reality
- Hysteria2
- VLESS XHTTP
- Personal subscription links
- Automated backups

Current production domain: `ruba4kisamara.jo3.org`

## Fast path: new VPS

The intended restore workflow is deliberately short.

```bash
git clone <PRIVATE_GITHUB_REPO_URL> Northstar && cd Northstar
sudo ./scripts/install.sh /root/northstar-backup.tar.gz
sudo ./scripts/verify.sh
```

If the backup archive is not yet on the server, copy it first with `scp` or place it in `/root/`.

`install.sh` installs the base packages and 3X-UI, then calls `restore.sh` when an archive path is supplied.

## Normal operating model

3X-UI remains the source of truth for users, inbounds and subscriptions. The repository contains deployment, backup, restore and operational tooling; it intentionally does not duplicate 3X-UI client management.

## Important paths

- Project: `/opt/northstar`
- 3X-UI database: `/etc/x-ui/x-ui.db`
- Nginx config: `/opt/northstar/configs/nginx/northstar.conf`
- Enabled Nginx site: `/etc/nginx/sites-enabled/northstar.conf`
- Let's Encrypt: `/etc/letsencrypt`
- Backups: `/opt/northstar/backups/daily`

## Documentation

Start with:

1. `docs/QUICKSTART.md`
2. `docs/ARCHITECTURE.md`
3. `docs/RUNBOOK.md`
4. `docs/RESTORE.md`
5. `docs/TROUBLESHOOTING.md`

## Release

**Northstar v1.0 — August 2026**

Release baseline is v1.0. Restore tooling matches the verified production backup layout; a real disaster-recovery test on a disposable VPS is still recommended before treating recovery time as guaranteed.

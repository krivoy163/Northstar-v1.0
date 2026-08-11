# Quick Start — restore Northstar on a new VPS

## Before starting

You need:

- a clean supported Linux VPS (Ubuntu is the reference platform);
- root access;
- the Northstar private repository;
- the latest `northstar-*.tar.gz` backup;
- DNS for `ruba4kisamara.jo3.org` already pointing to the new VPS before certificate renewal/reissue.

## Two-command restore

After copying the backup to `/root/`:

```bash
git clone <PRIVATE_GITHUB_REPO_URL> Northstar && cd Northstar
sudo ./scripts/install.sh /root/northstar-backup.tar.gz && sudo ./scripts/verify.sh
```

The installer:

- installs Nginx, Certbot, curl, jq, git and other base tools;
- installs 3X-UI using the upstream installer if it is not already present;
- creates `/opt/northstar`;
- restores `x-ui.db`;
- restores Northstar configs and Let's Encrypt state from the backup;
- recreates the Nginx site symlink;
- starts/enables `x-ui` and Nginx.

## If certificates do not validate on the new VPS

Once DNS points to the new server:

```bash
certbot renew
nginx -t && systemctl reload nginx
```

If renewal is not possible, reissue the domain certificate with Certbot, then re-check paths in `/opt/northstar/configs/nginx/northstar.conf`.

## Final check

```bash
sudo ./scripts/verify.sh
```

Then verify from a client:

- VLESS Reality
- Hysteria2
- VLESS XHTTP
- one personal subscription URL

# NEW VPS — Project Northstar v1.1

This is for a **new independent VPS**, not recovery of the existing production server.

## Prerequisites

1. Ubuntu 24.04 LTS VPS.
2. A new domain/subdomain (for example `de.example.com`) already pointing to the new VPS IPv4.
3. TCP 80/443 reachable so Let's Encrypt can validate the domain.
4. Read-only access from the VPS to the private Northstar GitHub repository.

## 1. Connect private GitHub

Create a dedicated deploy key on the new VPS:

```bash
ssh-keygen -t ed25519 -C "northstar-vps-02" -f /root/.ssh/northstar_github -N ""
cat /root/.ssh/northstar_github.pub
```

In GitHub: repository → Settings → Deploy keys → Add deploy key. Do **not** enable write access.

Then:

```bash
cat >> /root/.ssh/config <<'EOF'
Host github-northstar
    HostName github.com
    User git
    IdentityFile /root/.ssh/northstar_github
    IdentitiesOnly yes
EOF
chmod 600 /root/.ssh/config
ssh -T github-northstar
```

Expected: successful authentication with no shell access.

## 2. Clone and deploy

```bash
git clone git@github-northstar:krivoy163/Northstar-v1.0.git /opt/Northstar
cd /opt/Northstar
sudo ./scripts/deploy.sh
```

The installer asks for server name, domain, Let's Encrypt email and local panel/subscription ports. It generates new random public paths.

3X-UI's official unattended installer generates random credentials and records them in `/etc/x-ui/install-result.env`.

## 3. Open 3X-UI

After deployment, the installer prints the panel URL.

If this was a fresh 3X-UI installation:

```bash
cat /etc/x-ui/install-result.env
```

Keep the credentials private.

## 4. Subscription settings

In 3X-UI configure the subscription server to match the values printed by `deploy.sh`:

- Enabled: ON
- Port: `2096` unless you deliberately selected another
- URI Path: use the generated `/ns-.../` path
- Public domain: your new domain

The subscription server is separate from the panel.

## 5. Inbounds

Create three independent inbounds according to `INBOUNDS.md`:

- VLESS Reality
- Hysteria2
- VLESS XHTTP

Generate fresh keys/UUIDs on this VPS. Do not copy secrets from the first server.

## 6. Verify

```bash
/opt/northstar/scripts/verify.sh
```

Then test all three transports from a real external client.

## 7. First backup

```bash
/opt/northstar/backups/scripts/backup.sh
```

Copy the resulting archive **off the VPS**. It contains sensitive database and TLS material and must not be committed to GitHub.

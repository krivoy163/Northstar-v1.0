# Administrator Runbook

## Service status

```bash
systemctl status nginx --no-pager
systemctl status x-ui --no-pager
x-ui settings
```

## Listening sockets

```bash
ss -lntp
ss -lunp
```

Useful focused checks:

```bash
ss -lntp | grep -E ':443|:2053|:2096|:8443|:9443'
```

## Nginx

Validate before every reload:

```bash
nginx -t
systemctl reload nginx
```

Restart only when necessary:

```bash
systemctl restart nginx
```

## 3X-UI / Xray

```bash
x-ui
x-ui settings
x-ui status
systemctl restart x-ui
journalctl -u x-ui -n 100 --no-pager
```

## Backup now

Repository copy:

```bash
sudo ./scripts/backup.sh
```

Production-installed copy:

```bash
sudo /opt/northstar/scripts/backup.sh
```

## List backups

```bash
ls -lh /opt/northstar/backups/daily/
```

## Subscription health

Replace `<SUB_ID>` with a real user's subscription id:

```bash
curl -I "https://ruba4kisamara.jo3.org/ns-9Fh3Kx7L/<SUB_ID>"
```

Healthy responses normally include HTTP 200 and 3X-UI subscription headers.

## Panel health

```bash
curl -kI https://127.0.0.1:2053/
curl -I https://ruba4kisamara.jo3.org/
```

A 404 on `/` from the local 3X-UI HTTPS listener is not by itself a failure: the panel uses a configured web base path.

## Certificate information

```bash
certbot certificates
openssl s_client -connect ruba4kisamara.jo3.org:443 -servername ruba4kisamara.jo3.org </dev/null 2>/dev/null | openssl x509 -noout -subject -issuer -dates
```

## Change management

Before changing 3X-UI, Nginx or certificates:

```bash
sudo /opt/northstar/scripts/backup.sh
```

Do not update 3X-UI and simultaneously change inbounds. Make one change, verify all three transports, then continue.

# Troubleshooting

## Nginx configuration fails

```bash
nginx -t
```

Do not reload until the test succeeds.

Check:

```bash
cat /opt/northstar/configs/nginx/northstar.conf
ls -l /etc/nginx/sites-enabled/
```

## Panel is unavailable through the domain

First confirm local 3X-UI:

```bash
ss -lntp | grep 2053
curl -vk https://127.0.0.1:2053/
journalctl -u x-ui -n 100 --no-pager
```

Then check Nginx:

```bash
nginx -t
systemctl status nginx --no-pager
```

## Subscription opens the Northstar landing page

The subscription `location` is missing or does not match the URI configured in 3X-UI.

Current production path:

```text
/ns-9Fh3Kx7L/
```

The Nginx block must proxy it to the local subscription server on port `2096`.

## Subscription returns HTTP 200 but client import fails

Fetch the body:

```bash
curl -L "https://ruba4kisamara.jo3.org/ns-9Fh3Kx7L/<SUB_ID>"
```

Then verify in 3X-UI that the user exists in the intended inbounds and that each generated link uses the correct public address/port.

## XHTTP

Current model:

- direct external TLS listener;
- port `9443`;
- HTTP/2 available;
- certificate for `ruba4kisamara.jo3.org`.

Checks:

```bash
ss -lntp | grep 9443
curl -vk https://ruba4kisamara.jo3.org:9443/
```

A plain HTTP request may return `404`; the important checks here are TCP reachability, TLS handshake and expected certificate/ALPN.

## Reality

```bash
ss -lntp | grep 8443
journalctl -u x-ui -n 100 --no-pager
```

If the inbound exists but clients fail, compare the client link with the Reality inbound values (UUID, public key, short ID, SNI and flow).

## Hysteria2

Hysteria2 uses UDP. Do not diagnose it only with `ss -lntp`.

```bash
ss -lunp
journalctl -u x-ui -n 100 --no-pager
```

Check the actual Hysteria2 inbound port in 3X-UI after restore.

## Certificate/private key mix-up

Certificate:

```text
/etc/letsencrypt/live/ruba4kisamara.jo3.org/fullchain.pem
```

Private key:

```text
/etc/letsencrypt/live/ruba4kisamara.jo3.org/privkey.pem
```

Do not use `fullchain.pem` as the private key.

## Emergency commands

```bash
systemctl restart x-ui
systemctl restart nginx
nginx -t
journalctl -u x-ui -n 100 --no-pager
ss -lntp
ss -lunp
```

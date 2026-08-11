# Project Northstar

Version: 1.0.0
Status: Production

## Server

Reference hostname:
weaselcloud-6308

Reference IPv4:
194.147.33.222

Domain:
ruba4kisamara.jo3.org

OS:
Ubuntu 24.04 LTS

Purpose:
Private Family VPN Infrastructure

Maximum Users:
30

## Production Components

- Nginx
- Let's Encrypt
- 3X-UI / Xray
- VLESS Reality
- Hysteria2
- VLESS XHTTP
- 3X-UI Subscription Server
- Automated Northstar backup/restore

## Legacy

VLESS WebSocket `/vpnws` remains present in the production Nginx configuration from the build phase, but is not one of the three final primary transports.

## Release State

Northstar v1.0 is the baseline production release.
Operational changes should be preceded by a backup.

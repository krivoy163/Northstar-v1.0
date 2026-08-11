# Northstar v1.1 — New VPS Deployment

Adds an independent-server deployment workflow without cloning production secrets.

Files:
- `scripts/deploy.sh`
- `scripts/verify-new-vps.sh`
- `docs/NEW-VPS.md`
- `docs/INBOUNDS.md`

The existing v1.0 recovery scripts remain conceptually separate: **deploy** creates a new server; **restore** recreates an existing one.

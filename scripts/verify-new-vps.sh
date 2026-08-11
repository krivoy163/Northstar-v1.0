#!/usr/bin/env bash
set -u
ENV=/opt/northstar/server.env
[[ -f "$ENV" ]] || { echo "Missing $ENV"; exit 1; }
# shellcheck disable=SC1090
source "$ENV"

FAIL=0
ok(){ echo "  [OK]   $*"; }
warn(){ echo "  [WARN] $*"; }
bad(){ echo "  [FAIL] $*"; FAIL=1; }

echo "== Northstar verification =="

systemctl is-active --quiet x-ui && ok "x-ui active" || bad "x-ui inactive"
systemctl is-active --quiet nginx && ok "nginx active" || bad "nginx inactive"
nginx -t >/dev/null 2>&1 && ok "nginx configuration valid" || bad "nginx configuration invalid"
[[ -f /etc/x-ui/x-ui.db ]] && ok "x-ui.db present" || bad "x-ui.db missing"
ss -lnt | grep -q ":${PANEL_PORT} " && ok "panel listener :${PANEL_PORT}" || warn "panel listener :${PANEL_PORT} not detected"
ss -lnt | grep -q ":${SUB_PORT} " && ok "subscription listener :${SUB_PORT}" || warn "subscription listener :${SUB_PORT} not detected"
curl -fsS --max-time 10 "https://${DOMAIN}/" >/dev/null 2>&1 && ok "public HTTPS ${DOMAIN}" || bad "public HTTPS failed"
[[ -d "/etc/letsencrypt/live/${DOMAIN}" ]] && ok "Let's Encrypt certificate present" || bad "Let's Encrypt certificate missing"

echo
echo "Inbound listeners:"
ss -lntup | grep -E 'xray|x-ui' || true
echo
echo "Verify Reality, Hysteria2 and XHTTP ports against the values you selected in 3X-UI."
exit "$FAIL"

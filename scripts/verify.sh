#!/usr/bin/env bash
set -u

DOMAIN="ruba4kisamara.jo3.org"
FAIL=0

ok()   { printf '  [OK]   %s\n' "$*"; }
warn() { printf '  [WARN] %s\n' "$*"; }
bad()  { printf '  [FAIL] %s\n' "$*"; FAIL=1; }

echo "== Northstar verification =="

systemctl is-active --quiet x-ui && ok "x-ui active" || bad "x-ui inactive"
systemctl is-active --quiet nginx && ok "nginx active" || bad "nginx inactive"

if nginx -t >/tmp/northstar-nginx-test 2>&1; then
    ok "nginx configuration valid"
else
    bad "nginx configuration invalid"
    cat /tmp/northstar-nginx-test
fi

[[ -f /etc/x-ui/x-ui.db ]] && ok "x-ui.db present" || bad "x-ui.db missing"

if ss -lnt | grep -q ':2053 '; then ok "panel listener :2053"; else warn "panel listener :2053 not detected"; fi
if ss -lnt | grep -q ':2096 '; then ok "subscription listener :2096"; else warn "subscription listener :2096 not detected"; fi
if ss -lnt | grep -q ':9443 '; then ok "XHTTP listener :9443"; else warn "XHTTP listener :9443 not detected"; fi
if ss -lnt | grep -q ':8443 '; then ok "Reality listener :8443"; else warn "Reality listener :8443 not detected"; fi

if curl -fsS --max-time 10 "https://${DOMAIN}/" >/dev/null 2>&1; then
    ok "public HTTPS ${DOMAIN}"
else
    warn "public HTTPS check failed (DNS/certificate/firewall may still be propagating)"
fi

if [[ -d "/etc/letsencrypt/live/${DOMAIN}" ]]; then
    ok "Let's Encrypt directory present"
else
    warn "Let's Encrypt directory for ${DOMAIN} not found"
fi

echo
if [[ "$FAIL" -eq 0 ]]; then
    echo "Northstar core verification completed without fatal errors."
else
    echo "Northstar verification found fatal errors."
fi

exit "$FAIL"

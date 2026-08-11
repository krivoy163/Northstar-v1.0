# Architecture

## Logical view

```text
Internet
   |
   +-- TCP/443 --> Nginx
   |                |
   |                +--> 3X-UI panel (local HTTPS :2053)
   |                |
   |                +--> Subscription server (local HTTP :2096)
   |                |
   |                `--> Northstar landing response
   |
   +-- VLESS Reality --> Xray direct inbound
   |
   +-- Hysteria2 -----> Xray direct inbound
   |
   `-- VLESS XHTTP ---> Xray direct TLS inbound (:9443)
```

## Core design rules

- 3X-UI/Xray is the source of truth for inbound and client configuration.
- Each person has an individual subscription link.
- A subscription can be used on multiple devices belonging to that user.
- Three transports are kept so a user has alternatives when a network blocks or degrades one transport.
- Nginx terminates public HTTPS for the panel/subscription endpoints.
- XHTTP is exposed directly with its own TLS endpoint.
- Backups include the 3X-UI SQLite database, Northstar configs and Let's Encrypt state.

## Known production endpoints

- Domain: `ruba4kisamara.jo3.org`
- Nginx public HTTPS: `443/tcp`
- 3X-UI local panel: `2053`
- Subscription server: `2096`
- XHTTP: `9443/tcp`
- Reality: `8443/tcp` in the current deployment
- Hysteria2: preserved in `x-ui.db`; inspect current inbound configuration after restore

## Legacy note

VLESS WebSocket was tested during development but is not part of the final Northstar v1.0 transport set. If an old `/vpnws` location or WS inbound remains in a restored configuration, it can be removed after confirming that Reality, Hysteria2 and XHTTP are healthy.

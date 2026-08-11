# Backup and Restore

## What a Northstar backup contains

The v1 backup format stores:

- `/etc/x-ui/x-ui.db`
- `/opt/northstar/configs`
- `/etc/letsencrypt`
- `/opt/northstar/docs` when present

The archive intentionally does not need the installed 3X-UI binaries; they are installed fresh on the target VPS.

## Create a backup

```bash
sudo ./scripts/backup.sh
```

Default destination:

```text
/opt/northstar/backups/daily/
```

Backups older than 30 days are removed by the repository version of `backup.sh`.

## Restore to an already prepared server

```bash
sudo ./scripts/restore.sh /root/northstar-YYYY-MM-DD_HH-MM-SS.tar.gz
sudo ./scripts/verify.sh
```

## Full disaster recovery

```text
1. Provision a new Ubuntu VPS.
2. Point DNS to the new public IP.
3. Copy the latest Northstar backup to /root/.
4. Clone the private Northstar repository.
5. Run install.sh with the backup path.
6. Run verify.sh.
7. Test Reality, Hysteria2, XHTTP and a subscription from a real client.
```

## Rollback safety

`restore.sh` makes a timestamped copy of the existing `/etc/x-ui/x-ui.db` before replacing it.

## Certificate caution

Restoring `/etc/letsencrypt` preserves existing certificate/private-key material. On a new VPS, confirm that DNS points to the new server and that automatic renewal is healthy. If necessary, reissue the certificate rather than trying to repair an expired chain manually.

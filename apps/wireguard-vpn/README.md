# Wireguard

## Get a peer config file

Peers are named (`PEERS` in `config-map.yaml`), and each one gets a
`/config/peer_<name>/` directory. For the `pc` peer:

```bash
kubectl exec -n wireguard deployment/wireguard -- cat /config/peer_pc/peer_pc.conf
```

## Show a peer QR code

```bash
kubectl exec -n wireguard deployment/wireguard -- /app/show-peer pc
```

## Backup

Archived nightly by the host cron with `backups/general_pvc_backup.sh`, see the
`-- WireGuard --` entries in `backups/crontab.bak` (the single source for those lines)
and `docs/backups/README.md` for the restore procedure.

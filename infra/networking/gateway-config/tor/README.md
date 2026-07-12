# TOR

## Backup

```bash
crontab -e
```

Add:

```bash
0 3 * * * /home/ubuntu/k3s-personal-servers/backups/general_pvc_backup.sh -n envoy-gateway-system -N tor -p tor-hostname-data >> /home/ubuntu/backups/envoy-gateway-system/backup-tor.log 2>&1
```

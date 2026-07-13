# Immich database Postgres

## Backup

### Crontask

Do

```bash
crontab -e
```

And add this line (adapt do correct location if needed)

```bash
0 3 * * * /home/ubuntu/k3s-personal-servers/backups/general_pvc_backup.sh -n immich -N immich-postgres -p backup-immich-pvc >> /home/ubuntu/backups/immich/backup-immich.log 2>&1
```
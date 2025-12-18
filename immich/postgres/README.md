# Immich database Postgres

## Backup

### Crontask

Do

```bash
crontab -e
```

And add this line (adapt do correct location if needed)

```bash
0 3 * * * /home/ubuntu/k3s-personal-servers/immich/postgres/backup.sh >> /home/ubuntu/backups/immich/backup-immich-db.log 2>&1
```
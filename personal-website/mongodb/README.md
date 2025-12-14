# Portfolio mongodb

This database is used by the backend to store users for example.

## Back up

Create `backup-pvc.yaml` and `backup-cron-job.yaml`

Add crontab with:
```bash
crontab -e
```

Add this line:

```bash
0 3 * * * /home/ubuntu/k3s-personal-servers/personal-website/mongodb/backup.sh >> /home/ubuntu/backups/portfolio/backup-mongodb.log 2>&
```

## Restore 

For example (adapte the archive name). Do it inside the container.

```bash
mongorestore --archive=mongo-backup-2025-12-14_08-06-20 --verbose
```
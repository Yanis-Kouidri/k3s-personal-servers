# Strapi postgres database

## Back up

Create `backup-pvc.yaml` and `backup-cron-job.yaml` 

Then:

```bash
crontab -e
```

And add this line:

```bash
0 3 * * * /home/ubuntu/k3s-personal-servers/personal-website/postgres-strapi/backup.sh >> /home/ubuntu/backups/portfolio/backup-strapi-db.log 2>&
```
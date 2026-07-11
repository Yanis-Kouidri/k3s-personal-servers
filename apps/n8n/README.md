# n8n

## Install

Deploy postgres then n8n. Nothing special

## Backup

Add these two crontab

```bash
0 3 * * * /home/ubuntu/k3s-personal-servers/backups/general_pvc_backup.sh -n n8n -N n8n-postgres -p backup-n8n-pvc >> /home/ubuntu/backups/n8n/backup-n8n.log 2>&1

0 3 * * * /home/ubuntu/k3s-personal-servers/backups/general_pvc_backup.sh -n n8n -N n8n-itself -p n8n-claim0 >> /home/ubuntu/backups/n8n/backup-n8n.log 2>&1
```
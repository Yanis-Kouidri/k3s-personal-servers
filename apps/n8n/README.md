# n8n

## Install

PostgreSQL runs as a single-replica `StatefulSet`. The existing
`postgresql-pvc` is referenced explicitly instead of using
`volumeClaimTemplates`, so the database data remains on the current volume.
The existing headless `postgres-service` is used for the StatefulSet network
identity.

During a migration, scale the existing Deployment to zero before applying the
Kustomization, then remove the obsolete Deployment after the StatefulSet is
ready. The PVC must not be deleted.

## Backup

Add these two crontab

```bash
0 3 * * * /home/ubuntu/k3s-personal-servers/backups/general_pvc_backup.sh -n n8n -N n8n-postgres -p backup-n8n-pvc >> /home/ubuntu/backups/n8n/backup-n8n.log 2>&1

0 3 * * * /home/ubuntu/k3s-personal-servers/backups/general_pvc_backup.sh -n n8n -N n8n-itself -p n8n-claim0 >> /home/ubuntu/backups/n8n/backup-n8n.log 2>&1
```
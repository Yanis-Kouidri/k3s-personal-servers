# Immich database Postgres

The database runs as a single-replica `StatefulSet`. The existing
`postgres-immich-pvc` is referenced explicitly instead of using
`volumeClaimTemplates`, so the database data remains on the current volume.
The existing `postgres` Service remains unchanged for clients, while the
dedicated `postgres-headless` Service provides the stable network identity
required by the StatefulSet.

During the migration, scale the existing Deployment to zero before applying
the Kustomization, then remove the obsolete Deployment after the StatefulSet
is ready. The PVC must not be deleted.

## Backup

### Crontask

Do

```bash
crontab -e
```

And add this line (adapt do correct location if needed)

```bash
0 3 * * * /home/ubuntu/k3s-personal-servers/backups/general_pvc_backup.sh -n immich -N immich-postgres -p backup-immich-pvc >> /home/ubuntu/backups/immich/backup-immich-postgres.log 2>&1
```
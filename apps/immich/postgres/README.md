# Immich database Postgres

The database runs as a single-replica `StatefulSet` (`postgres-immich-db`). The
`postgres-immich-pvc` volume is referenced explicitly instead of through
`volumeClaimTemplates`: it predates the StatefulSet, which replaced a
Deployment, and must never be deleted. The `postgres` Service is what clients
use; `postgres-headless` gives the StatefulSet its network identity.

## Backup

`backup-cron-job.yaml` dumps the database nightly into `backup-immich-pvc`, and
`restore-verify-cron-job.yaml` restores the latest dump weekly to prove it
works. That PVC is then archived by the host cron:

Archived nightly by the host cron with `backups/general_pvc_backup.sh`, see the
`-- Immich --` entries in `backups/crontab.bak` (the single source for those lines)
and `docs/backups/README.md` for the restore procedure.

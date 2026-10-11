# n8n

PostgreSQL runs as a single-replica `StatefulSet` (`postgres`). The
`postgresql-pvc` volume is referenced explicitly instead of through
`volumeClaimTemplates`: it predates the StatefulSet, which replaced a
Deployment, and must never be deleted. The headless `postgres-service` gives
the StatefulSet its network identity.

## Backup

`postgres/backup-cron-job.yaml` dumps the database nightly into
`backup-n8n-pvc`, and `postgres/restore-verify-cron-job.yaml` restores the
latest dump weekly. That PVC and n8n's own data (`n8n-claim0`) are then
archived by the host cron:

Archived nightly by the host cron with `backups/general_pvc_backup.sh`, see the
`-- n8n --` entries in `backups/crontab.bak` (the single source for those lines)
and `docs/backups/README.md` for the restore procedure.

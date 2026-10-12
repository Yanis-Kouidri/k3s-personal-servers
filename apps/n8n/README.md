# n8n

## Access

n8n is only reachable through the WireGuard VPN (`apps/wireguard-vpn`), webhooks
included: `n8n/security-policy.yaml` makes Envoy answer 403 to any client outside
the pod network. Connect to the VPN, then open https://n8n.kouidri.fr as usual.
A trigger called from the Internet (webhook, form) no longer works; to expose one,
add a route for its path that the policy does not target.

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

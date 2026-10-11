# TOR

Onion service of the personal website. Its hostname and keys live on the
`tor-hostname-data` volume: losing it means a new `.onion` address.

## Backup

Archived nightly by the host cron with `backups/general_pvc_backup.sh`, see the
`-- Tor --` entries in `backups/crontab.bak` (the single source for those lines)
and `docs/backups/README.md` for the restore procedure.

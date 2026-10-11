# Immich Server

## Backup

To ensure backups work correctly, go to the web UI (photos.kouidri.fr) and follow these steps:

1. Click the top-right icon  
2. Select **Administration**  
3. Go to **Settings**  
4. Go to **Storage Template**  
5. Turn **Enable storage template engine** → **ON**  
6. Click **Save**

### Restore from Backup

The archive holds the whole `server-immich-pvc` volume (library, uploads,
thumbnails...). It is only half of Immich: restore it together with the
database dump of the same day, as described in `docs/backups/README.md`.

If thumbnails are missing afterwards, go to **Administration** → **Jobs** in the
web UI and run **Generate Thumbnails**.

### Crontask

Archived nightly by the host cron with `backups/general_pvc_backup.sh`, see the
`-- Immich --` entries in `backups/crontab.bak` (the single source for those lines)
and `docs/backups/README.md` for the restore procedure.

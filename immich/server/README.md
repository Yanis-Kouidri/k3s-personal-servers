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

If data is lost on the server side, the backup archive contains only the `library` folder.

To restore:

1. Extract the archive  
2. Place the `library` folder on the Immich volume  
3. In the web UI, go to **Administration** → **Jobs**  
4. Run **Generate Thumbnails**

### Crontask

Do

```bash
crontab -e
```

And add this line (adapt do correct location if needed)

```bash
0 3 * * * /home/ubuntu/k3s-personal-servers/immich/server/backup.sh >> /home/ubuntu/backups/immich/backup-immich.log 2>&
```
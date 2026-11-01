# Backup

`get_backup_folder.sh` runs on another machine (a personal computer) and pulls the
VPS backup folder there: it is the only copy that survives losing the node.

To run it automatically:

1. Clone the repo on an external machine such as personal computer.

2. Check the settings at the top of `backups/get_backup_folder.sh`. Each one can be
   overridden from the environment instead of editing the script: `VPS_NAME` (the
   host alias in `~/.ssh/config`, default `ovh-vps`), `SOURCE_DIR`, `DEST_DIR`
   (default `$HOME/vps_backups/`), `LOG_FILE` (default `$HOME/pull_backups.log`),
   `HISTORY_DIR` (default `$HOME/vps_backups_history`) and `HISTORY_DAYS` (default `7`).

3. Install anacron

```bash
sudo apt install anacron
```

4. Create a file here (with sudo) `/etc/cron.daily/pull_backup_from_vps`

With this content: (adapt user and path if needed)


```bash
#!/bin/bash

runuser -u yanis -- /home/yanis/k3s-personal-servers/backups/get_backup_folder.sh
```

5. Make both scripts executable

```bash
sudo chmod +x /etc/cron.daily/pull_backup_from_vps
```

```bash
sudo chmod +x k3s-personal-servers/backups/get_backup_folder.sh
```

6. Check the log file (`$HOME/pull_backups.log` by default) after the first run.

## History on the external machine

`DEST_DIR` is an exact mirror of the VPS folder (`rsync --delete`), so on its own it
would lose a backup as soon as the VPS loses it. Every file the mirror deletes or
replaces is moved instead to `HISTORY_DIR/<date of the pull>/`, with the same
layout, and these dated folders are removed after `HISTORY_DAYS` days.

To restore an older archive, look for it in `HISTORY_DIR`:

```bash
ls ~/vps_backups_history/*/immich/immich-server/
```

Each day of history costs roughly one generation of every backup (about 23 GB,
mostly the Immich photos).

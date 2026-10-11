# Backup

`get_backup_folder.sh` runs on another machine (a personal computer) and pulls the
VPS backup folder there: it is the only copy that survives losing the node.

To run it automatically:

1. Clone the repo on an external machine such as personal computer.

2. Check the settings at the top of `backups/get_backup_folder.sh`. Each one can be
   overridden from the environment instead of editing the script: `VPS_NAME` (the
   host alias in `~/.ssh/config`, default `ovh-vps`), `SOURCE_DIR`, `DEST_DIR`
   (default `$HOME/vps_backups/`) and `LOG_FILE` (default `$HOME/pull_backups.log`).

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
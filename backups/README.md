# Backup

This script `get_backup_folder.sh` is aim to be run on a remote machine to copy the backup folder present on VPS.

To perform that automaticaly :

1. Clone the repo on an external machine such as personal computer.

2. Check variable on `k3s-personal-servers/backups/get_backup_folder.sh` script.

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

6. Check the logs to be sure everithing is ok
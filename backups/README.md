# Backup

`get_backup_folder.sh` runs on another machine (a personal computer) and pulls the
VPS backup folder there: it is the only copy that survives losing the node.

## Setup

1. Clone the repo on the external machine.

2. Check the settings at the top of `backups/get_backup_folder.sh`. Each one can be
   overridden from the environment instead of editing the script: `VPS_NAME` (the
   host alias in `~/.ssh/config`, default `ovh-vps`), `SOURCE_DIR`, `DEST_DIR`
   (default `$HOME/vps_backups/`), `LOG_FILE` (default `$HOME/pull_backups.log`),
   `HISTORY_DIR` (default `$HOME/vps_backups_history`) and `HISTORY_DAYS` (default `7`).

3. Make sure `ssh <VPS_NAME>` connects without any prompt (key without passphrase,
   or a running agent): the pull runs unattended.

4. Make the script executable:

```bash
chmod +x backups/get_backup_folder.sh
```

5. Schedule it once a day, after the nightly backups on the VPS (03:00), with the
   method that matches the machine (see below).

6. Check the log file (`$HOME/pull_backups.log` by default) after the first run.

## Scheduling on Windows with WSL (current setup)

The copy is kept in the Ubuntu WSL distribution of a Windows PC. Do not schedule it
from inside WSL (cron, anacron, systemd timer): WSL shuts the distribution down about
a minute after its last process exits, so a job inside it is killed before it starts
or in the middle of the transfer. This is what happened with the former anacron
setup, which stopped pulling for a week without any error.

A Windows scheduled task starts WSL itself and keeps it running until the script
exits. Create it from PowerShell (adapt the distribution, user and path):

```powershell
$action = New-ScheduledTaskAction -Execute "$env:WINDIR\System32\conhost.exe" `
    -Argument '--headless wsl.exe -d Ubuntu -u yanis -e /home/yanis/projects/k3s-personal-servers/backups/get_backup_folder.sh'
$trigger = New-ScheduledTaskTrigger -Daily -At 10:00
$settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -RunOnlyIfNetworkAvailable `
    -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries `
    -ExecutionTimeLimit (New-TimeSpan -Hours 4) -MultipleInstances IgnoreNew `
    -RestartCount 2 -RestartInterval (New-TimeSpan -Minutes 30)
$principal = New-ScheduledTaskPrincipal -UserId "$env:USERDOMAIN\$env:USERNAME" `
    -LogonType Interactive -RunLevel Limited
Register-ScheduledTask -TaskName 'Rapatrier sauvegardes VPS' -Action $action `
    -Trigger $trigger -Settings $settings -Principal $principal
```

- `conhost.exe --headless` runs it without opening a console window.
- `-StartWhenAvailable` runs a missed day as soon as possible when the PC was off
  at 10:00.
- WSL distributions belong to a Windows user, so the task only runs while that
  user is logged on (`-LogonType Interactive`, no password stored). A PC left on
  the login screen does not pull anything.

Run it once by hand and check that it succeeds:

```powershell
Start-ScheduledTask -TaskName 'Rapatrier sauvegardes VPS'
Get-ScheduledTaskInfo -TaskName 'Rapatrier sauvegardes VPS'   # LastTaskResult 0 = success
```

## Scheduling on an always-on Linux machine

On a machine that stays up (a real Linux PC or server, not WSL), anacron is enough:
it runs the daily jobs, and catches up on the next boot when the machine was off.

```bash
sudo apt install anacron
```

Create `/etc/cron.daily/pull_backup_from_vps` (no dot in the name, or `run-parts`
skips it), adapting the user and path:

```bash
#!/bin/bash

runuser -l yanis -c '/home/yanis/projects/k3s-personal-servers/backups/get_backup_folder.sh' >> /var/log/pull_backup_from_vps.log 2>&1
```

```bash
sudo chmod +x /etc/cron.daily/pull_backup_from_vps
```

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

# Minecraft

## Replace the world map

Delete the previous one:

```bash
kubectl exec -n minecraft deployment/minecraft-server -- rm -rf /data/world
```

Copy the new one (`kubectl cp` needs a pod name):

```bash
POD=$(kubectl get pod -n minecraft -l app=minecraft-server -o jsonpath='{.items[0].metadata.name}')
kubectl cp world "minecraft/$POD:/data/world"
```

Give it the right owner:

```bash
kubectl exec -n minecraft deployment/minecraft-server -- chown -R minecraft:minecraft /data/world
```

## RCON console

```bash
kubectl exec -n minecraft -it deployment/minecraft-server -- rcon-cli
```

## Backup

The archive is taken with `-m minecraft-server`: autosave is turned off and the
world flushed through RCON for the duration of the archive.

Archived nightly by the host cron with `backups/general_pvc_backup.sh`, see the
`-- Minecraft --` entries in `backups/crontab.bak` (the single source for those lines)
and `docs/backups/README.md` for the restore procedure.

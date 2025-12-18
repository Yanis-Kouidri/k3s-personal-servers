# Minecraft

## Replace world map: (adapte pod name)

Delete previous one

```bash
    k exec deployments/minecraft-server -- rm -rf /data/world
```

Copy the new one

```bash
    k cp world minecraft-server-569794569d-ltz7v:/data/world
```

Give correct right

```bash
    k exec deployments/minecraft-server -- chown -R minecraft:minecraft /data/world
```

## User rcon

```bash
    k exec deployments/minecraft-server -it -- rcon-cli
```

## Backup

### Crontask

Do

```bash
crontab -e
```

And add this line (adapt do correct location if needed)

```bash
0 3 * * * /home/ubuntu/k3s-personal-servers/minecraft/backup.sh >> /home/ubuntu/backups/minecraft/backup-minecraft.log 2>&1
```
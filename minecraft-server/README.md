# Minecraft

## Replace world map: (adapte pod name)

Delete previous one

```bash
    k exec minecraft-server-569794569d-ltz7v -- rm -rf /data/world
```

Copy the new one

```bash
    k cp world minecraft-server-569794569d-ltz7v:/data/world
```

Give correct right

```bash
    k exec -n minecraft  minecraft-server-569794569d-ltz7v  -- chown -R minecraft:minecraft /data/world
```
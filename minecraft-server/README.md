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
    k exec deployments/minecraft-server  -- chown -R minecraft:minecraft /data/world
```
# Wireguard

## Get a peer config file

Adapt to peer2, peer3, or PEERS varibales configure in config-map etc.

```bash
    kubectl exec deployments/wireguard -- cat /config/peer1/peer1.conf
```

## Show a peer QR code

Adapt pc to 1, 2, 3 or PEERS varibales configure in config-map etc.

```bash
    kubectl exec deployments/wireguard -- /app/show-peer pc
```

## Backup

Open crontab

```bash
crontab -e
```

Add this line:

```bash
0 3 * * * /home/ubuntu/k3s-personal-servers/backups/general_pvc_backup.sh -n wireguard -N wireguard -p wireguard-pvc >> /home/ubuntu/backups/wireguard/backup-wireguard.log 2>&1
```

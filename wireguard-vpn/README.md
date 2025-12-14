# Wireguard

## Get a peer config file

Adapt to peer2, peer3, etc.

```bash
    kubectl exec deployments/wireguard -- cat /config/peer1/peer1.conf
```

## Backup

Open crontab

```bash
crontab -e
```

Add this line:

```bash
0 3 * * * /home/ubuntu/k3s-personal-servers/backup/general_pvc_backup.sh -n wireguard -N wireguard -p wireguard-pv >> /home/ubuntu/backups/wireguard/backup-wireguard.log 2>1&
```

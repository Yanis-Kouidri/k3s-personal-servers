# Wireguard

## Get a peer config file

Adapt to peer2, peer3, etc.

```bash
    kubectl exec deployments/wireguard -- cat /config/peer1/peer1.conf
```
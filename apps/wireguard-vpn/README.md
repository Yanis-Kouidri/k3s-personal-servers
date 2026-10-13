# Wireguard

## Get a peer config file

Peers are named (`PEERS` in `config-map.yaml`), and each one gets a
`/config/peer_<name>/` directory. For the `pc` peer:

```bash
kubectl exec -n wireguard deployment/wireguard -- cat /config/peer_pc/peer_pc.conf
```

## Show a peer QR code

```bash
kubectl exec -n wireguard deployment/wireguard -- /app/show-peer pc
```

## Templates

`templates/` holds the files the image renders `wg0.conf` and the peer confs from,
and the CoreDNS config served to peers. They are copied onto the volume and rendered
again on every start (init container of `deployment.yaml`), so edit them here, not
on the volume. They are evaluated by bash: `$` must only be used for the image's
variables.

- **MTU 1360**: the pod's `eth0` is a flannel VXLAN link (1450), and WireGuard adds
  up to 80 bytes. With the client default (1420) full-size packets were dropped on
  their way into the pod, which stalled TLS handshakes for seconds. The server also
  clamps the TCP MSS to the path MTU, for peers whose conf has not been updated.
- **IPv6**: the tunnel carries `fd13:13:13::/64`, NATed to the pod's IPv6 address.
  The peer address is derived from the IPv4 one and written *before* it in
  `Address`: on restart the image reads the peer IPv4 back as the last field of
  that line. Each peer also needs its `SERVER_ALLOWEDIPS_PEER_<name>` in
  `config-map.yaml`.

A change to `peer.conf` reaches a device only once its conf is imported again.

## Backup

Archived nightly by the host cron with `backups/general_pvc_backup.sh`, see the
`-- WireGuard --` entries in `backups/crontab.bak` (the single source for those lines)
and `docs/backups/README.md` for the restore procedure.

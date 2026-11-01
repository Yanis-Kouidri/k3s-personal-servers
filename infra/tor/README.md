# TOR

Onion service of the personal website, in its own `tor` namespace (Pod Security
`restricted`). It forwards to the Envoy Service on port 80, the only thing it may
reach inside the cluster besides DNS.

Its hostname and keys live on the `tor-hostname-data` volume: losing it means a
new `.onion` address.

## Runs as the tor user, without the image's entrypoint

The container starts `tor -f /etc/tor/torrc` directly as uid 101 / gid 102 (the
image's `tor` user), with no capability and a read-only root filesystem. The
image's entrypoint is not used: it only ran as root to chown the volume, write a
default torrc and drop to that same user.

Nothing fixes ownership any more, so **everything on the volume, the volume's
root directory included, must belong to 101:102** with mode 0700 (directories)
and 0600 (files). Tor refuses a DataDirectory it does not own.

## No key, no start

The `require-onion-key` init container waits as long as
`hidden_service/hs_ed25519_secret_key` is missing, so an empty volume shows up as
a pod stuck in `Init` (its logs say why) instead of Tor quietly publishing a new
address. Restore the volume and the pod carries on by itself.

## Backup

Archived nightly by the host cron with `backups/general_pvc_backup.sh`, see the
`-- Tor --` entries in `backups/crontab.bak` (the single source for those lines)
and `docs/backups/README.md` for the restore procedure. The archive keeps the
101:102 ownership (`--numeric-owner`); after a restore check the volume's root
directory too:

```bash
DIR=$(kubectl get pv "$(kubectl get pvc tor-hostname-data -n tor -o jsonpath='{.spec.volumeName}')" -o jsonpath='{.spec.hostPath.path}')
sudo chown 101:102 "$DIR" && sudo chmod 0700 "$DIR"
```

Archives taken before the move to this namespace (2026-11-01) are under
`/home/ubuntu/backups/envoy-gateway-system/tor/`.

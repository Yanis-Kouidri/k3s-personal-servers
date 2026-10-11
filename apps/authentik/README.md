# Authentik

Authentik is available at `https://auth.kouidri.fr` through the Envoy Gateway.

The Helm chart deploys one Authentik server, one worker, and a persistent
PostgreSQL database. Sensitive bootstrap and database values are stored in
`secrets.enc.yaml` with SOPS.

## Initial login

Flux creates the initial `akadmin` account from the encrypted bootstrap
password. Retrieve it locally with:

```bash
kubectl get secret authentik-config -n authentik \
  -o jsonpath='{.data.AUTHENTIK_BOOTSTRAP_PASSWORD}' | base64 -d; echo
```

The bootstrap password is only applied when `akadmin` does not exist yet. Once
the account has been created, changing `AUTHENTIK_BOOTSTRAP_PASSWORD` in
`secrets.enc.yaml` does not change the password: do it from the admin interface.

## Backup

The database is dumped nightly by `backup-cron-job.yaml` and the dump is
restore-tested weekly by `restore-verify-cron-job.yaml`. See
`docs/backups/README.md` for the restore procedure.

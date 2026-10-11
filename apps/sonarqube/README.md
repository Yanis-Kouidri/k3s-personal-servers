# SonarQube Community

Available at `https://sonarqube.kouidri.fr`. Managed by Flux, together with its
PostgreSQL database.

## Layout

- `helm-release.yaml`: the `sonarqube` chart, values from `sonar-values.yaml`
- `postgres-helm-release.yaml`: the Bitnami `postgresql` chart, values from
  `postgres-values.yaml`. The image is pinned by digest there: the chart
  defaults to `bitnami/postgresql:latest`, so bumping it is a deliberate step
  (backup first).
- `secrets.enc.yaml`: `sonarqube-postgres-secret`, SOPS-encrypted and decrypted
  by Flux at apply time
- `backup-cron-job.yaml` / `restore-verify-cron-job.yaml`: nightly dump and
  weekly restore test, see `docs/backups/README.md`

Both values files are rendered into ConfigMaps by `kustomization.yaml`
(`sonarqube-values`, `postgres-sonarqube-values`).

## Upgrades

1. Renovate bumps `buildNumber` in `sonar-values.yaml` when SonarQube is
   released, and the chart versions in the HelmReleases.
2. Once merged, Flux updates the ConfigMap. The HelmRelease picks the new values
   up at its next interval (5 min), or right away with
   `flux reconcile hr sonarqube -n sonarqube`.

> **Note:** It may be necessary to visit `https://sonarqube.kouidri.fr/setup` to run database migrations after an upgrade.

## Backup

The database dump is taken by `backup-cron-job.yaml` into `backup-sonarqube-pvc`.
Archived nightly by the host cron with `backups/general_pvc_backup.sh`, see the
`-- Sonarqube --` entries in `backups/crontab.bak` (the single source for those lines)
and `docs/backups/README.md` for the restore procedure.

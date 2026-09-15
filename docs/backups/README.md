# Backups and restore

Everything here has been executed against this cluster, not written from
memory. Where a step has a trap in it, the trap is written down.

## What is backed up, and where

Two independent layers.

**PostgreSQL logical dumps**, taken by a CronJob at 02:00 into a dedicated PVC,
kept 7 days:

| App | Job | Format | Lands in |
|---|---|---|---|
| Immich | `immich-db-backup` | plain SQL | `backup-immich-pvc` |
| n8n | `n8n-db-backup` | custom (`pg_restore`) | `backup-n8n-pvc` |
| SonarQube | `sonarqube-db-backup` | plain SQL | `backup-sonarqube-pvc` |

**Whole-PVC archives**, taken by host cron at 03:00 with
`backups/general_pvc_backup.sh`, into `/home/ubuntu/backups/<ns>/<name>/`, 2
generations kept. `backups/get_backup_folder.sh` pulls that tree to a machine
off the VPS — which is the only copy that survives losing the node.

The dump PVCs are themselves archived by the second layer, so a database ends up
in both.

## Verifying a backup is restorable

```bash
scripts/verify-restore.sh              # all three
scripts/verify-restore.sh n8n          # just one
```

For each app it starts a throwaway PostgreSQL in the app's namespace, with its
own empty data directory and the backup PVC mounted **read-only**, restores the
newest dump into it, compares the table count and a few business tables against
the live database, and deletes the pod. Production is only ever read; there is
no path from this script to a running database.

A restored count *lower* than production is normal for append-only tables
(executions, issues) — the dump is a point in time and production has moved on.
Only a **higher** count is reported as a failure.

Last run, 2026-09-15: Immich 67 tables / 5855 assets, n8n 139 tables / 5
workflows, SonarQube 164 tables / 13717 rules — all matching production.

### Automatically, every week

Three CronJobs do a narrower version of the same thing on Sunday mornings —
`immich-restore-verify` at 04:00, `n8n-restore-verify` at 04:30,
`sonarqube-restore-verify` at 05:00, staggered because they compete for the same
disk.

Each one starts a PostgreSQL inside its own container against an emptyDir,
restores this namespace's newest dump into it, and fails the Job if the dump is
missing or empty, if the restore errors, if fewer tables come back than expected,
or if the key table restores empty. A failed Job is picked up by the
`job-monitor` CronJob and reported to Telegram.

They deliberately have **no Kubernetes API access and no network**. Running
`verify-restore.sh` itself in-cluster would have meant granting a ServiceAccount
the right to create pods and exec into the production databases, which is read
access to all their data — a poor trade for a check. The price is that they
compare against fixed thresholds rather than against production; use
`verify-restore.sh` by hand when you want the exact comparison.

## Restoring a database for real

The scratch restore above is the rehearsal. The real thing differs in one way
only: the target is the production database, so **stop what writes to it first**.

```bash
# 1. stop the application (not the database)
kubectl scale deploy/immich-server -n immich --replicas=0

# 2. copy the dump somewhere the database pod can read
kubectl cp <backup-pod>:/backups/immich_db_<date>.sql /tmp/dump.sql
kubectl cp /tmp/dump.sql immich/postgres-immich-db-0:/tmp/dump.sql

# 3. recreate the database and load the dump
kubectl exec -n immich postgres-immich-db-0 -- sh -c '
  dropdb -U postgres immich && createdb -U postgres immich &&
  psql -U postgres -d immich -v ON_ERROR_STOP=1 -f /tmp/dump.sql'

# 4. bring the application back
kubectl scale deploy/immich-server -n immich --replicas=1
```

n8n is the same shape but `pg_restore -d n8n --no-owner --no-privileges` instead
of `psql -f`, and the deployment to scale is `deploy/n8n`.

### Three things that will bite

**The SonarQube dump needs its role to exist first.** It is a plain dump, so it
carries `ALTER TABLE ... OWNER TO sonar`, and psql stops on the first one:

```
psql:/backups/sonarqube_db_...sql:29: ERROR:  role "sonar" does not exist
```

Restoring into the production database is fine — the role is already there. Into
a bare PostgreSQL, run `createuser -U postgres sonar` first. This is what
`verify-restore.sh` does.

**Immich must be restored into an image that has its extensions, and vchord has
to be preloaded.** The dump recreates `vchord` and `vector`; a stock
`postgres:18` has neither and the restore fails. Use
`ghcr.io/immich-app/postgres:18-vectorchord...`, the same image the StatefulSet
runs — and if you start PostgreSQL yourself rather than through the image's
entrypoint, add `-c shared_preload_libraries=vchord`, or `CREATE EXTENSION
vchord` fails in the middle of the dump:

```
extension script file "vchord--0.5.3.sql", near line 23
```

**The database is only half of Immich.** The dump holds metadata; the photos
live on `server-immich-pvc`. Restoring one without the other gives a library
full of broken thumbnails. Restore the PVC archive and the dump from the same
day.

## Restoring a PVC from an archive

```bash
# inspect before extracting anything
sudo tar --use-compress-program=zstd -tf /home/ubuntu/backups/<ns>/<name>/<file>.tar.zst | head

# stop the workload, then extract over the volume path
kubectl scale deploy/<name> -n <ns> --replicas=0
PV=$(kubectl get pvc <pvc> -n <ns> -o jsonpath='{.spec.volumeName}')
DIR=$(kubectl get pv "$PV" -o jsonpath='{.spec.local.path}')
sudo tar --use-compress-program=zstd --numeric-owner -xpf <file>.tar.zst -C "$DIR"
kubectl scale deploy/<name> -n <ns> --replicas=1
```

`--numeric-owner` matters: the archive stores uids, and the names behind them
are not guaranteed to mean the same thing on another host.

Verified on 2026-09-15 with the WireGuard archive: 42 files extracted, and the
server and peer private keys byte-identical to production. The peer `.conf` and
`.png` files differed only on their `Endpoint` line, because `SERVERURL: "auto"`
had since resolved to the node's IPv6 address — drift, not corruption.

## What is NOT backed up

- **The SOPS age private key.** Without it Flux cannot decrypt a single secret,
  and it exists only in the `sops-age` secret in `flux-system` and wherever you
  keep it. Losing it means re-encrypting every secret from scratch. It belongs
  in a password manager, not on this node.
- **Anything that is only in the cluster and not in git**, such as resources
  created by hand. Flux rebuilds the rest from this repository.
- **Immich's `machine-learning-server-pvc`** — a model cache, refetched on
  demand.

## Known gaps

- The 2 generations kept on the node and the copy pulled by
  `get_backup_folder.sh` are the whole story. There is no offsite copy beyond
  that machine.
- Backups are verified by `verify-restore.sh` only when someone runs it; nothing
  runs it on a schedule yet.
- Every Immich and SonarQube dump taken before 2026-09-15 is 0 bytes: a failing
  `pg_dump` exited 0 and the retention step deleted the previous ones anyway.
  Fixed in commits 661fefa and f5979a1. The host archives of those PVCs from
  that period are correspondingly empty (530 bytes).

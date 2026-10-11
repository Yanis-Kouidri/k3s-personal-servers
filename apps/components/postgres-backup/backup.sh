#!/bin/sh
# Nightly logical dump of one PostgreSQL database into /backups, with retention.
# Shared by the *-db-backup CronJobs (see kustomization.yaml next to this file).
#
# Env:
#   DB_HOST            PostgreSQL service to dump
#   POSTGRES_USER      role used by pg_dump
#   POSTGRES_PASSWORD  its password
#   POSTGRES_DB        database to dump
#   DUMP_PREFIX        dump file name: /backups/<prefix>_db_<date>.<sql|dump>
#   DUMP_FORMAT        plain (psql-restorable .sql, default) or custom (pg_restore .dump)
#   RETENTION_DAYS     dumps older than this are deleted after a successful run (default 7)
set -eu

: "${DB_HOST:?}" "${POSTGRES_USER:?}" "${POSTGRES_PASSWORD:?}" "${POSTGRES_DB:?}" "${DUMP_PREFIX:?}"
DUMP_FORMAT="${DUMP_FORMAT:-plain}"
RETENTION_DAYS="${RETENTION_DAYS:-7}"

case "$DUMP_FORMAT" in
  plain) EXT=sql ;;
  custom) EXT=dump ;;
  *) echo "DUMP_FORMAT must be plain or custom, got '$DUMP_FORMAT'" >&2; exit 1 ;;
esac

BACKUP_FILE="/backups/${DUMP_PREFIX}_db_$(date +%Y-%m-%d_%H-%M-%S).${EXT}"

# A dump that dies midway (DB restarting, disk full) still leaves a truncated file
# behind, which the retention below would happily count as a valid backup. Drop it
# unless the script reaches the end.
trap 'rm -f "$BACKUP_FILE"' EXIT

# k3s programs a new pod's NetworkPolicy rules slightly after the pod gets its IP,
# so the very first connection out of a freshly created backup pod is refused
# ("connection to server at ... failed: Connection refused"). Without this wait the
# first attempt always fails and only the OnFailure restart succeeds.
i=0
until pg_isready -h "$DB_HOST" -U "$POSTGRES_USER" -d "$POSTGRES_DB" -q; do
  i=$((i + 1))
  if [ "$i" -ge 30 ]; then
    echo "PostgreSQL unreachable at $DB_HOST after 60s, giving up" >&2
    exit 1
  fi
  echo "waiting for PostgreSQL at $DB_HOST..."
  sleep 2
done

echo "Starting $DUMP_PREFIX PostgreSQL backup ($DUMP_FORMAT)..."
# --file= rather than a shell redirection: `> file` is opened by the shell *before*
# pg_dump runs, so a failing dump left an empty file behind while the job still
# exited 0.
PGPASSWORD="$POSTGRES_PASSWORD" pg_dump \
  -h "$DB_HOST" \
  -U "$POSTGRES_USER" \
  -d "$POSTGRES_DB" \
  --format="$DUMP_FORMAT" \
  --file="$BACKUP_FILE"

trap - EXIT

# Only reached once the dump above succeeded: with `set -e` a failed pg_dump exits
# here and fails the Job, so the retention can never delete good backups in the
# wake of a broken run.
find /backups -type f -mtime +"$RETENTION_DAYS" -name "*.${EXT}" -delete
echo "Backup completed: $BACKUP_FILE ($(du -h "$BACKUP_FILE" | cut -f1))"

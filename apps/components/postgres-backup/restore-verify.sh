#!/bin/sh
# Weekly proof that the newest dump in /backups can actually be restored. Shared by
# the *-restore-verify CronJobs (see kustomization.yaml next to this file).
#
# A dump nobody has restored is a hypothesis, and the failure mode is silent: the
# job that writes it can succeed while writing nothing usable. This starts a
# throwaway PostgreSQL inside its own container, against the /scratch emptyDir,
# restores the dump into it and checks what came back. It needs no Kubernetes API
# access and no network; the backup volume is mounted read-only. Thresholds rather
# than an exact match against production: the live database keeps moving, while a
# dump that restored to nothing does not reach them by accident.
# scripts/verify-restore.sh does the exact comparison, by hand.
#
# Env:
#   DUMP_FORMAT        plain (*.sql, restored with psql, default) or custom (*.dump, pg_restore)
#   MIN_TABLES         fewest tables in the public schema the restore must produce
#   NONEMPTY_TABLES    space-separated tables that must restore with at least one row
#   RESTORE_ROLES      (optional) roles to create first: a plain dump carries
#                      `ALTER ... OWNER TO <role>` and psql stops on a missing one
#   PRELOAD_LIBRARIES  (optional) shared_preload_libraries of the scratch server
#                      (immich: vchord, or `CREATE EXTENSION vchord` fails mid-dump)
#
# Must run as a non-root user (initdb refuses root) of an image with the server
# binaries and the extensions the dump recreates.
set -eu

: "${MIN_TABLES:?}" "${NONEMPTY_TABLES:?}"
DUMP_FORMAT="${DUMP_FORMAT:-plain}"

case "$DUMP_FORMAT" in
  plain) EXT=sql ;;
  custom) EXT=dump ;;
  *) echo "DUMP_FORMAT must be plain or custom, got '$DUMP_FORMAT'" >&2; exit 1 ;;
esac

# shellcheck disable=SC2012  # dump names are generated, no odd characters
DUMP=$(ls -t /backups/*."$EXT" 2>/dev/null | head -1)
if [ -z "$DUMP" ] || [ ! -s "$DUMP" ]; then
  echo "no usable dump in /backups -- backups are not being produced" >&2
  exit 1
fi
echo "verifying $DUMP ($(du -h "$DUMP" | cut -f1))"

export PGDATA=/scratch/pgdata
initdb -U postgres --auth=trust -D "$PGDATA" >/dev/null
SERVER_OPTS="-k /scratch -c listen_addresses=''"
if [ -n "${PRELOAD_LIBRARIES:-}" ]; then
  SERVER_OPTS="$SERVER_OPTS -c shared_preload_libraries=$PRELOAD_LIBRARIES"
fi
pg_ctl -D "$PGDATA" -o "$SERVER_OPTS" -w start >/dev/null

for role in ${RESTORE_ROLES:-}; do
  createuser -h /scratch -U postgres "$role"
done
createdb -h /scratch -U postgres verify

if [ "$DUMP_FORMAT" = custom ]; then
  pg_restore -h /scratch -U postgres -d verify --exit-on-error \
    --no-owner --no-privileges "$DUMP"
else
  psql -h /scratch -U postgres -d verify -v ON_ERROR_STOP=1 -q -f "$DUMP" >/dev/null
fi

query() { psql -h /scratch -U postgres -d verify -tAc "$1"; }

TABLES=$(query "SELECT count(*) FROM information_schema.tables WHERE table_schema='public';")
echo "restored $TABLES tables"
[ "$TABLES" -ge "$MIN_TABLES" ] || {
  echo "only $TABLES tables, expected at least $MIN_TABLES" >&2; exit 1; }

for table in $NONEMPTY_TABLES; do
  ROWS=$(query "SELECT count(*) FROM $table;")
  echo "  $table: $ROWS rows"
  [ "$ROWS" -gt 0 ] || { echo "$table restored empty" >&2; exit 1; }
done
echo "backup verified"

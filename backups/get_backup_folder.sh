#!/bin/bash
# Pull the VPS backup tree (/home/ubuntu/backups, written by general_pvc_backup.sh)
# to this machine. Runs on the machine that keeps the off-node copy, daily from
# anacron (see backups/README.md). Every setting can be overridden from the
# environment.
set -euo pipefail

# Host alias of the VPS in ~/.ssh/config
VPS_NAME="${VPS_NAME:-ovh-vps}"
# Backup tree on the VPS (trailing slash: copy its content, not the directory)
SOURCE_DIR="${SOURCE_DIR:-/home/ubuntu/backups/}"
DEST_DIR="${DEST_DIR:-$HOME/vps_backups/}"
LOG_FILE="${LOG_FILE:-$HOME/pull_backups.log}"
# Files that --delete removes or that a newer copy replaces are moved to a dated
# folder here instead of being lost, and kept HISTORY_DAYS days: a backup deleted,
# truncated or encrypted on the VPS does not take the good copy with it.
HISTORY_DIR="${HISTORY_DIR:-$HOME/vps_backups_history}"
HISTORY_DAYS="${HISTORY_DAYS:-7}"

log() {
    local now
    now=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$now] $*" >> "$LOG_FILE"
}

if ! [[ $HISTORY_DAYS =~ ^[0-9]+$ ]]; then
    echo "HISTORY_DAYS must be a number of days, got '$HISTORY_DAYS'" >&2
    exit 1
fi

# The archives hold database dumps and private keys: keep them private here too.
umask 077
mkdir -p "$DEST_DIR" "$HISTORY_DIR"

log "--- Starting backup ---"

# --delete mirrors the VPS rotation (2 generations kept there), so DEST_DIR does
# not grow without bound; --backup-dir keeps what it removes or replaces.
if rsync -avz --delete --backup --backup-dir="${HISTORY_DIR%/}/$(date +%F)" \
    -e ssh "$VPS_NAME:$SOURCE_DIR" "$DEST_DIR" >> "$LOG_FILE" 2>&1; then
    log "SUCCESS: backup folder saved locally."
else
    log "ERROR: rsync from $VPS_NAME failed."
    exit 1
fi

# Drop the history folders older than HISTORY_DAYS. Folders are matched on their
# YYYY-MM-DD name (not their mtime, which rsync may change), so nothing else in
# HISTORY_DIR is ever removed.
cutoff=$(date -d "-${HISTORY_DAYS} days" +%F)
for dir in "${HISTORY_DIR:?}"/[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]; do
    [[ -d $dir ]] || continue
    if [[ $(basename "$dir") < "$cutoff" ]]; then
        log "Removing history older than ${HISTORY_DAYS} days: $dir"
        rm -rf -- "$dir"
    fi
done

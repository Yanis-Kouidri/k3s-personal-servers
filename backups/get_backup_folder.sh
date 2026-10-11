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

log() {
    local now
    now=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$now] $*" >> "$LOG_FILE"
}

mkdir -p "$DEST_DIR"

log "--- Starting backup ---"

# --delete mirrors the VPS rotation (2 generations kept there), so this copy does
# not grow without bound.
if rsync -avz --delete -e ssh "$VPS_NAME:$SOURCE_DIR" "$DEST_DIR" >> "$LOG_FILE" 2>&1; then
    log "SUCCESS: backup folder saved locally."
else
    log "ERROR: rsync from $VPS_NAME failed."
    exit 1
fi

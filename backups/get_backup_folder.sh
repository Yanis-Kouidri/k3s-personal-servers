#!/bin/bash
set -euo pipefail

# Local
USER_HOME="/home/yanis"
LOG_FILE="$USER_HOME/pull_backups.log"
VPS_NAME="ovh-vps" # Le nom défini dans ton .ssh/config
DEST_DIR="$USER_HOME/vps_backups/"

# On VPS server
SOURCE_DIR="/home/ubuntu/backups/"


log() {
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] $*"
    echo "$msg" >> "$LOG_FILE"
}

mkdir -p "$DEST_DIR"

log "--- Starting backup ---"

if rsync -avz --delete -e ssh $VPS_NAME:$SOURCE_DIR $DEST_DIR >> $LOG_FILE 2>&1; then
    log "SUCCESS : Backup folder saved localy."
else
    log "ERROR : failed to copy with rsync."
    exit 1
fi
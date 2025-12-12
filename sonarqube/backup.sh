#!/bin/bash

# Stop on errors, unset variables, and fail on pipe errors
set -euo pipefail

# Config:
NAMESPACE="sonarqube"
PVC="backup-sonarqube-pvc" # PVC to back up
SUB_PATH=""   # Sub-path within the volume to back up
BACKUP_PATH=/home/ubuntu/backups/$NAMESPACE/database/
BACKUP_NAME=sonarqube-postgres-$(date +%Y-%m-%d-%H%M).tar.zst
BACKUP_FILE=$BACKUP_PATH$BACKUP_NAME

# Colors for nice output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Log function with timestamp
log() {
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

export KUBECONFIG="${KUBECONFIG:-/home/ubuntu/.kube/config}"

mkdir -p "$BACKUP_PATH"

log "${YELLOW}=== Sonarqube database Backup Started ===${NC}"

VOLUME_NAME=$(kubectl get pvc $PVC -n $NAMESPACE -ojsonpath='{.spec.volumeName}')
log "Volume name: $VOLUME_NAME"

VOLUME_PATH=$(kubectl get pv $VOLUME_NAME -n $NAMESPACE -ojsonpath='{.spec.local.path}')
log "Volume path: $VOLUME_PATH"


PATH_TO_BACKUP="$VOLUME_PATH/$SUB_PATH"
log "Folder to back up: $PATH_TO_BACKUP"

log "Backup file will be: $BACKUP_FILE"

sudo tar --use-compress-program=zstd --acls -cpvf $BACKUP_FILE -C $PATH_TO_BACKUP .

# Remove backups older than the 2 most recent ones
ls -t $BACKUP_PATH*.tar.zst | tail -n +3 | xargs -I {} rm -v {} || log "No old backups to delete."

BACKUP_SIZE=$(du -h "$BACKUP_FILE" | cut -f1)
log "${GREEN}=== Backup completed successfully! ===${NC}"
log "${GREEN}Backup file: $BACKUP_FILE (Size: $BACKUP_SIZE)${NC}"
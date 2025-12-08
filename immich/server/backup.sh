#!/bin/bash

# Stop on errors, unset variables, and fail on pipe errors
set -euo pipefail

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
NAMESPACE="immich"

log "${YELLOW}=== Immich Library Backup Started ===${NC}"

VOLUME=$(kubectl get pvc server-immich-pvc -n $NAMESPACE -ojsonpath='{.spec.volumeName}')
log "Volume name: $VOLUME"

IMMICH_PATH=$(kubectl get pv $VOLUME -n $NAMESPACE -ojsonpath='{.spec.local.path}')
log "IMMICH_PATH: $IMMICH_PATH"

LIBRARY_PATH="$IMMICH_PATH/library"
log "LIBRARY_PATH: $LIBRARY_PATH"


BACKUP_PATH=/home/ubuntu/backups/immich/
BACKUP_NAME=immich-library-$(date +%Y-%m-%d-%H%M).tar.zst
BACKUP_FILE=$BACKUP_PATH$BACKUP_NAME
log "Backup file will be: $BACKUP_FILE"

sudo tar --use-compress-program=zstd --acls -cpvf $BACKUP_FILE -C $LIBRARY_PATH .

# Remove backups older than the 2 most recent ones
ls -t $BACKUP_PATH*.tar.zst | tail -n +3 | xargs -I {} rm -v {} || log "No old backups to delete."

BACKUP_SIZE=$(du -h "$BACKUP_FILE" | cut -f1)
log "${GREEN}=== Backup completed successfully! ===${NC}"
log "${GREEN}Backup file: $BACKUP_FILE (Size: $BACKUP_SIZE)${NC}"
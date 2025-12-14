#!/bin/bash

# This script performs a backup of a specified Kubernetes Persistent Volume Claim (PVC) into /home/ubuntu/backups/

# Configuration: Stop on errors, unset variables, and fail on pipe errors
set -euo pipefail

# --- Default Variables ---
NAMESPACE=""
PVC=""
SUB_PATH="" # Default empty (volume root)
NAME=""
KUBECONFIG="${KUBECONFIG:-/home/ubuntu/.kube/config}"

# --- Colors ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# --- Functions ---

log() {
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

usage() {
    echo -e "${YELLOW}Usage: $0 -n <namespace> -p <pvc_name> -N <backup_name> [-s <sub_path>]${NC}"
    echo -e "  -n  Kubernetes Namespace (e.g., portfolio)"
    echo -e "  -p  PVC name to backup (e.g., mongodb-backup-pvc)"
    echo -e "  -N  Backup name (e.g., mongodb)"
    echo -e "  -s  (Optional) Sub-directory within the volume"
    echo -e "Example: ${YELLOW}$0 -n wireguard -N wireguard -p wireguard-pvc${NC}"
    echo -e "This script works well in cron jobs for automated backups."
    exit 1
}

# --- Argument Parsing ---

while getopts "n:p:N:s:h" opt; do
  case $opt in
    n) NAMESPACE="$OPTARG" ;;
    p) PVC="$OPTARG" ;;
    N) NAME="$OPTARG" ;;
    s) SUB_PATH="$OPTARG" ;;
    h) usage ;;
    *) usage ;;
  esac
done

# Check mandatory arguments
if [[ -z "$NAMESPACE" || -z "$PVC" || -z "$NAME" ]]; then
    echo -e "${RED}Error: Arguments -n, -p, and -N are mandatory.${NC}"
    usage
fi

# --- Derived Configuration ---
BACKUP_PATH="/home/ubuntu/backups/$NAMESPACE/$NAME/"
BACKUP_FILENAME="$NAME-$(date +%Y-%m-%d-%H%M).tar.zst"
BACKUP_FILE="${BACKUP_PATH}${BACKUP_FILENAME}"

export KUBECONFIG

# --- Execution ---

mkdir -p "$BACKUP_PATH"

log "${YELLOW}=== Backup started: $NAME ($NAMESPACE) ===${NC}"

# Retrieve actual volume name
if ! VOLUME_NAME=$(kubectl get pvc "$PVC" -n "$NAMESPACE" -ojsonpath='{.spec.volumeName}'); then
    log "${RED}Error: Unable to find PVC '$PVC' in namespace '$NAMESPACE'.${NC}"
    exit 1
fi
log "Volume name: $VOLUME_NAME"

# Retrieve local path on the node (Note: pod must be on the same node as this script)
VOLUME_PATH=$(kubectl get pv "$VOLUME_NAME" -ojsonpath='{.spec.local.path}')
log "Volume path: $VOLUME_PATH"

# Build source path
# Remove trailing slash from VOLUME_PATH and leading slash from SUB_PATH to avoid double //
clean_vol_path="${VOLUME_PATH%/}"
clean_sub_path="${SUB_PATH#/}"

if [[ -z "$clean_sub_path" ]]; then
    PATH_TO_BACKUP="$clean_vol_path"
else
    PATH_TO_BACKUP="$clean_vol_path/$clean_sub_path"
fi

log "Folder to back up: $PATH_TO_BACKUP"
log "Backup file will be: $BACKUP_FILE"

# Verify source directory exists before running tar
# Using 'sudo' to check existence as volumes are often owned by root
if ! sudo test -d "$PATH_TO_BACKUP"; then
    log "${RED}Error: Source directory '$PATH_TO_BACKUP' does not exist or is inaccessible.${NC}"
    exit 1
fi

# Create archive
# Using 'sudo' because PV volumes often belong to root
sudo tar --use-compress-program=zstd --acls -cpvf "$BACKUP_FILE" -C "$PATH_TO_BACKUP" .

# Backup rotation: Keep the 2 most recent files
# Note: using 'ls' carefully. If no files exist, we don't want the script to fail (set -e).
log "Cleaning up old backups..."
count=$(ls -1 "$BACKUP_PATH"*.tar.zst 2>/dev/null | wc -l)

if [ "$count" -gt 2 ]; then
    # Using sudo rm because files created by sudo tar likely belong to root
    ls -t "$BACKUP_PATH"*.tar.zst | tail -n +3 | xargs -I {} sudo rm -v {}
else
    log "Fewer than 3 backups exist, skipping deletion."
fi

# Final Report
if [ -f "$BACKUP_FILE" ]; then
    BACKUP_SIZE=$(du -h "$BACKUP_FILE" | cut -f1)
    log "${GREEN}=== Backup completed successfully! ===${NC}"
    log "${GREEN}Backup file: $BACKUP_FILE (Size: $BACKUP_SIZE)${NC}"
else
    log "${RED}Error: Backup file was not created.${NC}"
    exit 1
fi
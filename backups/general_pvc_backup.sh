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
MC_DEPLOYMENT="" # (optional) Minecraft deployment name for RCON save-off/save-on
MC_SAVE_OFF_DONE=false # tracks whether save-off was issued, so cleanup knows to re-enable it
STOP_WORKLOAD="" # (optional) <kind>/<name> scaled to 0 for the duration of the archive
STOP_REPLICAS="" # replica count to restore; set once the workload has been scaled down
STOP_SELECTOR="" # label selector of the stopped workload's pods

# --- Colors ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# --- Functions ---

log() {
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

# Runs an RCON command inside the Minecraft deployment's pod via rcon-cli
mc_rcon() {
    local cmd="$1"
    log "Minecraft RCON: $cmd"
    if ! kubectl exec -n "$NAMESPACE" "deployment/$MC_DEPLOYMENT" -- rcon-cli "$cmd"; then
        log "${RED}Error: RCON command '$cmd' failed on deployment '$MC_DEPLOYMENT' ($NAMESPACE).${NC}"
        return 1
    fi
}

# Label selector ("k=v,k=v") matching the pods of $STOP_WORKLOAD
workload_selector() {
    kubectl get -n "$NAMESPACE" "$STOP_WORKLOAD" -o json \
        | jq -r '.spec.selector.matchLabels // {} | to_entries | map("\(.key)=\(.value)") | join(",")'
}

# Fails if any pod of the stopped workload exists. Flux reconciles every 10 min
# and puts `replicas` back to what git says; a pod started while tar reads the
# volume would make the archive inconsistent, so it must not be kept.
assert_workload_stopped() {
    local pods
    pods=$(kubectl get pods -n "$NAMESPACE" -l "$STOP_SELECTOR" -o name)
    if [[ -n "$pods" ]]; then
        log "${RED}Error: '$STOP_WORKLOAD' came back while it should be stopped (Flux reconcile?): $pods${NC}"
        return 1
    fi
}

stop_workload() {
    STOP_SELECTOR=$(workload_selector)
    if [[ -z "$STOP_SELECTOR" ]]; then
        log "${RED}Error: unable to read the pod selector of '$STOP_WORKLOAD' ($NAMESPACE).${NC}"
        return 1
    fi
    STOP_REPLICAS=$(kubectl get -n "$NAMESPACE" "$STOP_WORKLOAD" -o jsonpath='{.spec.replicas}')
    log "Stopping $STOP_WORKLOAD (was $STOP_REPLICAS replica(s))..."
    kubectl scale -n "$NAMESPACE" "$STOP_WORKLOAD" --replicas=0
    # Waits for the pods to be gone, not just for the scale to be accepted: the
    # application only flushes and closes its files on SIGTERM, within its
    # terminationGracePeriodSeconds.
    kubectl wait --for=delete pod -n "$NAMESPACE" -l "$STOP_SELECTOR" --timeout=180s
    assert_workload_stopped
}

start_workload() {
    log "Starting $STOP_WORKLOAD again ($STOP_REPLICAS replica(s))..."
    kubectl scale -n "$NAMESPACE" "$STOP_WORKLOAD" --replicas="$STOP_REPLICAS"
    STOP_REPLICAS=""
    if ! kubectl rollout status -n "$NAMESPACE" "$STOP_WORKLOAD" --timeout=300s; then
        log "${RED}Error: '$STOP_WORKLOAD' did not become ready again. Check it manually!${NC}"
        return 1
    fi
}

usage() {
    echo -e "${YELLOW}Usage: $0 -n <namespace> -p <pvc_name> -N <backup_name> [-s <sub_path>]${NC}"
    echo -e "  -n  Kubernetes Namespace (e.g., personal-website-v2)"
    echo -e "  -p  PVC name to backup (e.g., mongodb-backup-pvc)"
    echo -e "  -N  Backup name (e.g., mongodb)"
    echo -e "  -s  (Optional) Sub-directory within the volume"
    echo -e "  -m  (Optional) Minecraft deployment name (e.g., minecraft-server)."
    echo -e "      When set, runs 'save-off' + 'save-all flush' via RCON before the"
    echo -e "      archive, and 'save-on' after (also on error, via cleanup trap)."
    echo -e "  -S  (Optional) Workload to stop during the archive, as <kind>/<name>"
    echo -e "      (e.g., statefulset/stalwart). Scaled to 0 before, back to its replica"
    echo -e "      count after (also on error, via cleanup trap). For stores that are only"
    echo -e "      consistent on disk once the application has shut down (RocksDB, ...)."
    echo -e "Example: ${YELLOW}$0 -n wireguard -N wireguard -p wireguard-pvc${NC}"
    echo -e "Example (Minecraft): ${YELLOW}$0 -n minecraft -N minecraft -p minecraft-pvc -m minecraft-server${NC}"
    echo -e "Example (stopped):   ${YELLOW}$0 -n mail -N stalwart -p stalwart-data -S statefulset/stalwart${NC}"
    echo -e "This script works well in cron jobs for automated backups."
    exit 1
}

# --- Argument Parsing ---

while getopts "n:p:N:s:m:S:h" opt; do
  case $opt in
    n) NAMESPACE="$OPTARG" ;;
    p) PVC="$OPTARG" ;;
    N) NAME="$OPTARG" ;;
    s) SUB_PATH="$OPTARG" ;;
    m) MC_DEPLOYMENT="$OPTARG" ;;
    S) STOP_WORKLOAD="$OPTARG" ;;
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
LOCK_FILE="/tmp/backup-${NAMESPACE}-${NAME}.lock"

export KUBECONFIG

# --- Anti-concurrency lock (point 1) ---
exec 200>"$LOCK_FILE"
if ! flock -n 200; then
    log "${RED}Error: A backup for '$NAME' ($NAMESPACE) is already running. Aborting.${NC}"
    exit 1
fi

# Cleanup: release the lock fd and remove the lock file on any exit
# (success, error via set -e, or signal like SIGINT/SIGTERM)
cleanup() {
    # Safety net: if we disabled Minecraft autosave and never got to re-enable it
    # (e.g. the script errored out mid-backup), make sure save-on is issued anyway.
    if [[ "$MC_SAVE_OFF_DONE" == true ]]; then
        mc_rcon "save-on" || log "${RED}Warning: failed to re-enable autosave via cleanup trap. Check manually!${NC}"
    fi
    # Same safety net for a stopped workload: never leave it scaled to 0.
    if [[ -n "$STOP_REPLICAS" ]]; then
        start_workload || log "${RED}Warning: failed to restart '$STOP_WORKLOAD' via cleanup trap. Check manually!${NC}"
    fi
    exec 200>&-
    rm -f "$LOCK_FILE"
}
trap cleanup EXIT

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
if ! VOLUME_PATH=$(kubectl get pv "$VOLUME_NAME" -ojsonpath='{.spec.local.path}'); then
    log "${RED}Error: Unable to retrieve PV '$VOLUME_NAME' details.${NC}"
    exit 1
fi

if [[ -z "$VOLUME_PATH" ]]; then
    log "${RED}Error: '.spec.local.path' is empty for PV '$VOLUME_NAME'.${NC}"
    exit 1
fi
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

# If a Minecraft deployment was given, freeze world writes for the duration of the
# archive: disable autosave, force a clean flush to disk, then wait a couple seconds
# to let any in-flight I/O settle before tar starts reading files.
if [[ -n "$MC_DEPLOYMENT" ]]; then
    mc_rcon "save-off"
    mc_rcon "save-all flush"
    MC_SAVE_OFF_DONE=true
    sleep 2
fi

if [[ -n "$STOP_WORKLOAD" ]]; then
    stop_workload
fi

# Create archive
# --numeric-owner (point 2): preserve UID/GID as numbers, safe for cross-host restore
# --checkpoint (point 5): lightweight progress instead of full file listing (-v)
sudo tar --use-compress-program=zstd --acls --numeric-owner \
    --checkpoint=1000 --checkpoint-action=echo="Archived %u files..." \
    -cpf "$BACKUP_FILE" -C "$PATH_TO_BACKUP" .

# Re-enable autosave as soon as the copy is done; no need to keep the world frozen
# during the integrity check / rotation steps below.
if [[ -n "$MC_DEPLOYMENT" ]]; then
    mc_rcon "save-on"
    MC_SAVE_OFF_DONE=false
fi

# Restart as soon as the copy is done, after checking nothing reopened the
# volume while tar was reading it.
if [[ -n "$STOP_WORKLOAD" ]]; then
    if ! assert_workload_stopped; then
        sudo rm -f "$BACKUP_FILE"
        exit 1
    fi
    start_workload
fi

# Integrity check (point 3): make sure the archive isn't corrupted before trusting it
log "Verifying archive integrity..."
if ! sudo tar --use-compress-program=zstd -tf "$BACKUP_FILE" > /dev/null; then
    log "${RED}Error: Archive '$BACKUP_FILE' appears corrupted. Removing it.${NC}"
    sudo rm -f "$BACKUP_FILE"
    exit 1
fi
log "Archive integrity OK."

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
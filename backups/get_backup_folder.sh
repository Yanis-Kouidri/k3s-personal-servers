#!/bin/bash
set -euo pipefail

log() {
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}


# Configuration
HOME=/home/yanis
SSH_CONFIG="$HOME/.ssh/config"                     # Chemin absolu vers le fichier SSH config
VPS_NAME="ovh-vps"                                # Défini dans .ssh/config
SOURCE_DIR="/home/ubuntu/backups/"               # Dossier source sur le VPS
DEST_DIR="$HOME/vps_backups"                      # Dossier de destination sur ton PC

# Copie depuis le VPS vers ton PC avec rsync
log "Début de la copie du backup depuis le VPS..."
/usr/bin/rsync -avz --delete -e "ssh -F $SSH_CONFIG" "$VPS_NAME:$SOURCE_DIR" "$DEST_DIR"
log "Backup copié avec succès depuis le VPS."
#!/bin/bash
set -euo pipefail

# Configuration
VPS_NAME="ovh-vps"                                # Define in .ssh/config
SOURCE_DIR="/home/ubuntu/backups/"    # Dossier source sur le VPS
DEST_DIR="$HOME/vps_backups" # Dossier de destination sur ton PC

# Copie depuis le VPS vers ton PC avec rsync
echo "Début de la copie du backup depuis le VPS..."
rsync -avz --delete $VPS_NAME:$SOURCE_DIR $DEST_DIR


echo "Backup copié avec succès depuis le VPS."

#!/bin/bash
#
# Backup script for all container volumes and configurations
# Usage: ./backup.sh [backup-name]
#

set -e

BACKUP_DIR="/var/backups/selfhosting"
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_NAME="${1:-backup_${DATE}}"
BACKUP_PATH="${BACKUP_DIR}/${BACKUP_NAME}"

echo "=================================================="
echo "VPS Infrastructure Backup"
echo "=================================================="
echo ""
echo "Backup location: ${BACKUP_PATH}"
echo ""

# Create backup directory
mkdir -p "${BACKUP_PATH}"

# Backup all volumes
echo "Backing up container volumes..."
for volume in joplin joplin-db miniflux-db qbittorrent-config qbittorrent-downloads \
              jellyfin-config jellyfin-cache nextcloud nextcloud-db n8n; do
    VOLUME_PATH="/var/lib/containers/storage/volumes/${volume}"
    if [ -d "${VOLUME_PATH}" ]; then
        echo "  - Backing up ${volume}..."
        tar -czf "${BACKUP_PATH}/${volume}.tar.gz" -C "${VOLUME_PATH}" .
    else
        echo "  - WARNING: Volume ${volume} not found, skipping"
    fi
done

# Backup Nginx configurations
echo "Backing up Nginx configurations..."
if [ -d "/etc/nginx" ]; then
    tar -czf "${BACKUP_PATH}/nginx.tar.gz" -C /etc/nginx .
fi

# Backup SSL certificates
echo "Backing up SSL certificates..."
if [ -d "/etc/letsencrypt" ]; then
    tar -czf "${BACKUP_PATH}/letsencrypt.tar.gz" -C /etc/letsencrypt .
fi

# Backup Quadlet files
echo "Backing up Quadlet files..."
if [ -d "/etc/containers/systemd" ]; then
    tar -czf "${BACKUP_PATH}/quadlets.tar.gz" -C /etc/containers/systemd .
fi

# Create backup manifest
echo "Creating backup manifest..."
cat > "${BACKUP_PATH}/manifest.txt" <<EOF
Backup created: ${DATE}
Hostname: $(hostname)
Kernel: $(uname -r)

Included volumes:
$(ls -lh ${BACKUP_PATH}/*.tar.gz)

To restore:
1. Stop all services: systemctl stop *.service
2. Extract archives to appropriate locations
3. Restart services: systemctl start *.service
EOF

# Calculate total backup size
TOTAL_SIZE=$(du -sh "${BACKUP_PATH}" | cut -f1)
echo ""
echo "=================================================="
echo "Backup complete!"
echo "=================================================="
echo "Location: ${BACKUP_PATH}"
echo "Total size: ${TOTAL_SIZE}"
echo ""
echo "To restore this backup:"
echo "  1. Copy backup to server"
echo "  2. Extract each tar.gz to its original location"
echo "  3. Restart services"
echo ""

# Cleanup old backups (keep last 7 days)
echo "Cleaning up old backups (keeping last 7 days)..."
find "${BACKUP_DIR}" -type d -name "backup_*" -mtime +7 -exec rm -rf {} + 2>/dev/null || true

echo "Done!"

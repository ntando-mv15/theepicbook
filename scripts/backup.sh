#!/bin/bash
# =============================================================
# EpicBook — Database Backup Script
# =============================================================

CONTAINER_NAME="theepicbook-db-1"
DATABASE_NAME="bookstore"
BACKUP_DIR="../backups"
RETAIN_DAYS=7
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="${BACKUP_DIR}/bookstore_${DATE}.sql"

# Create backup directory if it doesn't exist
mkdir -p "$BACKUP_DIR"

# Run the dump
docker exec "$CONTAINER_NAME" \
  mysqldump -u root -padminTechuserpass! "$DATABASE_NAME" \
  > "$BACKUP_FILE"

if [ $? -eq 0 ]; then
  gzip "$BACKUP_FILE"
  echo "[$DATE] Backup successful: ${BACKUP_FILE}.gz ($(du -h ${BACKUP_FILE}.gz | cut -f1))"
else
  echo "[$DATE] Backup FAILED!"
  rm -f "$BACKUP_FILE"
  exit 1
fi

# Clean up old backups
find "$BACKUP_DIR" -name "bookstore_*.sql.gz" -mtime "+$RETAIN_DAYS" -delete
echo "[$DATE] Old backups cleaned (kept last $RETAIN_DAYS days)"
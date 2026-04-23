# 05 — Persistence & Backup

## Data persistence strategy

### What needs to persist

| Data | Location in container | Persistence method | Why |
|---|---|---|---|
| MySQL data files | `/var/lib/mysql` | Named volume `db_data` | All database state. Lose this, lose everything |
| DB init scripts | `/docker-entrypoint-initdb.d` | Bind mount `./db` (read-only) | Schema and seed data loaded on first boot |
| Nginx logs | `/var/log/nginx` | Bind mount `./logs/nginx` | Must survive container removal and be accessible on host |

### Why no app_data volume

The app has no user upload functionality. All assets (book cover images, CSS, JS) are static files bundled into the Docker image at build time. 



### Critical distinction

```bash
docker compose down      # destroys containers — volumes survive ✅
docker compose down -v   # destroys containers AND volumes ❌ data lost
```

Never run `down -v` in production unless intentionally wiping the database.

## Backup strategy

### What to snapshot

SQL dump via `mysqldump` — chosen over volume snapshot because:
- Portable — restores to any MySQL 5.7 instance
- Human-readable — can inspect the SQL file directly
- Selective — can restore a single table if needed
- Volume snapshots are tied to MySQL version and storage engine

### When to run

Daily at 2am via cron job on the VM. The app is a bookstore with low write frequency — daily is sufficient. A pre-deployment backup is also recommended before any stack update.

### Where to store

| Tier | Location | Retention | Purpose |
|---|---|---|---|
| Local | `/home/azureuser/theepicbook/backups/ ` in Azure VM | 7 days | Fast restore |


## Backup script

Location: `scripts/backup.sh`

```bash
#!/bin/bash
set -euo pipefail

if [ -f ../.env ]; then
  export $(grep -v '^#' ../.env | xargs)
else
  echo "ERROR: .env file not found."
  exit 1
fi

CONTAINER_NAME="theepicbook-db-1"
DATABASE_NAME="bookstore"
BACKUP_DIR="../backups"
RETAIN_DAYS=7
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="${BACKUP_DIR}/bookstore_${DATE}.sql"

mkdir -p "$BACKUP_DIR"

docker exec "$CONTAINER_NAME" \
  mysqldump -u root -p"${MYSQL_ROOT_PASSWORD}" "$DATABASE_NAME" \
  > "$BACKUP_FILE"

if [ $? -eq 0 ]; then
  gzip "$BACKUP_FILE"
  echo "[$DATE] Backup successful: ${BACKUP_FILE}.gz"
else
  echo "[$DATE] Backup FAILED!"
  rm -f "$BACKUP_FILE"
  exit 1
fi

find "$BACKUP_DIR" -name "bookstore_*.sql.gz" -mtime "+$RETAIN_DAYS" -delete
echo "[$DATE] Old backups cleaned (kept last $RETAIN_DAYS days)"
```

## Restore procedure

```bash
# Decompress and restore in one command — no uncompressed file written to disk
gunzip -c backups/bookstore_TIMESTAMP.sql.gz | \
  docker exec -i theepicbook-db-1 \
  mysql -u root -p${MYSQL_ROOT_PASSWORD} bookstore

# Restart the app so Sequelize reconnects cleanly
docker compose restart app
```

## Cron job (on VM)

```bash
# Daily at 2am
0 2 * * * /home/azureuser/theepicbook/scripts/backup.sh >> /home/azureuser/theepicbook/logs/backup.log 2>&1
```

## Manual test results

Tested locally and on remote server:
1. Stack running with seeded data visible in browser
2. Backup script run — `.sql.gz` file created successfully
3. Database dropped: `DROP DATABASE bookstore; CREATE DATABASE bookstore;`
4. App confirmed broken — no data visible
5. Restore script run — data returned
6. App restarted — all books and authors visible again

Persistence test:
1. `docker compose down` run
2. `docker compose up` run
3. All data present — named volume survived container removal
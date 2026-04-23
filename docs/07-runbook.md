# 07 — Operations Runbook

## Overview

This runbook covers day-to-day operations for The EpicBook stack running on an Azure VM with Docker Compose.

**Stack location on VM:** `/home/azureuser/theepicbook`
**Services:** proxy (Nginx), app (Node.js), db (MySQL 5.7)

---

## 1. Start / Stop / Restart the stack

### Start the full stack
```bash
cd /home/azureuser/theepicbook
docker compose up -d
```
The `-d` flag runs the stack in the background (detached mode).

### Stop the full stack (preserves data)
```bash
docker compose down
```
Containers are removed. Named volumes (`db_data`) are preserved. Data is safe.

### Stop the full stack and wipe all data
```bash
docker compose down -v
```
⚠️ **Destructive.** Removes containers AND named volumes. All database data is permanently deleted. Only run this intentionally.

### Restart a single service
```bash
docker compose restart app      # restart Node.js app only
docker compose restart proxy    # restart Nginx only
docker compose restart db       # restart MySQL only
```

### Check service status
```bash
docker compose ps
```
All three services should show `(healthy)`.

---

## 2. Viewing logs

### Nginx access log (JSON — every HTTP request)
```bash
tail -f /home/azureuser/theepicbook/logs/nginx/access.log
```

### Nginx error log
```bash
tail -f /home/azureuser/theepicbook/logs/nginx/error.log
```

### App logs (Node.js stdout)
```bash
docker logs theepicbook-app-1
docker logs -f theepicbook-app-1          # follow in real time
docker logs --tail 50 theepicbook-app-1   # last 50 lines
```

### DB logs (MySQL)
```bash
docker logs theepicbook-db-1
```

### Backup audit log
```bash
cat /home/azureuser/theepicbook/logs/backup.log
```

---

## 3. Deploying an update

```bash
cd /home/azureuser/theepicbook

# Pull latest code
git pull origin main

# Rebuild the app image and restart
docker compose up -d --build
```

`--build` forces Docker to rebuild the app image from the updated code. The `db` and `proxy` containers are not rebuilt unless their config changed.

---

## 4. Rollback procedure

If a deployment breaks the app, roll back to the previous working image:

```bash
# Check what images are available
docker images | grep theepicbook

# Roll back by specifying the previous image tag
# (if you have tagged images — e.g. from CI/CD)
docker compose down
# Edit docker-compose.yml to pin the previous image tag
docker compose up -d

# If no previous tag is available, revert the code and rebuild
git revert HEAD
docker compose up -d --build
```

### Pre-deployment checklist
Before every deployment:
1. Run a manual backup: `./scripts/backup.sh backup`
2. Confirm current stack is healthy: `docker compose ps`
3. Note the current git commit: `git log --oneline -1`

---

## 5. Rotating secrets

When rotating database passwords or any secret:

```bash
# 1. Take a backup before making any changes
./scripts/backup.sh backup

# 2. Stop the stack
docker compose down

# 3. Update .env with new credentials
nano /home/azureuser/theepicbook/.env

# 4. Destroy the db volume so MySQL reinitialises with new credentials
docker volume rm theepicbook_db_data

# 5. Start the stack — MySQL creates fresh user with new password
docker compose up -d

# 6. Restore data from the backup taken in step 1
gunzip -c backups/bookstore_TIMESTAMP.sql.gz | \
  docker exec -i theepicbook-db-1 \
  mysql -u root -p${MYSQL_ROOT_PASSWORD} bookstore

# 7. Verify the app is healthy
curl http://localhost/health
```

⚠️ Step 4 destroys the volume and all data in it. Always backup first.

---

## 6. Backup and restore

### Run a manual backup
```bash
cd /home/azureuser/theepicbook
./scripts/backup.sh backup
```

### List available backups
```bash
./scripts/backup.sh list
```

### Restore from a backup
```bash
gunzip -c backups/bookstore_TIMESTAMP.sql.gz | \
  docker exec -i theepicbook-db-1 \
  mysql -u root -p${MYSQL_ROOT_PASSWORD} bookstore

docker compose restart app
```

### Cron schedule
Backups run daily at 2am automatically:
```bash
crontab -l
# 0 2 * * * /home/azureuser/theepicbook/scripts/backup.sh >> ...
```

---

## 7. Common errors and fixes

### App shows blank page or 502 Bad Gateway

**Cause:** App container is not running or is unhealthy.

```bash
docker compose ps
docker logs theepicbook-app-1
```

If the app crashed due to a DB connection error, restart it:
```bash
docker compose restart app
```

---

### `/health` returns `{"status":"error","db":"unreachable"}`

**Cause:** DB container is down or unhealthy.

```bash
docker compose ps
docker logs theepicbook-db-1
docker compose restart db
```

Wait 30 seconds for MySQL to initialise, then check:
```bash
curl http://localhost/health
```

---

### `docker compose up` fails with permission denied

**Cause:** `azureuser` is not in the `docker` group, or group membership hasn't taken effect.

```bash
# Check group membership
groups azureuser

# If docker is not listed, add it
sudo usermod -aG docker azureuser

# Log out and back in, then retry
exit
ssh azureuser@YOUR_VM_IP
docker compose up -d
```

---

### Nginx shows default page instead of the app

**Cause:** `nginx.conf` bind mount is not being picked up.

```bash
# Verify the config is loaded
docker exec theepicbook-proxy-1 nginx -T | grep proxy_pass

# If not present, check the volume mount in docker-compose.yml
# Then restart the proxy
docker compose restart proxy
```

---

### Backup script fails with "Container not running"

**Cause:** Stack is not up, or container name has changed.

```bash
# Check the actual container name
docker compose ps

# Update CONTAINER_NAME in scripts/backup.sh if it changed
```

---

### Disk space filling up

**Cause:** Log files or backups accumulating.

```bash
# Check disk usage
df -h

# Check what's taking space
du -sh /home/azureuser/theepicbook/*

# Manually clean old backups (script does this automatically for >7 days)
find backups/ -name "*.sql.gz" -mtime +7 -delete

# Truncate Nginx access log if very large
> logs/nginx/access.log
```

---

## 8. Health check reference

| Endpoint | Expected response | What it confirms |
|---|---|---|
| `GET /health` | `200 {"status":"ok","db":"reachable"}` | App up, DB connected |
| `GET /` | `200` HTML page | Full stack working |
| `docker compose ps` | All `(healthy)` | All containers healthy |
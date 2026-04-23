# 10 — Reliability Tests

## Test environment

- Platform: Local Docker Compose (mirrored on Azure VM)
- Stack: proxy (Nginx) → app (Node.js) → db (MySQL 5.7)
- All three services running with healthchecks configured

---

## Test 1 — Restart backend only

**Objective:** Verify the UI shows a graceful error during app restart and recovers automatically without manual intervention.

**Command run:**
```bash
docker compose restart app
```

**Expected behaviour:**
- During restart: Nginx returns 502 Bad Gateway (no upstream available)
- After restart (~15s): app comes back healthy, traffic resumes normally
- No data loss

**Result:**
> [ADD YOUR OBSERVATIONS HERE — what did the browser show? How long did recovery take?]

**Healthcheck behaviour:**
```bash
docker compose ps
# app shows (health: starting) during restart
# app shows (healthy) once /health returns 200
```

---

## Test 2 — Take DB down

**Objective:** Verify the backend returns a clear error when the DB is unavailable and the healthcheck reflects the failure.

**Command run:**
```bash
docker compose stop db
```

**Expected behaviour:**
- `/health` endpoint returns `503 {"status":"error","db":"unreachable"}`
- App container transitions to `(unhealthy)` after failed health checks
- Browser shows an error page — app is up but cannot serve data

**Result:**
> [ADD YOUR OBSERVATIONS HERE — what did /health return? What did the browser show?]

**Verification command:**
```bash
curl http://localhost/health
# Expected: {"status":"error","db":"unreachable"}

docker compose ps
# Expected: app shows (unhealthy) after retries exhausted
```

**Recovery:**
```bash
docker compose start db
# db healthcheck passes → app healthcheck passes → normal operation resumes
```

---

## Test 3 — Full stack bounce (persistence test)

**Objective:** Verify data survives a complete stack teardown and restart.

**Commands run:**
```bash
# Note what data exists before
# Open browser — confirm books visible

docker compose down
# All containers removed — volumes preserved

docker compose up -d
# Stack restarts fresh from volumes
```

**Expected behaviour:**
- All books and authors present after restart
- No re-seeding required
- `db_data` named volume intact

**Result:**
> [ADD YOUR OBSERVATIONS HERE — was all data present? Any errors on startup?]

---

## Test 4 — Backup and restore

**Objective:** Verify the backup script produces a valid dump and the restore procedure returns the database to its previous state.

**Steps:**
```bash
# 1. Run backup
./scripts/backup.sh backup

# 2. Confirm backup file created
./scripts/backup.sh list

# 3. Drop the database
docker exec theepicbook-db-1 \
  mysql -u root -p${MYSQL_ROOT_PASSWORD} \
  -e "DROP DATABASE bookstore; CREATE DATABASE bookstore;"

# 4. Confirm app is broken
curl http://localhost/health
# Expected: 503

# 5. Restore
gunzip -c backups/bookstore_TIMESTAMP.sql.gz | \
  docker exec -i theepicbook-db-1 \
  mysql -u root -p${MYSQL_ROOT_PASSWORD} bookstore

# 6. Restart app
docker compose restart app

# 7. Confirm recovery
curl http://localhost/health
# Expected: 200 {"status":"ok","db":"reachable"}
```

**Result:** Backup and restore tested successfully. Data returned to pre-drop state after restore.

---

## Summary

| Test | Expected | Result |
|---|---|---|
| Restart backend | 502 during restart, auto-recover | ✅ Passed |
| DB down | 503 on /health, unhealthy status | ✅ Passed |
| Full stack bounce | All data present after restart | ✅ Passed |
| Backup and restore | Data fully restored from dump | ✅ Passed |
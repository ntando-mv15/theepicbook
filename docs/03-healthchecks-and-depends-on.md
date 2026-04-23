# 03 — Healthchecks & Startup Order

## The problem healthchecks solve

Docker starts containers roughly in parallel by default. Without controls:

```
db container starts → MySQL still initialising (takes 10–30s)
app container starts → tries to connect to MySQL → connection refused → crash
```

`depends_on` alone only waits for the container process to start, not for the service inside it to be ready. Healthchecks define what "ready" actually means for each service.

## The dependency chain

```
db (mysqladmin ping passes)
   ↓ service_healthy
app (/health returns 200)
   ↓ service_healthy
proxy (GET / returns 200)
```

Nothing starts until the service below it is genuinely healthy.

## DB Healthcheck

```yaml
db:
  healthcheck:
    test: ["CMD", "mysqladmin", "ping", "-h", "localhost", "-u", "root", "-p${MYSQL_ROOT_PASSWORD}"]
    interval: 10s
    timeout: 5s
    retries: 5
    start_period: 30s
```

`mysqladmin ping` sends a ping to the MySQL server. It only succeeds when MySQL is fully initialised and accepting connections.

`start_period: 30s` gives MySQL extra time on first boot when it needs to create the database, create users, and run seed SQL files before it is ready.

## App Healthcheck

```yaml
app:
  healthcheck:
    test: ["CMD", "wget", "-qO-", "http://:8080/health"]
    interval: 10s
    timeout: 5s
    retries: 5
    start_period: 15s
```

The `/health` endpoint was added to `server.js`:

```javascript
app.get("/health", async (req, res) => {
  try {
    await db.sequelize.authenticate();
    res.status(200).json({ status: "ok", db: "reachable" });
  } catch (err) {
    res.status(503).json({ status: "error", db: "unreachable" });
  }
});
```

`db.sequelize.authenticate()` runs `SELECT 1+1` against the database. This confirms not just that the app started, but that the full path from app to database is alive. If the DB goes down after startup, this endpoint reflects that immediately.

Why `wget` and not `curl`: the `node:alpine` image does not include `curl`. `wget` is always present in Alpine images.

## Proxy Healthcheck

```yaml
proxy:
      healthcheck:
      test: ["CMD", "wget", "-qO-", "http://app:8080/health"]
      interval: 10s
      timeout: 5s
      retries: 5
      start_period: 15s
```

## depends_on configuration

```yaml
app:
  depends_on:
    db:
      condition: service_healthy

proxy:
  depends_on:
    app:
      condition: service_healthy
```

`condition: service_healthy` means the dependent service waits until the healthcheck passes — not just until the container starts.


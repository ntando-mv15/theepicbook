# 06 — Logging Layout & Observability

## Logging strategy overview

| Service | Destination | Format | Driver |
|---|---|---|---|
| `proxy` | Bind mount `./logs/nginx/` | JSON structured | Nginx native |
| `app` | stdout → Docker | Plain text | json-file with rotation |
| `db` | stdout → Docker | MySQL native | Docker default |

## Proxy logs — bind mount

```yaml
proxy:
  volumes:
    - ./logs/nginx:/var/log/nginx
```

Two log files are written:
- `access.log` — every HTTP request with full JSON detail
- `error.log` — Nginx errors at `warn` level and above

### Why bind mount for proxy logs

Nginx sits at the edge of the stack — it sees every request. These logs need to be:
- Directly accessible on the host for manual inspection and monitoring agents
- Persistent even if the container is removed
- Easy to tail in real time: `tail -f logs/nginx/access.log`

### JSON log format

```nginx
log_format json_combined escape=json
  '{'
    '"time":"$time_iso8601",'
    '"method":"$request_method",'
    '"uri":"$request_uri",'
    '"status":$status,'
    '"bytes_sent":$bytes_sent,'
    '"request_time":$request_time,'
    '"remote_addr":"$remote_addr",'
    '"http_referrer":"$http_referer",'
    '"http_user_agent":"$http_user_agent",'
    '"upstream_addr":"$upstream_addr",'
    '"upstream_response_time":"$upstream_response_time"'
  '}';
```

### Sample log entry

```json
{
  "time": "2026-04-21T22:34:11+00:00",
  "method": "GET",
  "uri": "/",
  "status": 200,
  "bytes_sent": 25596,
  "request_time": 0.388,
  "remote_addr": "172.21.0.1",
  "http_referrer": "",
  "http_user_agent": "curl/7.81.0",
  "upstream_addr": "172.21.0.2:8080",
  "upstream_response_time": "0.388"
}
```

### Why JSON over plain text

Plain text logs require custom parsers for every tool that ingests them. JSON logs are directly ingestible by CloudWatch, Datadog, ELK stack, and any other log aggregator without transformation.

## App logs — stdout

```yaml
app:
  logging:
    driver: "json-file"
    options:
      max-size: "10m"
      max-file: "3"
```

App logs go to stdout. Docker captures them and wraps them in its own JSON envelope. Maximum storage: 30MB (3 files × 10MB).

### Why stdout for app logs

This follows the 12-factor app standard: applications should not concern themselves with log routing or storage. Write to stdout, let the infrastructure handle the rest. Benefits:
- No log file management inside the container
- Docker handles rotation automatically
- Logs are accessible via `docker logs` immediately
- Easy to forward to a centralised system later without changing the app

### Reading app logs

```bash
# All logs
docker logs theepicbook-app-1

# Follow in real time
docker logs -f theepicbook-app-1

# Last 50 lines
docker logs --tail 50 theepicbook-app-1
```

## DB logs — stdout

MySQL logs go to stdout via Docker's default logging. No custom configuration needed. Read with:

```bash
docker logs theepicbook-db-1
```

DB logs are operational noise (buffer pool init, connection events) — useful for debugging but not needed for day-to-day monitoring.

## Log locations summary

```
theepicbook/
└── logs/
    └── nginx/
        ├── access.log    ← every HTTP request in JSON
        └── error.log     ← Nginx errors

Docker managed:
  theepicbook-app-1       ← docker logs theepicbook-app-1
  theepicbook-db-1        ← docker logs theepicbook-db-1

VM:
  logs/backup.log                  ← daily backup audit trail
```


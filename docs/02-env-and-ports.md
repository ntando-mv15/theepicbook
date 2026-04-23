# 02 — Environment Variables & Ports

## Environment Variables

### What informs the .env structure

The `.env` file is shaped by three sources:
1. What the application code reads (`process.env.*` in `server.js` and `config.json`)
2. What the MySQL Docker image expects (fixed variable names defined by the image)
3. What Docker Compose needs to configure the stack

### Full variable list

| Variable | Read by | Purpose |
|---|---|---|
| `NODE_ENV` | Node.js / Sequelize | Tells Sequelize which config block to use (`production`) |
| `PORT` | `server.js` | Port the Node.js server listens on |
| `JAWSDB_URL` | Sequelize via `config.json` | Full DB connection string — host must be `db` not `127.0.0.1` |
| `MYSQL_ROOT_PASSWORD` | MySQL image | Root superuser password , set on first boot |
| `MYSQL_DATABASE` | MySQL image | Database to create on first boot |
| `MYSQL_USER` | MySQL image | Non-root app user to create on first boot |
| `MYSQL_PASSWORD` | MySQL image | Password for the app user |

### Why JAWSDB_URL instead of individual DB variables

The original `config.json` uses Sequelize's `use_env_variable` directive pointing to `JAWSDB_URL`. This was designed for Heroku deployment. Rather than rewrite `config.json` to read individual variables, we keep it unchanged and provide `JAWSDB_URL` as a full connection string in `.env`.

The critical detail: the hostname in the URL must be `db` (the Docker Compose service name), not `127.0.0.1`. Inside Docker, containers reach each other by service name — `127.0.0.1` refers to the container's own loopback, not the database container.

```
# Wrong — tries to connect to itself
JAWSDB_URL=mysql://epicbook:password@127.0.0.1:3306/bookstore

# Correct — resolves to the db container via Docker DNS
JAWSDB_URL=mysql://epicbook:password@db:3306/bookstore
```


### .env.example (committed to Git)

```bash
NODE_ENV=production
PORT=8080
JAWSDB_URL=mysql://epicbook:@db:3306/bookstore
MYSQL_ROOT_PASSWORD=
MYSQL_DATABASE=bookstore
MYSQL_USER=epicbook
MYSQL_PASSWORD=
```

## Port Exposure

| Service | Internal port | Host port | VM firewall |
|---|---|---|---|
| proxy | 80 | 80 | Open — HTTP traffic |
| app | 8080 | Not published | Closed — internal only |
| db | 3306 | Not published | Closed — internal only |
| SSH | 22 | 22 | Open — your IP only |

### Why only port 80 is open

Every open port is an attack surface. By keeping `8080` and `3306` off the host network:
- Even if the Azure NSG is misconfigured, those ports are unreachable from outside Docker's internal network
- The database is never directly accessible from the internet under any circumstances

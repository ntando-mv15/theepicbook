# 06 — Cloud Deployment Notes

## Platform

- Cloud provider: Microsoft Azure
- VM size: Standard B1s (or equivalent)
- OS: Ubuntu 24.04 LTS
- User: `azureuser`

## VM Provisioning

- Update system
- Install Docker and Docker Compose
- Add `azureuser` to docker group
- Start docker service
- Enable docker service (to start at boot)


## Network Security Group (NSG) Rules

| Rule | Port | Protocol | Source | Purpose |
|---|---|---|---|---|
| Allow HTTP | 80 | TCP | Any | Public web traffic |
| Allow SSH | 22 | TCP | Your IP only | Remote administration |
| Deny all inbound | * | Any | Any | Default deny everything else |

### Why SSH is restricted to your IP

Leaving SSH open to `0.0.0.0/0` exposes the VM to brute-force attacks from the entire internet. Restricting to your IP means only you can SSH in. If your IP changes, update the NSG rule.

### Why port 3306 and 8080 are not in the NSG

These ports are not published to the host by Docker — they exist only on Docker's internal bridge networks. Even if the NSG allowed them, there is nothing listening on those ports at the host level. Defence in depth: both Docker networking and the NSG independently block access to these ports.

## Deployment steps

```bash
# 1. SSH into the VM
ssh azureuser@YOUR_VM_PUBLIC_IP

# 2. Clone the repository
cd /home/azureuser
git clone https://github.com/YOUR_REPO theepicbook
cd theepicbook

# 3. Create .env with production secrets
cp .env.example .env
nano .env
# Fill in: JAWSDB_URL, MYSQL_ROOT_PASSWORD, MYSQL_USER, MYSQL_PASSWORD

# 4. Create logs directory
mkdir -p logs/nginx
mkdir -p logs/backups

# 5. Start the stack
docker compose up -d

# 6. Verify all containers are healthy
docker compose ps

# 7. Check the app is accessible
curl http://localhost/health
```

## Validation checklist

- [ ] `http://PUBLIC_IP/` serves the EpicBook homepage
- [ ] `http://PUBLIC_IP/health` returns `{"status":"ok","db":"reachable"}`
- [ ] Books and authors visible — DB seeded correctly
- [ ] `docker compose ps` shows all three containers as `(healthy)`
- [ ] `docker compose down && docker compose up -d` — data persists


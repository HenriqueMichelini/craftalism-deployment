# Craftalism Deployment

Central deployment configuration for the Craftalism economy server platform.

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                      Craftalism Platform                      │
├─────────────────────────────────────────────────────────────┤
│                                                               │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐  │
│  │  Dashboard   │───▶│     API      │◀───│   Minecraft  │  │
│  │   (React)    │    │    (Java)    │    │    Server    │  │
│  │   Port 8080  │    │  Port 3000   │    │  Port 25565  │  │
│  └──────────────┘    └───────┬──────┘    └──────────────┘  │
│                              │                               │
│                              ▼                               │
│                      ┌──────────────┐                        │
│                      │  PostgreSQL  │                        │
│                      │   Database   │                        │
│                      └──────────────┘                        │
│                                                               │
└─────────────────────────────────────────────────────────────┘
```

## Components

| Service | Image | Purpose |
|---------|-------|---------|
| **API** | `ghcr.io/henriquemichelini/craftalism-api` | Central backend service |
| **Dashboard** | `ghcr.io/henriquemichelini/craftalism-dashboard` | Web management interface |
| **Minecraft** | `itzg/minecraft-server` | Game server with economy plugin |
| **PostgreSQL** | `postgres:15-alpine` | Database for economy data |

## Prerequisites

- Docker Engine 20.10+
- Docker Compose 2.0+
- 4+ GB RAM
- 20+ GB disk space
- Open ports: 25565 (Minecraft), 3000 (API), 8080 (Dashboard)

## Quick Start

### 1. Clone the Repository

```bash
git clone https://github.com/HenriqueMichelini/craftalism-deployment.git
cd craftalism-deployment
```

### 2. Configure Environment

```bash
# Copy the example environment file
cp .env.example .env

# Edit with your settings
nano .env  # or vim, code, etc.
```

**Required changes:**
- `DB_PASSWORD` - Database password
- `API_SECRET` - API authentication key
- `RCON_PASSWORD` - Minecraft RCON password
- `VITE_API_URL` - API URL (for production, use your domain)

**Generate secure secrets:**
```bash
# Database password
openssl rand -base64 32

# API secret
openssl rand -hex 32
```

### 3. Install the Economy Plugin

```bash
# Download the latest plugin JAR from GitHub Releases
wget https://github.com/HenriqueMichelini/craftalism-economy/releases/download/v0.1.0/craftalism-economy-0.1.0.jar

# Start Minecraft server first to create the data volume
docker-compose up -d minecraft

# Wait for server to initialize (about 30 seconds)
sleep 30

# Copy plugin to server
docker cp craftalism-economy-0.1.0.jar craftalism-minecraft:/data/plugins/

# Restart Minecraft server to load plugin
docker-compose restart minecraft
```

### 4. Start All Services

```bash
# Pull latest images
docker-compose pull

# Start all services
docker-compose up -d

# Check status
docker-compose ps

# View logs
docker-compose logs -f
```

### 5. Verify Services

```bash
# Check API health
curl http://localhost:3000/health

# Check Dashboard
open http://localhost:8080

# Check Minecraft server
# Use Minecraft client to connect to: localhost:25565
```

## Service Management

### Start Services

```bash
# Start all services
docker-compose up -d

# Start specific service
docker-compose up -d api
```

### Stop Services

```bash
# Stop all services
docker-compose down

# Stop without removing containers
docker-compose stop

# Stop specific service
docker-compose stop minecraft
```

### View Logs

```bash
# All services
docker-compose logs -f

# Specific service
docker-compose logs -f api
docker-compose logs -f minecraft

# Last 100 lines
docker-compose logs --tail=100 api
```

### Restart Services

```bash
# Restart all
docker-compose restart

# Restart specific service
docker-compose restart api
```

## Updating Services

### Update API or Dashboard

```bash
# Edit .env and change version
# API_VERSION=v0.2.0
# DASHBOARD_VERSION=v0.2.0

# Pull new images
docker-compose pull api dashboard

# Restart services
docker-compose up -d api dashboard
```

### Update Economy Plugin

```bash
# Download new version
wget https://github.com/HenriqueMichelini/craftalism-economy/releases/download/v0.2.0/craftalism-economy-0.2.0.jar

# Stop Minecraft server
docker-compose stop minecraft

# Remove old plugin
docker exec craftalism-minecraft rm /data/plugins/craftalism-economy-0.1.0.jar

# Copy new plugin
docker cp craftalism-economy-0.2.0.jar craftalism-minecraft:/data/plugins/

# Start server
docker-compose up -d minecraft
```

### Update Minecraft Version

```bash
# Edit .env
# MINECRAFT_VERSION=1.20.6

# Backup world first!
./scripts/backup.sh

# Restart server
docker-compose up -d minecraft

# Monitor logs for any issues
docker-compose logs -f minecraft
```

## Backup & Recovery

### Manual Backup

```bash
# Backup database
docker exec craftalism-postgres pg_dump -U craftalism craftalism > backup-$(date +%Y%m%d).sql

# Backup Minecraft world
docker cp craftalism-minecraft:/data ./minecraft-backup-$(date +%Y%m%d)

# Or use tar for compression
docker exec craftalism-minecraft tar -czf /tmp/world-backup.tar.gz /data/world
docker cp craftalism-minecraft:/tmp/world-backup.tar.gz ./world-backup-$(date +%Y%m%d).tar.gz
```

### Restore from Backup

```bash
# Restore database
docker exec -i craftalism-postgres psql -U craftalism craftalism < backup-20260213.sql

# Restore Minecraft world
docker cp ./minecraft-backup-20260213/world craftalism-minecraft:/data/
docker-compose restart minecraft
```

### Automated Backups (Optional)

Create a cron job:

```bash
# Edit crontab
crontab -e

# Add daily backup at 3 AM
0 3 * * * /path/to/craftalism-deployment/scripts/backup.sh
```

## Monitoring

### Check Service Health

```bash
# All services status
docker-compose ps

# API health
curl http://localhost:3000/health

# Database connection
docker exec craftalism-postgres pg_isready -U craftalism

# Minecraft server (via RCON)
docker exec craftalism-minecraft rcon-cli list
```

### Resource Usage

```bash
# Container stats
docker stats

# Disk usage
docker system df

# Specific service
docker stats craftalism-minecraft
```

### Database Access

```bash
# PostgreSQL shell
docker exec -it craftalism-postgres psql -U craftalism

# Run query
docker exec craftalism-postgres psql -U craftalism -c "SELECT COUNT(*) FROM players;"
```

### Minecraft Console

```bash
# Attach to console
docker attach craftalism-minecraft

# Execute command via RCON
docker exec craftalism-minecraft rcon-cli "say Hello from RCON!"

# View online players
docker exec craftalism-minecraft rcon-cli list
```

## Troubleshooting

### API won't start

**Check logs:**
```bash
docker-compose logs api
```

**Common issues:**
- Database not ready: Wait for PostgreSQL health check
- Port conflict: Check if port 3000 is in use
- Environment variables: Verify .env file

### Dashboard shows connection error

**Check:**
1. API is running: `curl http://localhost:3000/health`
2. VITE_API_URL in .env is correct
3. API is accessible from browser (CORS settings)

### Minecraft server won't start

**Check logs:**
```bash
docker-compose logs minecraft
```

**Common issues:**
- Port 25565 in use
- Insufficient memory (increase MINECRAFT_MEMORY)
- Corrupted world data

### Economy plugin not working

**Verify:**
```bash
# Check plugin loaded
docker exec craftalism-minecraft rcon-cli plugins

# Check plugin logs
docker-compose logs minecraft | grep craftalism

# Check config
docker exec craftalism-minecraft cat /data/plugins/craftalism-economy/config.yml
```

**Common issues:**
- API URL incorrect in plugin config
- API not accessible from Minecraft container
- Plugin JAR not in /data/plugins/

### Database connection failed

**Check:**
```bash
# Database is running
docker-compose ps postgres

# Test connection
docker exec craftalism-postgres pg_isready -U craftalism

# Check credentials in .env
```

## Security

### Firewall Configuration

```bash
# Allow Minecraft
sudo ufw allow 25565/tcp

# Allow Dashboard (if exposing publicly)
sudo ufw allow 8080/tcp

# Allow API (if exposing publicly)
sudo ufw allow 3000/tcp

# Enable firewall
sudo ufw enable
```

### Production Recommendations

1. **Use HTTPS** - Put nginx/Caddy in front with SSL certificates
2. **Strong passwords** - Use generated passwords, not defaults
3. **Regular updates** - Keep images and plugins updated
4. **Backups** - Automate daily backups
5. **Monitoring** - Set up alerting for downtime
6. **Network isolation** - Don't expose PostgreSQL port
7. **Limit RCON** - Don't expose RCON port publicly

### SSL/TLS Setup (Optional)

Use Caddy as a reverse proxy:

```yaml
# Add to docker-compose.yml
caddy:
  image: caddy:alpine
  ports:
    - "80:80"
    - "443:443"
  volumes:
    - ./Caddyfile:/etc/caddy/Caddyfile
    - caddy_data:/data
    - caddy_config:/config
```

```
# Caddyfile
dashboard.yourdomain.com {
    reverse_proxy dashboard:80
}

api.yourdomain.com {
    reverse_proxy api:8080
}
```

## Maintenance

### Regular Tasks

**Daily:**
- Check logs for errors
- Monitor resource usage
- Verify backups completed

**Weekly:**
- Review player activity
- Check for plugin updates
- Test backup restoration

**Monthly:**
- Update Docker images
- Review and rotate secrets
- Clean up old backups
- Performance tuning

### Cleanup

```bash
# Remove stopped containers
docker-compose down

# Remove unused images
docker image prune -a

# Remove unused volumes (BE CAREFUL!)
docker volume prune

# Clean everything (BE VERY CAREFUL!)
docker system prune -a
```

## Performance Tuning

### Minecraft Server

Edit `.env`:
```bash
# Increase memory
MINECRAFT_MEMORY=8G

# Reduce view distance for better performance
MINECRAFT_VIEW_DISTANCE=8
MINECRAFT_SIMULATION_DISTANCE=6
```

### PostgreSQL

Add to docker-compose.yml:
```yaml
postgres:
  command:
    - postgres
    - -c
    - max_connections=200
    - -c
    - shared_buffers=256MB
```

### API

Increase container resources:
```yaml
api:
  deploy:
    resources:
      limits:
        cpus: '2'
        memory: 2G
```

## Development vs Production

### Development Setup

```bash
# Use latest tags for rapid iteration
API_VERSION=latest
DASHBOARD_VERSION=latest

# Lower resource usage
MINECRAFT_MEMORY=2G
MINECRAFT_MAX_PLAYERS=10
```

### Production Setup

```bash
# Pin specific versions
API_VERSION=v1.0.0
DASHBOARD_VERSION=v1.0.0

# Production resources
MINECRAFT_MEMORY=8G
MINECRAFT_MAX_PLAYERS=100

# Enable online mode
MINECRAFT_ONLINE_MODE=TRUE
```

## Support

- **GitHub Issues**: Report bugs in respective repositories
- **Documentation**: Check component-specific READMEs
- **Logs**: Always include relevant logs when asking for help

## Repository Structure

```
craftalism-deployment/
├── docker-compose.yml       # Main orchestration file
├── .env.example            # Environment template
├── .env                    # Your actual config (git-ignored)
├── .gitignore             # Git ignore rules
├── README.md              # This file
└── scripts/               # Utility scripts (future)
    ├── backup.sh
    ├── restore.sh
    └── update.sh
```

## Next Steps

- [ ] Set up automated backups (Phase 6.2)
- [ ] Implement update manager (Phase 6.3)
- [ ] Add monitoring dashboard (Phase 6.1)
- [ ] Configure SSL/TLS for production
- [ ] Set up CI/CD for deployment repo
- [ ] Create update automation scripts

---

**Craftalism** - Your Minecraft economy platform 🎮💰

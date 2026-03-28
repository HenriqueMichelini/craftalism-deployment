# Craftalism Deployment

Docker Compose deployment for the **Craftalism economy platform**, including:

- PostgreSQL for persistent storage
- Craftalism Authorization Server (OAuth2/JWT issuer)
- Craftalism API (Spring Boot)
- Craftalism Dashboard (frontend)
- Minecraft server (Paper/itzg image) with the Craftalism economy plugin auto-downloaded

This repository is focused on **runtime orchestration and environment configuration** (not application source code).

---

## What this project does

This repo provides a production-oriented container stack that connects a Minecraft economy server to a web/API backend:

1. Players interact with the Minecraft server.
2. The Minecraft plugin communicates with the Craftalism API.
3. The API uses PostgreSQL and trusts tokens issued by the Authorization Server.
4. The Dashboard is exposed to users/admins and communicates with the API.

---

## Architecture (actual from `docker-compose.yml`)

```text
┌──────────────────────────────────────────────────────────────────────┐
│                           Craftalism Stack                           │
├──────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  Dashboard (:8080->80) ───────▶ API (:3000->8080)                   │
│                                  │                                   │
│                                  ▼                                   │
│                             PostgreSQL (:5432 internal)              │
│                                  ▲                                   │
│                                  │                                   │
│                 Auth Server (:9000->9000) ─────▶ JWT/OIDC issuer     │
│                                                                      │
│  Minecraft (:25565, :25575) ────▶ API + Auth Server                 │
│                                                                      │
└──────────────────────────────────────────────────────────────────────┘
```

### Services

| Service | Container | Image | Purpose |
|---|---|---|---|
| PostgreSQL | `craftalism-postgres` | `postgres:18-alpine` | Primary database |
| Auth DB Init | ephemeral | `postgres:18-alpine` | One-shot init that creates `authserver` DB |
| Authorization Server | `craftalism-auth-server` | `ghcr.io/henriquemichelini/craftalism-authorization-server` | Token issuer / auth |
| API | `craftalism-api` | `ghcr.io/henriquemichelini/craftalism-api` | Core backend |
| Dashboard | `craftalism-dashboard` | `ghcr.io/henriquemichelini/craftalism-dashboard` | Web UI |
| Minecraft | `craftalism-minecraft` | `itzg/minecraft-server` | Game server + plugin runtime |

---

## Tech stack

- **Orchestration:** Docker Compose
- **Database:** PostgreSQL 18 (alpine)
- **Backend runtime:** Java/Spring Boot containers (API + Auth)
- **Frontend runtime:** Dashboard container (served on port 80 inside container)
- **Game server:** Paper-compatible Minecraft server via `itzg/minecraft-server`

---

## Prerequisites

- Docker Engine 20.10+
- Docker Compose v2+
- Recommended host resources: 4+ GB RAM, 20+ GB disk
- Open host ports as needed:
  - `8080` Dashboard
  - `3000` API
  - `9000` Auth Server
  - `25565` Minecraft
  - `25575` RCON

---

## Configuration

1. Copy environment template:

```bash
cp env.example .env
```

2. Update required values in `.env`:

- `DB_PASSWORD`
- `MINECRAFT_CLIENT_SECRET`
- `RSA_PRIVATE_KEY`
- `RSA_PUBLIC_KEY`
- `AUTH_ISSUER_URI` (must match your externally reachable auth URL)
- Optional tuning: `ECONOMY_VERSION`, Minecraft settings, exposed ports

### Generate secrets

```bash
# DB password / client secret examples
openssl rand -base64 32
```

### Generate RSA keys

`env.example` references `./generate-keys.sh`, but that script is not present in this repository. Generate keys with OpenSSL and place them in `.env` with literal `\n` separators:

```bash
# Private key (PKCS#8)
openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:2048 -out private.pem

# Public key
openssl rsa -pubout -in private.pem -out public.pem

# Convert to single-line env-safe values with literal \n
awk '{printf "%s\\n", $0}' private.pem
awk '{printf "%s\\n", $0}' public.pem
```

---

## Run

```bash
# Pull images
docker compose pull

# Start stack
docker compose up -d

# See status
docker compose ps

# Follow logs
docker compose logs -f
```

---

## Health and verification

```bash
# API
curl -f http://localhost:3000/actuator/health

# Auth Server
curl -f http://localhost:9000/actuator/health

# Dashboard
curl -I http://localhost:8080/
```

Minecraft server should be reachable at `localhost:25565`.

---

## Common operations

### Stop

```bash
docker compose down
```

### Restart one service

```bash
docker compose restart api
```

### Update images

```bash
docker compose pull
docker compose up -d
```

### Backup database

```bash
docker exec craftalism-postgres pg_dump -U craftalism craftalism > backup-$(date +%Y%m%d).sql
```

### Restore database

```bash
docker exec -i craftalism-postgres psql -U craftalism craftalism < backup-YYYYMMDD.sql
```

---

## Folder structure

```text
.
├── docker-compose.yml       # Full multi-service deployment topology
├── env.example              # Environment variable template
├── DEPLOYMENT_README.md     # Legacy deployment notes
├── README.md                # Main project documentation (this file)
└── LICENSE
```

---

## Known limitations / notes

- This repository contains deployment definitions only; application source code lives in separate repositories/images.
- The Minecraft plugin is downloaded dynamically from GitHub Releases using `ECONOMY_VERSION`.
- `AUTH_ISSUER_URI` and the token issuer used by dependent services must be consistent in real deployments.

---

## Future improvements

- Add `generate-keys.sh` script referenced by `env.example`.
- Add pinned image tags (instead of `latest`) for repeatable deployments.
- Add example reverse-proxy/TLS setup (Nginx/Caddy/Traefik).
- Add automated backup/restore scripts and runbooks.

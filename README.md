# Craftalism Deployment

> Docker Compose orchestration for the full Craftalism economy platform: database, authorization server, backend API, frontend dashboard, and Minecraft game server.

---

## Overview

This repository contains the runtime orchestration and environment configuration for the Craftalism stack. It does not contain application source code; all services are pulled from pre-built container images.

**Key capabilities:**

- Single `docker compose up` brings up the complete platform.
- PostgreSQL provides shared persistent storage for the API and Authorization Server.
- The Minecraft plugin is downloaded automatically from GitHub Releases at container startup using the configured `ECONOMY_VERSION`.
- All inter-service communication happens on an isolated Docker network.

---

## Architecture

```text
┌─────────────────────────────────────────────────────────────┐
│                      Craftalism Stack                        │
│                                                             │
│  Dashboard (:8080 → :80) ──────▶ API (:3000 → :8080)       │
│                                         │                   │
│                                         ▼                   │
│                                    PostgreSQL               │
│                                    (internal)               │
│                                         ▲                   │
│                                         │                   │
│              Auth Server (:9000) ───────┘                   │
│                    ▲                                        │
│                    │                                        │
│  Minecraft (:25565, :25575) ──────▶ API + Auth Server       │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### Services

| Container | Image | Purpose |
|---|---|---|
| `craftalism-postgres` | `postgres:18-alpine` | Primary database for API and Auth Server. |
| `auth-db-init` | `postgres:18-alpine` | One-shot container that creates the `authserver` database before the app starts. |
| `craftalism-auth-server` | `ghcr.io/henriquemichelini/craftalism-authorization-server` | OAuth2/JWT token issuer. |
| `craftalism-api` | `ghcr.io/henriquemichelini/craftalism-api` | Core economy REST API. |
| `craftalism-dashboard` | `ghcr.io/henriquemichelini/craftalism-dashboard` | Admin web UI. |
| `craftalism-minecraft` | `itzg/minecraft-server` | Paper Minecraft server with the economy plugin. |

---

## Tech Stack

| Category | Technology |
|---|---|
| Orchestration | Docker Compose |
| Database | PostgreSQL 18 (alpine) |
| Backend runtime | Java / Spring Boot (via pre-built images) |
| Frontend runtime | Nginx (via pre-built dashboard image) |
| Game server | Paper via `itzg/minecraft-server` |

---

## Prerequisites

- Docker Engine 20.10+
- Docker Compose v2+
- Host resources: 4+ GB RAM, 20+ GB disk recommended

---

## Configuration

### 1. Copy the environment template

```bash
cp env.example .env
```

### 2. Set required values in `.env`

| Variable | Default | Description |
|---|---|---|
| `DB_PASSWORD` | — | **Required.** PostgreSQL password for the `craftalism` user. |
| `MINECRAFT_CLIENT_SECRET` | — | **Required.** OAuth2 client secret for the Minecraft plugin. |
| `RSA_PRIVATE_KEY` | — | **Required.** PEM-encoded RSA private key with literal `\n` separators. |
| `RSA_PUBLIC_KEY` | — | **Required.** PEM-encoded RSA public key with literal `\n` separators. |
| `AUTH_ISSUER_URI` | — | **Required.** Externally reachable URL of the Authorization Server. Must be consistent across all services. |
| `ECONOMY_VERSION` | — | GitHub Release tag of the economy plugin JAR to download at Minecraft container startup. |

### 3. Generate secrets

```bash
# Generate a random DB password or client secret
openssl rand -base64 32
```

### 4. Generate RSA keys

> **Note:** A `generate-keys.sh` script is referenced in `env.example` but is not present in this repository. Generate keys manually with OpenSSL and place them in `.env` using literal `\n` as the line separator.

```bash
# Generate private key (PKCS#8 format)
openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:2048 -out private.pem

# Derive public key
openssl rsa -pubout -in private.pem -out public.pem

# Convert to single-line env-safe format (literal \n)
awk '{printf "%s\\n", $0}' private.pem   # → RSA_PRIVATE_KEY value
awk '{printf "%s\\n", $0}' public.pem    # → RSA_PUBLIC_KEY value
```

---

## Running with Docker

### Production mode (default)

```bash
# Pull images pinned by VERSION variables from .env
docker compose pull

# Start the stack
docker compose up -d

# Check service status
docker compose ps

# Follow all logs
docker compose logs -f
```

| Service | Host Port | URL |
|---|---|---|
| Dashboard | 8080 | `http://localhost:8080` |
| API | 3000 | `http://localhost:3000` |
| Authorization Server | 9000 | `http://localhost:9000` |
| Minecraft | 25565 | `localhost:25565` |
| RCON | 25575 | `localhost:25575` |

---

## API Reference

### Health checks

```bash
# API
curl -f http://localhost:3000/actuator/health

# Authorization Server
curl -f http://localhost:9000/actuator/health

# Dashboard
curl -I http://localhost:8080/
```

All three should return HTTP 200 before considering the stack healthy.

---

## Testing

This repository does not include automated tests. Verification is done via the health checks above after `docker compose up`.

---

## Project Structure

```text
.
├── docker-compose.yml    # Full multi-service deployment topology
├── env.example           # Environment variable template
├── README.md
└── LICENSE
```

---

## Common Operations

### Stop the stack

```bash
docker compose down
```

### Restart a single service

```bash
docker compose restart api
```

### Update to latest images (production pins)

```bash
docker compose pull
docker compose up -d
```

### Refresh mutable test tags

```bash
docker compose -f docker-compose.yml -f docker-compose.test.yml pull auth-server api dashboard
docker compose -f docker-compose.yml -f docker-compose.test.yml up -d
docker compose -f docker-compose.yml -f docker-compose.test.yml up -d --no-deps --force-recreate auth-server api dashboard
```

### Back up the database

```bash
docker exec craftalism-postgres \
  pg_dump -U craftalism craftalism > backup-$(date +%Y%m%d).sql
```

### Restore the database

```bash
docker exec -i craftalism-postgres \
  psql -U craftalism craftalism < backup-YYYYMMDD.sql
```

---

## Known Limitations

- Production reproducibility depends on pinning `AUTH_SERVER_VERSION`, `API_VERSION`, and `DASHBOARD_VERSION` in `.env`. Test mode intentionally overrides them to mutable test tags (`latest` by default).
- `AUTH_ISSUER_URI` must be reachable by all services at runtime. An incorrect or unreachable issuer URI will cause token validation failures across the API and Minecraft plugin.
- No reverse proxy or TLS termination is configured; all services are exposed directly on host ports.
- No `generate-keys.sh` script is present despite being referenced in `env.example`.

---

## Roadmap

- Pin image tags to specific versions for reproducible deployments.
- Add a `generate-keys.sh` script for RSA key generation.
- Add an example reverse proxy configuration with TLS (Nginx, Caddy, or Traefik).
- Add automated backup and restore scripts with scheduling guidance.

---

## License

MIT. See [`LICENSE`](./LICENSE) for details.

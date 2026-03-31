# Craftalism Deployment

> Docker Compose orchestration for the full Craftalism platform in two modes:
> **production/release mode** (prebuilt tagged images) and **test/development mode** (live source synced from `main`).

## Modes

### Production / release mode (unchanged)
- Uses `docker-compose.yml` only.
- Uses image tags from `*_VERSION` variables in `.env`.
- Minecraft downloads the economy plugin from GitHub Releases using `ECONOMY_VERSION`.

---

## Prerequisites

- Docker Engine 20.10+
- Docker Compose v2+
- Git
- Host resources: 4+ GB RAM, 20+ GB disk recommended

---

## Configuration

### 1) Copy env template

```bash
cp env.example .env
```

### 2) Required production values in `.env`

| Variable | Description |
|---|---|
| `DB_PASSWORD` | PostgreSQL password for `craftalism` user. |
| `MINECRAFT_CLIENT_SECRET` | OAuth2 client secret used by Minecraft integration. |
| `RSA_PRIVATE_KEY` | PEM private key encoded as a single line with literal `\\n`. |
| `RSA_PUBLIC_KEY` | PEM public key encoded as a single line with literal `\\n`. |
| `AUTH_ISSUER_URI` | External issuer URI used across services. |
| `ECONOMY_VERSION` | Economy plugin release version used in production mode only. |

---

## Running the stack

### Production / release mode

```bash
docker compose pull
docker compose up -d
```

Stops exactly as before:

```bash
docker compose down
```

---

## Compose files

- `docker-compose.yml`: canonical production/release deployment.

Production behavior stays stable because test behavior is isolated in the override file and helper script.

---

## Health checks

```bash
curl -f http://localhost:3000/actuator/health
curl -f http://localhost:9000/actuator/health
curl -I http://localhost:8080/
```

---

## Notes

- Test mode intentionally tracks mutable branch heads and is not reproducible like releases.
- Production mode should pin `AUTH_SERVER_VERSION`, `API_VERSION`, `DASHBOARD_VERSION`, and `ECONOMY_VERSION`.
- No reverse proxy/TLS is configured in this repository.

## License

MIT. See [`LICENSE`](./LICENSE).

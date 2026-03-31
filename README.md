# Craftalism Deployment

> Docker Compose orchestration for the full Craftalism platform in two modes:
> **production/release mode** (prebuilt tagged images) and **test/development mode** (live source synced from `main`).

## Modes

### Production / release mode (unchanged)
- Uses `docker-compose.yml` only.
- Uses image tags from `*_VERSION` variables in `.env`.
- Minecraft downloads the economy plugin from GitHub Releases using `ECONOMY_VERSION`.

### Test / development mode (new)
- Uses `docker-compose.yml` + `docker-compose.test.yml`.
- Uses `scripts/test-mode.sh` to clone/update source repos under `/tmp/craftalism-test-mode` (configurable).
- Every run syncs each repo to the latest `origin/main`.
- Builds auth server, API, and dashboard Docker images from local source.
- Builds the economy plugin from local source and mounts the built JAR into Minecraft.
- Keeps the same host ports and service names as production.

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

### 3) Optional test-mode repository/branch overrides

Defaults are already provided in `env.example`; override only if needed:

- `AUTH_SERVER_REPO_URL`, `API_REPO_URL`, `DASHBOARD_REPO_URL`, `ECONOMY_REPO_URL`
- `AUTH_SERVER_BRANCH`, `API_BRANCH`, `DASHBOARD_BRANCH`, `ECONOMY_BRANCH`
- `TEST_WORKSPACE_ROOT` (default `/tmp/craftalism-test-mode`)

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

### Test / development mode

Start or refresh test mode:

```bash
./scripts/test-mode.sh
```

What this does each run:
1. Clones missing repos into `/tmp/craftalism-test-mode`.
2. Fetches and hard-resets existing repos to `origin/<branch>` (default `main`).
3. Rebuilds the economy plugin JAR from source.
4. Regenerates `.test-mode.env` with resolved local paths.
5. Runs Compose with `--build` using the test override file.

Stop test mode:

```bash
./scripts/test-mode.sh down
```

> **Idempotent workflow:** rerunning `./scripts/test-mode.sh` updates existing checkouts and restarts the stack with fresh builds. No manual cleanup is required for normal use.

---

## Compose files

- `docker-compose.yml`: canonical production/release deployment.
- `docker-compose.test.yml`: test-only overrides that switch app services to local build contexts and switch Minecraft to a locally built economy plugin JAR.

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

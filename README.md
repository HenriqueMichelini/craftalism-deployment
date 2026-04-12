# Craftalism Deployment

Docker Compose orchestration for the Craftalism platform with **explicitly separated workflows**:

1. **Local development** (`docker-compose.yml` + `docker-compose.local.yml`)
2. **Staging / test** (`docker-compose.yml` + `docker-compose.test.yml`)
3. **Production** (`docker-compose.yml` behind the infra-managed host edge)

---

## Why this split exists

- Local development should be fast, editable, and not depend on published releases.
- Staging/test should be immutable and traceable to a commit.
- Production should be immutable and tied to released versions only.

---

## Prerequisites

- Docker Engine 20.10+
- Docker Compose v2+
- Git
- For local plugin builds: JDK compatible with the economy and market plugin projects

---

## Configuration

```bash
cp env.example .env
```

Set required secrets and issuer config (`DB_PASSWORD`, `MINECRAFT_CLIENT_SECRET`, `RSA_PRIVATE_KEY`, `RSA_PUBLIC_KEY`, `AUTH_ISSUER_URI`, etc.) in `.env`.

For the normal EC2 production path behind `craftalism-infra`, this repo binds
application upstreams only on loopback and relies on the host Caddy proxy from
that infra repository to own public `80/443`.

Expected localhost bindings:

- auth server: `127.0.0.1:9000`
- API: `127.0.0.1:3000`
- dashboard: `127.0.0.1:8080`

### Path assumptions (local development)

This deployment repository expects sibling checkouts for local build contexts:

```text
<parent-dir>/
  craftalism-deployment/                  # this repository
  craftalism-authorization-server/
  craftalism-api/
  craftalism-dashboard/
  craftalism-economy/
    java/
  craftalism-market/
    java/
```

If your layout differs, set `*_BUILD_CONTEXT`, `*_DOCKERFILE`, `ECONOMY_PLUGIN_JAR`, and `MARKET_PLUGIN_JAR` explicitly in `.env` (or exported environment variables). The default local build expects these app subdirectory contexts:

- `craftalism-authorization-server/java`
- `craftalism-api/java`
- `craftalism-dashboard/react`

---

## Quick start (plug-and-play modes)

From repo root, you can now run:

```bash
./local
./local down
./local hot dashboard
./test
./test down
./prod
./prod down
```

What each command does:
- `./local`: bootstraps local sibling repos, builds local plugin jar, and starts local compose (`docker-compose.yml` + `docker-compose.local.yml`).
- `./local down`: stops/removes the local stack with the same compose file set.
- `./local hot <service>`: rebuilds/restarts only one local service (for example `./local hot dashboard`) without restarting the full stack.
- `./test`: ensures local plugin jar exists, auto-populates CI tag env vars from current git branch/sha if absent, provides safe defaults for base-compose required vars, refreshes test base-image digests when enabled, and for app services falls back to local `*:local` images when remote CI tags are unavailable.
- `./test down`: stops/removes the test stack with test compose overrides.
- `./prod`: optionally refreshes pinned image digests into `.env`, reuses those pulls when available, and starts the production stack on localhost-only upstream ports for the infra-managed edge.
- `./prod down`: stops/removes the production stack.
- `scripts/monitor-platform.sh`: prints a host and container runtime snapshot; use `--watch=3` for a live refresh loop on EC2.

Optional behavior flags:
- `SKIP_DIGEST_REFRESH=1 ./prod` to skip automatic digest refresh.
- `CLEAN_PLUGIN_BUILD=1 ./local` to force clean plugin build via bootstrap.
- `LOCAL_BUILD_RETRIES=5 ./local` to retry transient local docker builds (default: 3 attempts).
- `scripts/resolve-image-digests.sh --env-file .env --mode test --write` to resolve only digests needed by `./test`.

---

## 1) Local development flow

Use local build contexts for Java/UI services and locally built Minecraft plugin jars.

### Build the plugins locally

```bash
scripts/build-economy-plugin.sh ../craftalism-economy/java
scripts/build-market-plugin.sh ../craftalism-market/java
```

For a forced clean rebuild when plugin metadata/dependencies changed:

```bash
scripts/build-economy-plugin.sh --clean ../craftalism-economy/java
scripts/build-market-plugin.sh --clean ../craftalism-market/java
```

This produces:

- `.local-dev/craftalism-economy.jar`
- `.local-dev/craftalism-market.jar`

### Run local stack

```bash
export AUTH_SERVER_BUILD_CONTEXT=../craftalism-authorization-server/java
export API_BUILD_CONTEXT=../craftalism-api/java
export DASHBOARD_BUILD_CONTEXT=../craftalism-dashboard/react
export ECONOMY_PLUGIN_JAR=$PWD/.local-dev/craftalism-economy.jar
export MARKET_PLUGIN_JAR=$PWD/.local-dev/craftalism-market.jar
export AUTH_SERVER_DOCKERFILE=Dockerfile
export API_DOCKERFILE=Dockerfile
export DASHBOARD_DOCKERFILE=Dockerfile


docker compose -f docker-compose.yml -f docker-compose.local.yml up --build
```

Notes:
- The compose local override builds `auth-server`, `api`, and `dashboard` from local source paths.
- By default those local builds use app subdirectory contexts (`java` for the backend services, `react` for the dashboard) and `Dockerfile` inside each context.
- If you prefer pointing `*_BUILD_CONTEXT` at a repo root, pair it with the matching subdirectory Dockerfile, for example `AUTH_SERVER_DOCKERFILE=java/Dockerfile`. The `./local` helper normalizes that combination back to the subdirectory context automatically.
- Minecraft plugins use local jar mounts (`/data/plugins/craftalism-economy.jar` and `/data/plugins/craftalism-market.jar`) and do **not** use GitHub Releases in local mode.
- If you are iterating heavily on one service, direct IDE execution is recommended while keeping dependencies (Postgres/Auth/API) in Compose.
- For faster local loops, you can boot only shared dependencies (Postgres/Auth/API):

```bash
scripts/start-local-deps.sh up
scripts/start-local-deps.sh down
```

---

## 2) Staging / test flow

Staging uses CI-built immutable images tagged by branch + short SHA, for example:

- `craftalism-api:main-a1b2c3d`
- `craftalism-authorization-server:main-a1b2c3d`
- `craftalism-dashboard:main-a1b2c3d`

The workflow `.github/workflows/build-staging-images.yml` first validates deployment wiring (script syntax + compose interpolation checks) and then builds/pushes those tags on each push to `main` or `feature/**`.

CI note:
- When this deployment repo publishes staging images to existing GHCR packages such as `ghcr.io/henriquemichelini/craftalism-api`, the default `GITHUB_TOKEN` may not have permission to write those package namespaces because it is scoped to `craftalism-deployment`, not the service repos that own the packages.
- Configure Actions secrets `GHCR_PUSH_TOKEN` (classic PAT or fine-grained token with package write access to the target packages) and optionally `GHCR_USERNAME`. The staging workflow uses those secrets when present and falls back to `GITHUB_TOKEN` otherwise.

### Run test stack

```bash
export AUTH_SERVER_CI_TAG=main-a1b2c3d
export API_CI_TAG=main-a1b2c3d
export DASHBOARD_CI_TAG=main-a1b2c3d
export AUTH_SERVER_GIT_SHA=a1b2c3d
export API_GIT_SHA=a1b2c3d
export DASHBOARD_GIT_SHA=a1b2c3d
export ECONOMY_GIT_SHA=a1b2c3d
export MARKET_GIT_SHA=a1b2c3d
export ECONOMY_PLUGIN_JAR=$PWD/.local-dev/craftalism-economy.jar
export MARKET_PLUGIN_JAR=$PWD/.local-dev/craftalism-market.jar

docker compose -f docker-compose.yml -f docker-compose.test.yml up -d
```

Optional pre-pull (recommended in CI to reduce cold-start time):

```bash
scripts/prepull-images.sh test
```

Notes:
- Test overrides replace service images with commit-tagged CI images.
- Test still uses locally built plugin artifacts (mounted jars), not release download transport.
- Commit metadata is attached as labels/environment values so the running commit is obvious.

---

## 3) Production flow

Production uses the base compose file directly. The public edge, TLS, and
dashboard basic auth are expected to be owned by `craftalism-infra` on the
host, while this repo publishes only the localhost upstream ports the host
proxy forwards to.

```bash
scripts/prepull-images.sh production
docker compose up -d
```

Production requirements:
- Publicly expose only `80`, `443`, and `25565` at the EC2/security-group layer. Keep `9000`, `3000`, `8080`, and `25575` private.
- Set immutable release tags in `.env` (`AUTH_SERVER_VERSION`, `API_VERSION`, `DASHBOARD_VERSION`, `ECONOMY_VERSION`, `MARKET_VERSION`).
- Set pinned image digests in `.env` (`AUTH_SERVER_DIGEST`, `API_DIGEST`, `DASHBOARD_DIGEST`, `POSTGRES_DIGEST`, `MINECRAFT_IMAGE_DIGEST`).
- Do **not** use `latest` or unpinned image references.
- Economy and market plugins are downloaded from GitHub Releases using `ECONOMY_VERSION` and `MARKET_VERSION`.
- Image references are configured as `repo:tag@sha256:...` so deployments are immutable by default.
- `craftalism-infra` owns the public edge proxy, TLS termination, and dashboard basic auth for the EC2 deployment path.
- `./prod up` fails fast and prints missing variable names when required production configuration is not set.

### Small-instance guidance

For `t3.small` testing, this repo now supports explicit runtime ceilings through `.env`:

- `AUTH_SERVER_JAVA_TOOL_OPTIONS` and `API_JAVA_TOOL_OPTIONS` cap Spring JVM heap growth.
- `*_MEM_LIMIT` and `*_MEM_RESERVATION` set container-level memory ceilings.
- `POSTGRES_SHARED_BUFFERS`, `POSTGRES_WORK_MEM`, and `POSTGRES_MAINTENANCE_WORK_MEM` keep the database conservative on low-memory hosts.
- `MINECRAFT_INIT_MEMORY`, `MINECRAFT_MEMORY`, `MINECRAFT_VIEW_DISTANCE`, and `MINECRAFT_SIMULATION_DISTANCE` now have low-memory-friendly example values in `env.example`.

These defaults are aimed at survival on a hobby-scale `t3.small`. If the host still thrashes or player load is non-trivial, move to `t3.medium`.

---

## Health checks

```bash
curl -I "https://dashboard.craftalism.com/"
curl -f "https://auth.craftalism.com/actuator/health"
curl -f "https://api.craftalism.com/actuator/health"
```

---

## Compose file responsibilities

- `docker-compose.yml`: production-safe baseline with localhost-only upstream publishing for the infra-managed host edge, plus an optional `standalone-edge` profile.
- `docker-compose.local.yml`: local source builds + direct local port publishing + local economy/market plugin jars.
- `docker-compose.test.yml`: staging/test CI-tagged immutable images + direct test port publishing + local test-built economy/market plugin jars.

## License

MIT. See [`LICENSE`](./LICENSE).

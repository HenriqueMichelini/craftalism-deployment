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

For local Docker development, keep production-style values in `.env` if you need them, but put container-network overrides in `.env.local`:

```bash
cp .env.local.example .env.local
```

`./local` reads `.env` first and then applies `.env.local` overrides, so local auth/API wiring can use internal service URLs such as `http://craftalism-auth-server:9000` without affecting production settings.

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
- `./local`: bootstraps local sibling repos, builds local plugin jar, reads `.env` plus optional `.env.local` overrides, and starts local compose (`docker-compose.yml` + `docker-compose.local.yml`).
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
- `CRAFTALISM_RUNTIME_PROFILE=standard ./prod` to raise deployment-owned memory defaults above the small-host preset.
- `CRAFTALISM_PROD_VARIANT=friend-paper ./prod` to run production with `docker-compose.friend-paper.yml`.
- `scripts/resolve-image-digests.sh --env-file .env --mode test --write` to resolve only digests needed by `./test`.

---

## 1) Local development flow

Use local build contexts for Java/UI services and locally built Minecraft plugin jars.

### Build the plugins locally

```bash
scripts/build-economy-plugin.sh ../craftalism-economy
scripts/build-market-plugin.sh ../craftalism-market
```

For a forced clean rebuild when plugin metadata/dependencies changed:

```bash
scripts/build-economy-plugin.sh --clean ../craftalism-economy
scripts/build-market-plugin.sh --clean ../craftalism-market
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
- Dashboard write actions go through the deployment-owned `dashboard-bff` service. Set `DASHBOARD_BFF_CLIENT_SECRET` in `.env` to the same server-side secret registered by `craftalism-authorization-server`; do not expose it to browser runtime configuration.
- By default those local builds use app subdirectory contexts (`java` for the backend services, `react` for the dashboard) and `Dockerfile` inside each context.
- If you prefer pointing `*_BUILD_CONTEXT` at a repo root, pair it with the matching subdirectory Dockerfile, for example `AUTH_SERVER_DOCKERFILE=java/Dockerfile`. The `./local` helper normalizes that combination back to the subdirectory context automatically.
- Minecraft plugins use local jar mounts (`/data/plugins/craftalism-economy.jar` and `/data/plugins/craftalism-market.jar`) and do **not** use GitHub Releases in local mode.
- If you are iterating heavily on one service, direct IDE execution is recommended while keeping dependencies (Postgres/Auth/API) in Compose.
- For faster local loops, you can boot only shared dependencies (Postgres/Auth/API):

```bash
scripts/start-local-deps.sh up
scripts/start-local-deps.sh down
```

### Verify dashboard writes locally

After the local stack is running, create, update, and delete a player or balance from the dashboard at `http://localhost:8080/`.

Expected path:

```text
browser -> dashboard /api/dashboard/... -> dashboard-bff -> auth-server /oauth2/token -> api /api/...
```

Verification checks:

- `dashboard-bff` is healthy in `docker compose ps`.
- The browser network panel shows writes to `/api/dashboard/players` or `/api/dashboard/balances`.
- API writes still reach canonical `/api/players` and `/api/balances` only from `dashboard-bff` with a Bearer token.
- `DASHBOARD_BFF_CLIENT_SECRET` does not appear in browser JavaScript, runtime config, or network payloads.

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

Production uses the base compose file by default. The public edge, TLS, and
dashboard basic auth are expected to be owned by `craftalism-infra` on the
host, while this repo publishes only the localhost upstream ports the host
proxy forwards to.

```bash
scripts/prepull-images.sh production
docker compose up -d
```

Use `./prod` for the checked production path. It validates required production
configuration, refreshes image digests unless disabled, pre-pulls images, and
starts the selected production compose set.

Production requirements:
- Publicly expose only `80`, `443`, and `25565` at the EC2/security-group layer. Keep `9000`, `3000`, `8080`, and `25575` private.
- Set immutable release tags in `.env` (`AUTH_SERVER_VERSION`, `API_VERSION`, `DASHBOARD_VERSION`, `ECONOMY_VERSION`, `MARKET_VERSION`).
- Set pinned image digests in `.env` (`AUTH_SERVER_DIGEST`, `API_DIGEST`, `DASHBOARD_DIGEST`, `POSTGRES_DIGEST`, `MINECRAFT_IMAGE_DIGEST`).
- Set the Paper market plugin runtime config in `.env` (`MARKET_API_BASE_URL`, `MARKET_API_SNAPSHOT_PATH`, and related `MARKET_API_*` settings). The deployment now seeds `/data/plugins/CraftalismMarket/config.yml` from these values before Paper starts.
- Optional extra server jars must be Paper/Bukkit/Spigot plugins. Add them with `MINECRAFT_EXTRA_PLUGIN_URLS`; Forge, Fabric, and NeoForge mods do not run on Paper.
- Do **not** use `latest` or unpinned image references.
- Economy and market plugins are downloaded from GitHub Releases using `ECONOMY_VERSION` and `MARKET_VERSION`.
- Image references are configured as `repo:tag@sha256:...` so deployments are immutable by default.
- `craftalism-infra` owns the public edge proxy, TLS termination, and dashboard basic auth for the EC2 deployment path.
- `./prod up` fails fast and prints missing variable names when required production configuration is not set.
- `./prod up` also validates deployment-owned memory budgets so JVM heap/metaspace and Minecraft heap settings leave headroom inside each container limit.

### Small-instance guidance

For `t3.small` testing, this repo now supports profile-driven runtime ceilings through `.env`:

- `CRAFTALISM_RUNTIME_PROFILE=small-host` applies conservative defaults for Java, Postgres, dashboard, edge, and Minecraft.
- `CRAFTALISM_RUNTIME_PROFILE=standard` raises those defaults for less constrained hosts without changing compose files.
- Per-service env vars still override the selected profile when you need a one-off adjustment.
- The Java defaults now use container-aware heap percentages, reduced thread stacks, and fail-fast OOM behavior so the container budget remains enforceable.

These defaults are aimed at survival on a hobby-scale `t3.small`. If the host still thrashes or player load is non-trivial, move to `t3.medium`.

### Friend Paper server override

For a small Paper server with two extra plugin jars:

```bash
cp env.friend-paper.example .env.friend-paper
# TreeChopper is enabled by default through FRIEND_PAPER_MODRINTH_PROJECTS.
# Optionally add more trusted Paper/Bukkit/Spigot plugin jar URLs with MINECRAFT_EXTRA_PLUGIN_URLS.
CRAFTALISM_PROD_VARIANT=friend-paper ./prod
```

`./prod down` must be run with the same variant when stopping this compose set:

```bash
CRAFTALISM_PROD_VARIANT=friend-paper ./prod down
```

This override installs the TreeChopper Paper plugin from Modrinth. It does not make Paper load Forge, Fabric, or NeoForge mods. If those two requested jars are real mods, use a separate mod-loader server type instead and expect the Craftalism Paper plugins to be out of scope for that server.

### Friend modded server override

For real Forge, Fabric, NeoForge, or Quilt mods, run a separate modded server:

```bash
cp env.friend-modded.example .env.friend-modded
# edit FRIEND_MODDED_TYPE, FRIEND_MODDED_MINECRAFT_VERSION, and FRIEND_MODDED_MOD_URLS
docker compose --env-file .env.friend-modded -f docker-compose.friend-modded.yml up -d
```

This starts only `minecraft-modded` with its own `minecraft_modded_data` volume. It does not load the Craftalism Paper plugins or depend on the Craftalism API stack.

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

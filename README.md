# Craftalism Deployment

Docker Compose orchestration for the Craftalism platform with **explicitly separated workflows**:

1. **Local development** (`docker-compose.yml` + `docker-compose.local.yml`)
2. **Staging / test** (`docker-compose.yml` + `docker-compose.test.yml`)
3. **Production** (`docker-compose.yml` only)

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
- For local plugin builds: JDK compatible with the economy plugin project

---

## Configuration

```bash
cp env.example .env
```

Set required secrets (`DB_PASSWORD`, `MINECRAFT_CLIENT_SECRET`, `RSA_PRIVATE_KEY`, `RSA_PUBLIC_KEY`, etc.) in `.env`.

---

## Quick start (plug-and-play modes)

From repo root, you can now run:

```bash
./local
./test
./prod
```

What each command does:
- `./local`: bootstraps local sibling repos, builds local plugin jar, and starts local compose (`docker-compose.yml` + `docker-compose.local.yml`).
- `./test`: ensures local plugin jar exists, auto-populates CI tag env vars from current git branch/sha if absent, pre-pulls test images, and starts test compose (`docker-compose.yml` + `docker-compose.test.yml`).
- `./prod`: optionally refreshes pinned image digests into `.env`, pre-pulls production images, then starts production compose (`docker-compose.yml`).

Optional behavior flags:
- `SKIP_DIGEST_REFRESH=1 ./prod` to skip automatic digest refresh.
- `CLEAN_PLUGIN_BUILD=1 ./local` to force clean plugin build via bootstrap.

---

## 1) Local development flow

Use local build contexts for Java/UI services and a locally built Minecraft economy plugin jar.

### Build the economy plugin locally

```bash
scripts/build-economy-plugin.sh ../craftalism-economy
```

For a forced clean rebuild when plugin metadata/dependencies changed:

```bash
scripts/build-economy-plugin.sh --clean ../craftalism-economy
```

This produces:

- `.local-dev/craftalism-economy.jar`

### Run local stack

```bash
export AUTH_SERVER_BUILD_CONTEXT=../craftalism-authorization-server
export API_BUILD_CONTEXT=../craftalism-api
export DASHBOARD_BUILD_CONTEXT=../craftalism-dashboard
export ECONOMY_PLUGIN_JAR=$PWD/.local-dev/craftalism-economy.jar

docker compose -f docker-compose.yml -f docker-compose.local.yml up --build
```

Notes:
- The compose local override builds `auth-server`, `api`, and `dashboard` from local source paths.
- Minecraft plugin uses local jar mount (`/data/plugins/craftalism-economy.jar`) and does **not** use GitHub Releases in local mode.
- If you are iterating heavily on one service, direct IDE execution is recommended while keeping dependencies (Postgres/Auth/API) in Compose.
- For faster local loops, you can boot only shared dependencies:

```bash
scripts/start-local-deps.sh up
```

---

## 2) Staging / test flow

Staging uses CI-built immutable images tagged by branch + short SHA, for example:

- `craftalism-api:main-a1b2c3d`
- `craftalism-authorization-server:main-a1b2c3d`
- `craftalism-dashboard:main-a1b2c3d`

The workflow `.github/workflows/build-staging-images.yml` builds and pushes those tags on each push to `main` or `feature/**`.

### Run test stack

```bash
export AUTH_SERVER_CI_TAG=main-a1b2c3d
export API_CI_TAG=main-a1b2c3d
export DASHBOARD_CI_TAG=main-a1b2c3d
export AUTH_SERVER_GIT_SHA=a1b2c3d
export API_GIT_SHA=a1b2c3d
export DASHBOARD_GIT_SHA=a1b2c3d
export ECONOMY_GIT_SHA=a1b2c3d
export ECONOMY_PLUGIN_JAR=$PWD/.local-dev/craftalism-economy.jar

docker compose -f docker-compose.yml -f docker-compose.test.yml up -d
```

Optional pre-pull (recommended in CI to reduce cold-start time):

```bash
scripts/prepull-images.sh test
```

Notes:
- Test overrides replace service images with commit-tagged CI images.
- Test still uses a locally built economy plugin artifact (mounted jar), not release download transport.
- Commit metadata is attached as labels/environment values so the running commit is obvious.

---

## 3) Production flow

Production uses `docker-compose.yml` only.

```bash
scripts/prepull-images.sh production
docker compose up -d
```

Production requirements:
- Set immutable release tags in `.env` (`AUTH_SERVER_VERSION`, `API_VERSION`, `DASHBOARD_VERSION`, `ECONOMY_VERSION`).
- Set pinned image digests in `.env` (`AUTH_SERVER_DIGEST`, `API_DIGEST`, `DASHBOARD_DIGEST`, `POSTGRES_DIGEST`, `MINECRAFT_IMAGE_DIGEST`).
- Do **not** use `latest` or unpinned image references.
- Economy plugin is downloaded from GitHub Releases using `ECONOMY_VERSION` (release artifact path).
- Image references are configured as `repo:tag@sha256:...` so deployments are immutable by default.

---

## Health checks

```bash
curl -f http://localhost:3000/actuator/health
curl -f http://localhost:9000/actuator/health
curl -I http://localhost:8080/
```

---

## Compose file responsibilities

- `docker-compose.yml`: production-safe baseline.
- `docker-compose.local.yml`: local source builds + local economy plugin jar.
- `docker-compose.test.yml`: staging/test CI-tagged immutable images + local test-built economy plugin jar.

## License

MIT. See [`LICENSE`](./LICENSE).

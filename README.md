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

## 1) Local development flow

Use local build contexts for Java/UI services and a locally built Minecraft economy plugin jar.

### Build the economy plugin locally

```bash
scripts/build-economy-plugin.sh ../craftalism-economy
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

Notes:
- Test overrides replace service images with commit-tagged CI images.
- Test still uses a locally built economy plugin artifact (mounted jar), not release download transport.
- Commit metadata is attached as labels/environment values so the running commit is obvious.

---

## 3) Production flow

Production uses `docker-compose.yml` only.

```bash
docker compose pull
docker compose up -d
```

Production requirements:
- Set immutable release tags in `.env` (`AUTH_SERVER_VERSION`, `API_VERSION`, `DASHBOARD_VERSION`, `ECONOMY_VERSION`).
- Do **not** use `latest`.
- Economy plugin is downloaded from GitHub Releases using `ECONOMY_VERSION` (release artifact path).
- For maximum immutability, pin image digests (`image: repo:tag@sha256:...`) as a future hardening step.

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

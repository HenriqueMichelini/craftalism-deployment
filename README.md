# Craftalism Deployment

Docker Compose orchestration for the Craftalism platform with **explicitly separated workflows**:

1. **Local development** (`docker-compose.yml` + `docker-compose.local.yml`)
2. **Staging / test** (`docker-compose.yml` + `docker-compose.test.yml`)
3. **Production** (`docker-compose.yml` with the `production` profile)

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

Set required secrets and issuer config (`DB_PASSWORD`, `MINECRAFT_CLIENT_SECRET`, `RSA_PRIVATE_KEY`, `RSA_PUBLIC_KEY`, `AUTH_ISSUER_URI`, etc.) in `.env`.

Production also requires the edge proxy settings:

- `CADDY_VERSION` / `CADDY_DIGEST`
- `DASHBOARD_SITE_ADDRESS`
- `AUTH_SITE_ADDRESS`
- `DASHBOARD_BASIC_AUTH_USERNAME`
- `DASHBOARD_BASIC_AUTH_PASSWORD_HASH`

Generate the dashboard password hash with:

```bash
docker run --rm caddy:2.9-alpine caddy hash-password --plaintext 'strong-password'
```

When you paste the hash into `.env`, escape each `$` as `$$` so Docker Compose keeps the bcrypt hash literal.

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
```

If your layout differs, set `*_BUILD_CONTEXT`, `*_DOCKERFILE`, and `ECONOMY_PLUGIN_JAR` explicitly in `.env` (or exported environment variables).

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
- `./test`: ensures local plugin jar exists, auto-populates CI tag env vars from current git branch/sha if absent, provides safe defaults for base-compose required vars, resolves/pulls base images, and for app services falls back to local `*:local` images when remote CI tags are unavailable.
- `./test down`: stops/removes the test stack with test compose overrides.
- `./prod`: optionally refreshes pinned image digests into `.env`, pre-pulls production images, then starts production compose with the `production` profile.
- `./prod down`: stops/removes the production stack.

Optional behavior flags:
- `SKIP_DIGEST_REFRESH=1 ./prod` to skip automatic digest refresh.
- `CLEAN_PLUGIN_BUILD=1 ./local` to force clean plugin build via bootstrap.
- `LOCAL_BUILD_RETRIES=5 ./local` to retry transient local docker builds (default: 3 attempts).
- `scripts/resolve-image-digests.sh --env-file .env --mode test --write` to resolve only digests needed by `./test`.

---

## 1) Local development flow

Use local build contexts for Java/UI services and a locally built Minecraft economy plugin jar.

### Build the economy plugin locally

```bash
scripts/build-economy-plugin.sh ../craftalism-economy/java
```

For a forced clean rebuild when plugin metadata/dependencies changed:

```bash
scripts/build-economy-plugin.sh --clean ../craftalism-economy/java
```

This produces:

- `.local-dev/craftalism-economy.jar`

### Run local stack

```bash
export AUTH_SERVER_BUILD_CONTEXT=../craftalism-authorization-server
export API_BUILD_CONTEXT=../craftalism-api
export DASHBOARD_BUILD_CONTEXT=../craftalism-dashboard
export ECONOMY_PLUGIN_JAR=$PWD/.local-dev/craftalism-economy.jar
# Optional if your repos use non-standard Dockerfile locations:
# export AUTH_SERVER_DOCKERFILE=java/Dockerfile
# export API_DOCKERFILE=java/Dockerfile
# export DASHBOARD_DOCKERFILE=react/Dockerfile


docker compose -f docker-compose.yml -f docker-compose.local.yml up --build
```

Notes:
- The compose local override builds `auth-server`, `api`, and `dashboard` from local source paths.
- Minecraft plugin uses local jar mount (`/data/plugins/craftalism-economy.jar`) and does **not** use GitHub Releases in local mode.
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

Production uses the base compose file plus the `production` profile, which enables the edge proxy.

```bash
scripts/prepull-images.sh production
docker compose --profile production up -d
```

Production requirements:
- Publicly expose only `80`, `443`, and `25565` at the EC2/security-group layer. Keep `9000`, `3000`, `8080`, and `25575` private.
- Set immutable release tags in `.env` (`AUTH_SERVER_VERSION`, `API_VERSION`, `DASHBOARD_VERSION`, `ECONOMY_VERSION`).
- Set pinned image digests in `.env` (`CADDY_DIGEST`, `AUTH_SERVER_DIGEST`, `API_DIGEST`, `DASHBOARD_DIGEST`, `POSTGRES_DIGEST`, `MINECRAFT_IMAGE_DIGEST`).
- Do **not** use `latest` or unpinned image references.
- Economy plugin is downloaded from GitHub Releases using `ECONOMY_VERSION` (release artifact path).
- Image references are configured as `repo:tag@sha256:...` so deployments are immutable by default.
- The edge proxy terminates HTTPS, protects the dashboard with HTTP basic auth, and routes the public auth hostname to the authorization server.
- `./prod up` fails fast and prints missing variable names when required production configuration is not set.

---

## Health checks

```bash
curl -u "${DASHBOARD_BASIC_AUTH_USERNAME}:<dashboard-password>" -I "https://${DASHBOARD_SITE_ADDRESS}/"
curl -f "https://${AUTH_SITE_ADDRESS}/actuator/health"
```

---

## Compose file responsibilities

- `docker-compose.yml`: production-safe baseline with internal-only service ports and the production edge profile.
- `docker-compose.local.yml`: local source builds + direct local port publishing + local economy plugin jar.
- `docker-compose.test.yml`: staging/test CI-tagged immutable images + direct test port publishing + local test-built economy plugin jar.

## License

MIT. See [`LICENSE`](./LICENSE).

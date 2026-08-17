# Craftalism Deployment

Docker Compose orchestration for the Craftalism platform. This repository owns service wiring, environment alignment, runtime limits, image selection, and the helper scripts used to run the stack in three modes:

| Mode | Compose files | Application artifacts | Main command |
| --- | --- | --- | --- |
| Local development | `docker-compose.yml` + `docker-compose.local.yml` | Sibling source checkouts and locally built plugin JARs | `./local` |
| Staging/test | `docker-compose.yml` + `docker-compose.test.yml` | Branch/commit-tagged application images and locally built plugin JARs | `./test` |
| Production | `docker-compose.yml` | Released, digest-pinned images and released plugin JARs | `./prod` |

The baseline stack contains PostgreSQL, a one-shot auth database initializer, the authorization server, API, dashboard BFF, dashboard, a one-shot Minecraft configuration initializer, and the Paper Minecraft server. An optional Caddy service is available through the `standalone-edge` Compose profile; the normal production path uses the host edge managed by `craftalism-infra`.

## Prerequisites

- Bash, Git, and `curl`
- Docker Engine with the Docker Compose v2 plugin (`docker compose`)
- Network and registry access for the images, releases, and repositories used by the selected mode
- JDK 21 for local economy and market plugin builds; the build scripts use each sibling project's Gradle wrapper
- Optional: Node.js 20 to run the dashboard BFF unit tests directly
- Optional: Tailscale for tailnet-only local access

## Configuration

Create the base environment file:

```bash
cp env.example .env
```

`env.example` is a template. Replace its placeholder values before running the stack. In particular:

- Production requires immutable versions and valid SHA-256 digests for the auth server, API, dashboard, PostgreSQL, and Minecraft images.
- Production also requires released `ECONOMY_VERSION` and `MARKET_VERSION` values.
- Set real values for `DB_PASSWORD`, `DASHBOARD_BFF_CLIENT_SECRET`, `MINECRAFT_CLIENT_SECRET`, `RCON_PASSWORD`, `AUTH_ISSUER_URI`, `RSA_PRIVATE_KEY`, and `RSA_PUBLIC_KEY`.
- PEM keys must be stored on one line with literal `\n` separators, as shown in `env.example`.
- `DASHBOARD_BFF_CLIENT_SECRET` must match the confidential `dashboard-bff` client registered by the authorization server. It is server-side configuration and must not be exposed to browser runtime configuration.

For non-production use, the authorization server can generate ephemeral RSA keys when `RSA_ALLOW_EPHEMERAL=true` and both RSA key values are empty. Production validation rejects missing or placeholder key material.

### Local overrides

Create the optional local override file:

```bash
cp .env.local.example .env.local
```

`./local` loads `.env` and then applies supported values from `.env.local`, including the internal issuer and API URLs. This keeps container-network values such as `http://craftalism-auth-server:9000` out of production configuration. The helper creates `.env` and `.env.local` from their examples when absent, but generated files still contain development placeholders that you must review.

The local stack still pulls PostgreSQL and Minecraft by digest. Resolve those two base-image digests before the first local run:

```bash
scripts/resolve-image-digests.sh --env-file .env --mode test --write
```

This command pulls the images and updates `POSTGRES_DIGEST` and `MINECRAFT_IMAGE_DIGEST` in `.env`.

### Sibling repository layout

The default local build expects these sibling checkouts:

```text
<parent-dir>/
  craftalism-deployment/
  craftalism-authorization-server/
    java/
  craftalism-api/
    java/
  craftalism-dashboard/
    react/
  craftalism-economy/
    java/
  craftalism-market/
    java/
```

`./local` runs `scripts/bootstrap-local-dev.sh`. Missing siblings are cloned; existing siblings are fetched, switched to the configured branch, and fast-forwarded when that branch exists on `origin`. The default branch is `main`. Set `AUTH_SERVER_BRANCH`, `API_BRANCH`, `DASHBOARD_BRANCH`, `ECONOMY_BRANCH`, or `MARKET_BRANCH` before running the command when another branch is required, and preserve any uncommitted sibling-repository work first.

If the directory layout differs, set `AUTH_SERVER_BUILD_CONTEXT`, `API_BUILD_CONTEXT`, `DASHBOARD_BUILD_CONTEXT`, `AUTH_SERVER_DOCKERFILE`, `API_DOCKERFILE`, and `DASHBOARD_DOCKERFILE`. Set `ECONOMY_PLUGIN_JAR` and `MARKET_PLUGIN_JAR` when the plugin artifacts are outside `.local-dev/`.

## Local development

Start the full local stack from this repository:

```bash
./local
```

The command bootstraps the five sibling repositories, builds both plugin JARs, builds the auth server, API, dashboard, and dashboard BFF images from local source, and runs Compose in the foreground. Stop and remove the stack with:

```bash
./local down
```

For a focused rebuild without restarting dependencies:

```bash
./local hot dashboard
./local hot api
./local hot minecraft
```

`./local hot minecraft` rebuilds the economy and market plugins, refreshes them in the persistent Minecraft volume, and recreates only the Minecraft container. Use `CLEAN_PLUGIN_BUILD=1 ./local` or `CLEAN_PLUGIN_BUILD=1 ./local hot minecraft` when Gradle metadata or dependencies changed. `LOCAL_BUILD_RETRIES` controls full-stack build/start attempts and defaults to `3`.

To build the plugins without starting Compose:

```bash
scripts/build-economy-plugin.sh ../craftalism-economy
scripts/build-market-plugin.sh ../craftalism-market
```

Pass `--clean` before the repository path for a clean Gradle build. The outputs are:

- `.local-dev/craftalism-economy.jar`
- `.local-dev/craftalism-market.jar`

For direct IDE work, start only PostgreSQL, the auth initializer, auth server, and API:

```bash
scripts/start-local-deps.sh up
scripts/start-local-deps.sh down
```

Unlike `./local`, this helper reads Compose's `.env` values and does not apply `.env.local`; export any required container-network overrides before using it.

### Dashboard BFF

Dashboard mutations are routed through the deployment-owned `dashboard-bff`. It obtains scoped OAuth client-credentials tokens and forwards only its explicit route allowlist. Ordinary API reads are proxied without adding that credential; the market event and event-template administration reads use the market-admin scope.

The local dashboard is available at `http://localhost:8080/`. The write path is:

```text
browser -> dashboard /api/dashboard/... -> dashboard-bff -> auth-server /oauth2/token -> API
```

The BFF health endpoint is internal to the Compose network at `/health`; inspect it with `docker compose ps` or container logs.

## Staging/test

The staging workflow builds application images tagged with the normalized branch name and the deployment commit's seven-character SHA, for example `main-a1b2c3d`. It runs for pull requests and pushes targeting `main` or `feature/**`, and can also be dispatched manually. The workflow validates shell syntax, repository hygiene, Compose interpolation, builds the three application images, builds both plugins, and runs the Compose smoke flow.

When the target GHCR packages are owned by the service repositories, configure the Actions secret `GHCR_PUSH_TOKEN` with package write access and, optionally, `GHCR_USERNAME`. The workflow otherwise falls back to `GITHUB_TOKEN`.

Run the test stack with:

```bash
./test
```

The helper:

- derives missing `*_CI_TAG` and `*_GIT_SHA` values from the current deployment branch and commit;
- builds either plugin JAR when its `.local-dev` artifact is missing;
- refreshes the PostgreSQL and Minecraft digests in `.env` unless `SKIP_TEST_DIGEST_REFRESH=1`;
- pulls the application CI images, falling back to the corresponding `*:local` image when available; and
- starts the merged test Compose stack in detached mode.

`./test` reads `.env`, not `.env.local`. Ensure `.env` or exported variables contain test-appropriate internal auth configuration and usable RSA configuration. To use ephemeral keys for a disposable test stack, set `RSA_ALLOW_EPHEMERAL=true` and leave `RSA_PRIVATE_KEY` and `RSA_PUBLIC_KEY` empty.

Override the automatically derived tags when testing published images from another build:

```bash
export AUTH_SERVER_CI_TAG=main-a1b2c3d
export API_CI_TAG=main-a1b2c3d
export DASHBOARD_CI_TAG=main-a1b2c3d
./test
```

Run the end-to-end smoke check after the stack is healthy. The supplied secret must match the configured Minecraft OAuth client:

```bash
MINECRAFT_CLIENT_SECRET='test-secret' scripts/smoke-test.sh
```

Stop the test stack with `./test down`.

## Production

The supported production path is the `./prod` wrapper. It validates required values, placeholder values, immutable digests, runtime memory budgets, and market rate-limit settings before changing the stack.

Review the resolved Compose configuration first:

```bash
./prod config
```

Start or update the full production stack:

```bash
./prod
```

By default, this resolves the configured application and base-image tags, writes their current digests to `.env`, reuses the pulled images, and starts the stack in detached mode. Use `SKIP_DIGEST_REFRESH=1 ./prod` only when `.env` already contains the intended pinned digests.

After changing one released application version in `.env`, deploy only that service:

```bash
./prod deploy auth-server
./prod deploy api
./prod deploy dashboard
```

The targeted deploy resolves only that application's digest, replaces its container without restarting dependencies, waits up to 120 seconds for health, and verifies the active image reference. Set `PROD_DEPLOY_WAIT_TIMEOUT` to change the timeout.

Other production commands:

```bash
./prod ps
./prod down
scripts/monitor-platform.sh
scripts/monitor-platform.sh --watch=3
```

### Production network and runtime requirements

- The default auth server, API, and dashboard bindings are `127.0.0.1:9000`, `127.0.0.1:3000`, and `127.0.0.1:8080` respectively. `craftalism-infra` owns the public proxy, TLS termination, and dashboard basic auth on the normal EC2 path.
- Expose only HTTP/HTTPS and Minecraft (`80`, `443`, and `25565`) at the EC2 security-group layer. Keep `9000`, `3000`, `8080`, and RCON `25575` private.
- The optional `standalone-edge` profile uses this repository's `Caddyfile`. Configure `DASHBOARD_SITE_ADDRESS`, `AUTH_SITE_ADDRESS`, `API_SITE_ADDRESS`, `DASHBOARD_BASIC_AUTH_USERNAME`, a Caddy-compatible `DASHBOARD_BASIC_AUTH_PASSWORD_HASH`, and a pinned `CADDY_IMAGE` before enabling it. The included file also has an unauthenticated `localhost` dashboard site for local access, so this profile is not equivalent to the infra-managed production access-control boundary as written.
- Economy and market plugins are downloaded from GitHub Releases. Extra URLs in `MINECRAFT_EXTRA_PLUGIN_URLS` must point to Paper/Bukkit/Spigot plugins; Forge, Fabric, and NeoForge mods do not run on Paper.
- `minecraft-config-init` writes the market plugin's runtime configuration into the persistent Minecraft volume from the `MARKET_API_*` values before Paper starts.
- Named PostgreSQL, Minecraft, and Caddy data volumes persist across ordinary `down` operations.
- API SpringDoc and Swagger UI default to disabled in production and enabled by the local override.
- Production market request defaults are `120` quote requests and `30` execute requests per `60` seconds. A max-request value of `0` disables that limiter intentionally.

`CRAFTALISM_RUNTIME_PROFILE=small-host` is the default and applies conservative limits intended for a hobby-scale `t3.small`. `CRAFTALISM_RUNTIME_PROFILE=standard` raises several service budgets for larger hosts. Per-service variables in `.env` override profile defaults, and `./prod` rejects memory configurations that do not fit their container limits. See [`docs/api-production-runtime-guardrails.md`](docs/api-production-runtime-guardrails.md) for API-specific tuning details.

Enable the repository-owned edge explicitly for a standalone environment:

```bash
COMPOSE_PROFILES=standalone-edge ./prod
```

For tailnet-only local access while retaining loopback bindings, see [`docs/tailscale-serve-local.md`](docs/tailscale-serve-local.md). The helpers use Tailscale Serve, not Funnel; API and Minecraft exposure require explicit flags.

## Verification

Run the repository-local static checks from the repository root:

```bash
bash -n local test prod scripts/*.sh diagnostics/runtime-snapshots/snapshot.sh gather-market-config-logs.sh
scripts/check-repository-hygiene.sh
docker compose --env-file env.example -f docker-compose.yml config >/dev/null
node --test dashboard-bff/server.test.js
```

The staging workflow additionally validates the local and test Compose merges and runs `scripts/smoke-test.sh` against the started test stack.

Check the production upstreams directly on the deployment host:

```bash
curl -f 'http://127.0.0.1:9000/actuator/health'
curl -f 'http://127.0.0.1:3000/actuator/health'
curl -I 'http://127.0.0.1:8080/'
```

## License

MIT. See [`LICENSE`](LICENSE).

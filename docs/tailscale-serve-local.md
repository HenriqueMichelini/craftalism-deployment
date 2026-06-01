# Local Tailnet Access With Tailscale Serve

## Purpose

Expose local Craftalism services to devices in the same Tailscale tailnet without
changing the Docker loopback-only bindings or enabling public internet access.

The default local Docker bindings remain:

```text
127.0.0.1:8080 -> dashboard:80
127.0.0.1:3000 -> api:8080
0.0.0.0:25565 -> minecraft:25565
```

Because the dashboard and API ports listen only on `127.0.0.1`, a direct request such as
`http://<tailscale-ip>:8080/` cannot reach the dashboard. This is intentional:
those HTTP services are not exposed on every host interface.

Tailscale Serve is the operator-controlled proxy from the tailnet to the local
services. Do not use Tailscale Funnel for this workflow. Funnel exposes services
to the public internet.

Minecraft retains its deployment port binding because production clients connect
to it directly. The optional TCP Serve mapping adds a tailnet path; it does not
make the Minecraft port tailnet-only.

## Commands

Start the dashboard proxy:

```bash
scripts/tailscale-serve-up.sh
```

Start the dashboard proxy and optionally expose the API directly:

```bash
scripts/tailscale-serve-up.sh --api
```

Start the dashboard proxy and expose Minecraft over TCP:

```bash
scripts/tailscale-serve-up.sh --minecraft
```

The options can be combined when both direct API and Minecraft access are
needed.

Show the current Serve configuration and the tailnet URLs:

```bash
scripts/tailscale-serve-status.sh
```

Disable the Craftalism Serve mappings:

```bash
scripts/tailscale-serve-down.sh
```

The scripts use the local deployment ports by default. Set `DASHBOARD_PORT`,
`API_PORT`, or `MINECRAFT_PORT` when the Compose port overrides differ from
`8080`, `3000`, or `25565`.

## Dashboard API Behavior

The dashboard container rewrites its default localhost API URL to same-origin
`/api`. Nginx then proxies `/api/*` through the deployment-owned dashboard BFF
and API wiring inside Docker. As a result, remote dashboard use normally needs
only the dashboard Serve mapping.

The optional API mapping is useful for direct API inspection from another
tailnet device. It also exposes API routes to any tailnet principal permitted by
the Tailscale access-control policy, so enable it only when needed.

If runtime configuration is changed to use an absolute browser-visible API URL,
do not use `http://localhost:3000`: in a remote browser, `localhost` refers to
the remote device. Prefer the existing same-origin `/api` path.

## Validation

Verify the local services before enabling Serve:

```bash
curl -fsS http://localhost:8080/ >/dev/null
curl -fsS http://localhost:3000/actuator/health
nc -z -w 2 localhost 25565
```

Verify that Docker still publishes loopback-only ports:

```bash
ss -ltnp | rg '(127\.0\.0\.1:(8080|3000)|:25565)'
docker ps | rg '(127\.0\.0\.1:(8080|3000)|:25565)'
```

After starting Serve, obtain the actual tailnet URLs from:

```bash
scripts/tailscale-serve-status.sh
```

Use the reported dashboard URL from another device in the same tailnet. Connect
Minecraft to the reported Tailscale DNS name on port `25565`. The DNS name is
intentionally not hard-coded because it belongs to the local Tailscale node
configuration.

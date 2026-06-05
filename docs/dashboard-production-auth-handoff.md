# Dashboard Production Auth Handoff

## Ownership

- `craftalism-deployment` owns the compose-managed dashboard upstream on `127.0.0.1:8080` and the optional standalone edge profile.
- `craftalism-infra` owns the production public edge for `https://dashboard.craftalism.com`, including the auth gate in front of that upstream.

## Problem

`https://dashboard.craftalism.com` is currently reachable without the expected login challenge.

This is a regression from the previous production behavior, where the dashboard
presented an auth prompt before proxying to the dashboard container.

## Confirmed Boundary

This repository does not own production public edge auth for the normal EC2
deployment path.

Confirmed evidence in `craftalism-deployment`:

- [README.md](/home/ubuntu/craftalism-deployment/README.md:44) says production runs behind the host proxy from `craftalism-infra`.
- [README.md](/home/ubuntu/craftalism-deployment/README.md:241) says public edge, TLS, and dashboard basic auth are expected to be owned by `craftalism-infra`.
- [README.md](/home/ubuntu/craftalism-deployment/README.md:276) says `craftalism-infra` owns the public edge proxy, TLS termination, and dashboard basic auth for the EC2 deployment path.
- [env.example](/home/ubuntu/craftalism-deployment/env.example:16) keeps the dashboard published only on loopback for that infra-managed model.

The compose-managed dashboard service is still expected to be available only as
the upstream:

```text
127.0.0.1:8080 -> craftalism-dashboard
```

If production no longer prompts for login, the missing protection is in the
host edge configuration owned by `craftalism-infra`.

## Required Infra Change

In `craftalism-infra`, restore the auth gate for:

```text
https://dashboard.craftalism.com
```

before proxying to:

```text
http://127.0.0.1:8080
```

The previous user-visible behavior was a browser login prompt. Reintroduce the
same protection model there unless infra has intentionally migrated to a
different edge auth mechanism with equivalent protection.

## Validation

Before the fix:

```text
curl -I https://dashboard.craftalism.com/
HTTP 200
```

Expected after the fix:

```text
curl -I https://dashboard.craftalism.com/
HTTP 401
WWW-Authenticate: Basic realm=...
```

Then verify authenticated access still succeeds and the dashboard loads through
the existing upstream on `127.0.0.1:8080`.

## Related Repo-Local Cleanup

This repo also had a separate standalone-edge bug: the optional Caddy profile
accepted `DASHBOARD_BASIC_AUTH_USERNAME` and
`DASHBOARD_BASIC_AUTH_PASSWORD_HASH` but did not enforce them in
`Caddyfile`.

That repo-local issue is fixed here for the standalone profile only. It does
not fix the production regression on `dashboard.craftalism.com`.

# Market Events Dashboard BFF Mutation Handoff

## Issue

Creating a Market Event from the dashboard fails with:

```text
POST /api/dashboard/market/events -> 403 Forbidden
```

## Confirmed Boundary

The rejection occurs in the deployment-owned `dashboard-bff`, before the
request reaches `craftalism-api`.

The BFF already proxies:

```text
GET /api/dashboard/market/events
```

with an OAuth token requested using:

```text
scope=market:admin
```

However, Market Events mutations are absent from the BFF write allowlist.
Unapproved writes under `/api/**` are intentionally rejected with `403`.

## Required Deployment Change

In `craftalism-deployment/dashboard-bff/server.js`, approve and forward:

```text
POST  /api/dashboard/market/events
PATCH /api/dashboard/market/events/{id}
POST  /api/dashboard/market/events/{id}/cancel
POST  /api/dashboard/market/events/supersede
```

These routes must obtain and forward a Bearer token with:

```text
scope=market:admin
```

Do not use the generic `api:write` token for these routes. Do not expose the
dashboard BFF client secret or token to browser code.

## Deployment Step

Rebuild and recreate the `dashboard-bff` service after the source change.

## Validation Evidence

Current live probes:

```text
dashboard-bff POST /api/dashboard/market/events -> 403 Forbidden
auth-server token request scope=market:admin     -> 200
```

After the fix, validate the four mutation route mappings in
`dashboard-bff/server.test.js`, recreate the sidecar, and confirm a dashboard
Market Event create request reaches `craftalism-api` with `market:admin`.

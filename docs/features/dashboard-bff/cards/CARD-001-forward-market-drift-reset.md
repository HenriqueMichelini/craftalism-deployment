# CARD-001: Forward Market Drift Reset

## Status

completed

## Objective

Forward the confirmed dashboard market drift reset mutation through the deployment-owned dashboard BFF with the required market admin OAuth scope.

## Context

`craftalism-api` exposes `POST /api/dashboard/market/drift/reset` for callers with `SCOPE_market:admin`, and the dashboard calls that route. The deployment-owned dashboard BFF currently rejects the mutation before it reaches the API because the route is absent from its authenticated write allowlist.

## Required Reading

- `../../../market-events-dashboard-bff-mutation-handoff.md`
- `../../../../dashboard-bff/server.js`
- `../../../../dashboard-bff/server.test.js`

## Expected Behavior

The dashboard BFF accepts `POST /api/dashboard/market/drift/reset`, obtains a server-side token with `scope=market:admin`, and forwards the request to the same API path without exposing credentials to browser code.

## Acceptance Criteria

- [x] `POST /api/dashboard/market/drift/reset` is an approved authenticated BFF write route.
- [x] The route forwards to `/api/dashboard/market/drift/reset`.
- [x] The route requests `scope=market:admin`, matching the API-owned authorization contract.
- [x] Direct API writes and unrelated unapproved dashboard mutations remain rejected by the existing default-deny behavior.
- [x] A targeted BFF test covers the drift reset route mapping and scope.
- [x] A recreated local BFF forwards the drift reset mutation past the BFF instead of returning the BFF's plain-text `403 Forbidden`.

## Expected Files to Change

```text
dashboard-bff/server.js
dashboard-bff/server.test.js
docs/features/dashboard-bff/cards/CARD-001-forward-market-drift-reset.md
```

## Constraints

- Do not change the API-owned drift reset semantics or authorization contract.
- Do not expose the dashboard BFF client secret or access token to browser code.
- Do not broaden public `/api/market/**` routes.
- Do not refactor unrelated dashboard BFF mappings.

## Validation Commands

```bash
rtk node --test dashboard-bff/server.test.js
rtk docker compose -f docker-compose.yml -f docker-compose.local.yml up -d --build --force-recreate dashboard-bff dashboard
rtk curl -i -X POST http://localhost:8080/api/dashboard/market/drift/reset
```

The live probe passes when it reaches the API-authenticated route and returns a JSON API response rather than the BFF's plain-text `403 Forbidden`.

## Out of Scope

- API drift reset implementation or persistence behavior.
- Dashboard UI behavior.
- Market event mutation mappings.

## Completion Notes

Added the scoped dashboard BFF route and its targeted matcher test. Rebuilt the
local BFF and confirmed that `POST /api/dashboard/market/drift/reset` returns
the API JSON response with `resetItemCount`, neutral
`driftMultiplierBasisPoints`, and `driftEvaluatedAt`.

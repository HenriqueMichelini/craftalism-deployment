# CARD-002: Forward Market Event Template Admin Routes

## Status

completed

## Objective

Forward the confirmed dashboard market event template list and create routes through the deployment-owned dashboard BFF with the required market admin OAuth scope.

## Context

`craftalism-api` exposes `GET` and `POST /api/dashboard/market/event-templates` for callers with `SCOPE_market:admin`. The authorization server already allows the confidential `dashboard-bff` client to request `market:admin`, but the deployment-owned BFF has no allowlist entries for these template routes. Without explicit mappings, the read would be proxied without an access token and the create mutation would be rejected by the BFF's default-deny write behavior.

## Required Reading

- `../../../../dashboard-bff/server.js`
- `../../../../dashboard-bff/server.test.js`
- `../../../../../craftalism-api/docs/features/market-events/cards/CARD-022-add-dashboard-market-event-template-api.md`
- `../../../../../craftalism-api/java/src/main/java/io/github/HenriqueMichelini/craftalism/api/controller/DashboardMarketEventTemplateController.java`
- `../../../../../craftalism-api/java/src/main/java/io/github/HenriqueMichelini/craftalism/api/config/SecurityConfig.java`
- `../../../../../craftalism-authorization-server/docs/features/market-events/contract.md`

## Expected Behavior

The dashboard BFF accepts template list and create requests, obtains a server-side token with `scope=market:admin`, and forwards each request to the same API path without exposing credentials to browser code.

## Acceptance Criteria

- [ ] `GET /api/dashboard/market/event-templates` is an approved authenticated BFF read route.
- [ ] `POST /api/dashboard/market/event-templates` is an approved authenticated BFF write route.
- [ ] Both routes forward to `/api/dashboard/market/event-templates`.
- [ ] Both routes request `scope=market:admin`, matching the API-owned authorization contract.
- [ ] Direct API writes and unrelated unapproved dashboard mutations remain rejected by the existing default-deny behavior.
- [ ] Targeted BFF tests cover both template route mappings and scopes.
- [ ] A recreated local BFF forwards template list and create requests past the BFF instead of returning an unauthenticated API response or the BFF's plain-text `403 Forbidden`.

## Expected Files to Change

```text
dashboard-bff/server.js
dashboard-bff/server.test.js
docs/features/dashboard-bff/cards/CARD-002-forward-market-event-template-admin-routes.md
```

## Constraints

- Do not change API-owned template semantics or authorization requirements.
- Do not expose the dashboard BFF client secret or access token to browser code.
- Do not broaden public `/api/market/**` routes.
- Do not add speculative update or delete template mappings.
- Do not refactor unrelated dashboard BFF mappings.

## Validation Commands

```bash
rtk node --test dashboard-bff/server.test.js
rtk docker compose -f docker-compose.yml -f docker-compose.local.yml up -d --build --force-recreate dashboard-bff dashboard
rtk curl -i http://localhost:8080/api/dashboard/market/event-templates
rtk curl -i -X POST http://localhost:8080/api/dashboard/market/event-templates -H 'Content-Type: application/json' --data '{}'
```

The live list probe passes when it reaches the API-authenticated route and returns a JSON API response rather than an API `401`. The live create probe passes when it reaches API validation and returns a JSON API response rather than the BFF's plain-text `403 Forbidden`.

## Out of Scope

- API template implementation, schema, validation, persistence, scheduler, pricing, blocking, or lifecycle behavior
- Dashboard template table or form behavior
- Authorization-server seeded-client changes
- Template update or delete mappings

## Completion Notes

- Added authenticated `GET` and `POST` dashboard BFF mappings for
  `/api/dashboard/market/event-templates`.
- Both mappings forward to the same API path with `scope=market:admin`.
- Added targeted matcher coverage for both mappings, optional trailing slashes,
  and the existing default-deny behavior for unapproved template deletes.
- Validation passed: `rtk node --test dashboard-bff/server.test.js`.
- Validation passed: `rtk git diff --check`.
- The declared compose recreation command rebuilt the dashboard BFF image but
  could not start the local stack because the pre-existing persisted Postgres
  volume rejected the configured `craftalism` password during `auth-db-init`.
- Isolated localhost BFF smoke probes passed without resetting the persisted
  database volume: template list forwarded with a server-side bearer token and
  returned JSON `200`; template create forwarded with a server-side bearer
  token and returned JSON `422`; an unapproved template delete remained the
  BFF's plain-text `403 Forbidden`.

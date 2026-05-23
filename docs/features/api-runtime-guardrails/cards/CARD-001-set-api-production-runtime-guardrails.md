# CARD-001: Set API Production Runtime Guardrails

## Status

implemented

## Objective

Set deployment-owned production guardrails that give the API a sane JVM/native/metaspace budget, reduce unnecessary production runtime surface, and bound market request pressure.

## Context

Confirmed production evidence shows `craftalism-api` terminated with `java.lang.OutOfMemoryError: Metaspace` at `2026-05-23T03:37:42Z` during market buy spam. The API was running with tight JVM settings: `-Xms48m -Xmx144m -Xss512k -XX:+UseSerialGC -XX:MaxMetaspaceSize=96m -XX:ReservedCodeCacheSize=48m -XX:+ExitOnOutOfMemoryError`.

Market plugin `1.1.1` and API `1.1.1` logs showed repeated accepted `market.trade.quote.request` calls and `STALE_QUOTE` retry refreshes before the API failure, followed by correct plugin degraded-mode and read-only click rejection behavior after the API failed. API market rate-limit properties default to unlimited unless configured: `MARKET_QUOTE_RATE_LIMIT_MAX_REQUESTS=0`, `MARKET_EXECUTE_RATE_LIMIT_MAX_REQUESTS=0`, and `MARKET_RATE_LIMIT_WINDOW_SECONDS=60`.

The API includes and exposes SpringDoc/Swagger; production logs warn it is enabled by default. Disabling it by default in production is an appropriate deployment-owned runtime surface reduction while preserving local and development API docs behavior.

This repository owns runtime composition, JVM options, environment examples/profiles, validation, and operator-facing deployment documentation. API code behavior remains owned by `craftalism-api` only if metaspace continues growing after sane deployment settings are in place.

## Required Reading

- `craftalism/docs/governance-precedence.md`
- `craftalism/docs/system-summary.md`
- `craftalism/docs/contracts/market-contract.md`
- `craftalism/docs/standards/security-access-control.md`
- `craftalism/docs/standards/testing.md`
- `craftalism/docs/standards/documentation.md`
- `craftalism-deployment/AGENTS.md`
- `craftalism-deployment/docs/repo-contract-map.md`
- `craftalism-deployment/docs/repo-requirement-pack.md`

## Expected Behavior

Production deployment defaults and validation give `craftalism-api` enough JVM, metaspace, code cache, thread stack, and native headroom for a Spring Boot API under expected market traffic, without silently exceeding the container memory limit.

Production deployment disables SpringDoc/Swagger UI by default for the API while local and development overlays can still expose API docs intentionally.

Production deployment configures bounded market quote and execute rate-limit environment defaults so market spam cannot remain unlimited by omission. The configured values must be operator-visible, documented, and propagated through compose/runtime configuration without changing the API-owned rate-limit semantics.

Deployment validation and operator docs cover the API JVM budget, SpringDoc production default, and market rate-limit environment knobs.

## Acceptance Criteria

- [ ] Production API JVM options use an explicit sane floor for a Spring Boot API, including heap, metaspace, code cache, stack size, and OOM exit behavior.
- [ ] The API JVM/native budget validation accounts for heap, metaspace, reserved code cache, thread stack, and required native/container headroom.
- [ ] Production API memory limits/reservations and JVM defaults remain internally consistent and preserve container headroom.
- [ ] Production compose/runtime configuration disables API SpringDoc/Swagger UI by default.
- [ ] Local and development behavior can still enable or expose SpringDoc/Swagger intentionally.
- [ ] Production market quote and execute rate-limit environment defaults are bounded instead of unlimited-by-omission.
- [ ] `MARKET_QUOTE_RATE_LIMIT_MAX_REQUESTS`, `MARKET_EXECUTE_RATE_LIMIT_MAX_REQUESTS`, and `MARKET_RATE_LIMIT_WINDOW_SECONDS` are documented as deployment/runtime guardrails.
- [ ] Compose interpolation or runtime validation fails clearly when the configured API JVM budget cannot fit within the API memory limit.
- [ ] Operator docs describe why the API production JVM budget changed, why SpringDoc is disabled in production, and how to tune the market rate-limit knobs.
- [ ] Validation confirms the production compose configuration renders the intended API JVM options and environment values.

## Expected Files to Change

```text
docker-compose.yml
env.example
prod
scripts/runtime-profile.sh
scripts/smoke-test.sh
diagnostics/runtime-snapshots/snapshot.sh
README.md
docs/
```

Adjust this list during implementation if the same behavior is already centralized elsewhere in deployment-owned scripts or docs.

## Constraints

- Do not modify API source code, API rate-limit implementation, plugin retry behavior, dashboard behavior, or auth behavior.
- Do not change market quote, execute, stale quote, rejection payload, or degraded-mode semantics.
- Do not weaken protected write authentication or issuer alignment.
- Keep production SpringDoc/Swagger disabled by default without removing local/dev API docs support.
- Keep rate-limit defaults deployment-owned and configurable; do not hard-code API business policy in documentation only.
- Preserve container memory headroom rather than only raising JVM limits.
- Do not overwrite unrelated local edits or untracked audit artifacts.
- Keep the implementation in one focused deployment-runtime PR.

## Validation Commands

```bash
rtk ./prod config
rtk ./prod config | rg 'API_JAVA_TOOL_OPTIONS|MaxMetaspaceSize|ReservedCodeCacheSize|SPRINGDOC|MARKET_.*RATE_LIMIT'
rtk ./prod up -d
rtk ./prod ps
rtk ./scripts/smoke-test.sh
rtk ./diagnostics/runtime-snapshots/snapshot.sh
```

If production startup is not available locally, run the largest safe subset:

```bash
rtk ./prod config
rtk ./test
```

Record any skipped command and reason in completion notes.

## Out of Scope

- Investigating or fixing API classloader/metaspace leaks in `craftalism-api`.
- Changing API market rate-limit semantics, rejection codes, payloads, or persistence.
- Changing `craftalism-market` retry, stale quote refresh, degraded-mode, or read-only click behavior.
- Adding distributed rate-limit infrastructure such as Redis.
- Changing public API routes, auth scopes, issuer behavior, dashboard writes, or Minecraft plugin UX.
- Tuning Minecraft server memory or unrelated service JVM budgets except where validation shared code requires API-specific handling.

## Completion Notes

Implemented in `craftalism-deployment` only.

- Set production API JVM defaults to explicit heap, metaspace, code cache, thread stack, and OOM-exit settings; the small-host API profile now uses the measured steady-state values from the `craftalism-api:1.1.2` diagnostics handoff: `-Xms48m -Xmx144m -Xss512k -XX:+UseSerialGC -XX:MaxMetaspaceSize=128m -XX:ReservedCodeCacheSize=48m -XX:+ExitOnOutOfMemoryError`.
- Raised the small-host API container limit to `576m` and reservation to `384m`, and kept auth-server production limits/reservations within validated JVM/native budgets.
- Added API SpringDoc/Swagger production disablement and local-development enablement.
- Added bounded deployment-owned market rate-limit defaults and production validation for those knobs.
- Extended production JVM budget validation to account for heap, metaspace, reserved code cache, thread stacks, and native/container headroom.
- Added `./prod config` and `./prod ps` helper actions for card validation/operator use.
- Added operator docs in `docs/api-production-runtime-guardrails.md` and linked them from `README.md`.
- Extended runtime snapshots to capture `ReservedCodeCacheSize`.

Validation performed:

```bash
rtk bash -n local prod scripts/runtime-profile.sh diagnostics/runtime-snapshots/snapshot.sh scripts/smoke-test.sh
rtk ./prod config
rtk ./prod config | rg 'API_JAVA_TOOL_OPTIONS|MaxMetaspaceSize|ReservedCodeCacheSize|SPRINGDOC|MARKET_.*RATE_LIMIT'
rtk docker compose -f docker-compose.yml -f docker-compose.local.yml config | rg 'SPRINGDOC'
API_MEM_LIMIT=512m API_MEM_RESERVATION=256m rtk ./prod config
MARKET_RATE_LIMIT_WINDOW_SECONDS=0 rtk ./prod config
rtk ./prod ps
MINECRAFT_CLIENT_SECRET="$(awk -F= '$1 == "MINECRAFT_CLIENT_SECRET" {sub(/^[^=]*=/, ""); print; exit}' .env.local)" rtk ./scripts/smoke-test.sh
rtk ./diagnostics/runtime-snapshots/snapshot.sh /tmp/api-runtime-guardrails-snapshot
```

`./prod config`, targeted render grep, syntax checks, validation failure checks, `./prod ps`, smoke test, and snapshot completed successfully. `./prod ps`, smoke test, and snapshot required elevated local Docker/loopback access because the sandbox blocked Docker socket or loopback HTTP access.

Skipped `rtk ./prod up -d` to avoid replacing the already-running healthy local stack with production images in the shared workspace.

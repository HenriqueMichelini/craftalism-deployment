# Repo Contract Map: craftalism-deployment

## Repository Role
`craftalism-deployment` is the runtime composition and environment alignment layer for the ecosystem. It owns deployment orchestration, environment consistency, cross-service wiring, and operator-facing automation for local/test/prod flows.

## Owned Contracts
- Runtime/environment alignment rules for composed services
- Deployment-side enforcement/validation of shared environment assumptions where defined by standards

## Consumed Contracts
- `auth-issuer`
  - Must align compose/runtime wiring with the canonical issuer contract
- `ci-cd`
  - Must comply with deployment automation and validation expectations
- `testing`
  - Must support smoke/integration validation expectations where defined
- `documentation`
  - Must keep operator-facing docs and scripts accurate
- Service image/runtime assumptions from API, auth, dashboard, and economy repos

## Local-Only Responsibilities
- Compose file consistency
- Overlay/environment strategy
- Health checks and startup ordering
- Helper scripts for local/test/prod operations
- Runtime defaults and env propagation
- Deployment documentation and reproducibility discipline

## Out of Scope
- Application-level business logic in API/plugin/dashboard/auth repos
- API contract ownership
- Plugin command behavior
- Dashboard UI behavior
- Auth-server token issuance internals
- API persistence model changes

## Compliance Questions
- Does this repo preserve consistent cross-service runtime behavior?
- Are issuer/env defaults aligned across services?
- Are scripts and docs accurate and reproducible?
- Does CI/CD validate deployment behavior meaningfully, or only build/publish artifacts?
- Does the repo reduce or amplify cross-repo configuration drift?

## Success Signal
This repo is compliant when it provides predictable, well-documented, and reproducible environment orchestration that keeps all services aligned at runtime.

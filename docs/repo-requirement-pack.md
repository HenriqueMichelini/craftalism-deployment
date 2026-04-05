# Repo Requirement Pack: craftalism-deployment

## Repo Role
`craftalism-deployment` is the runtime composition and environment alignment layer for the ecosystem. It is responsible for compose/runtime consistency, cross-service wiring, operator-facing automation, and preventing avoidable environment drift across services.

## Owned Contracts
- Runtime/environment alignment rules for composed services
- Deployment-side enforcement/validation of shared environment assumptions where defined by standards

## Consumed Contracts
- `auth-issuer`
  - Align compose/runtime wiring with the canonical issuer contract
- `ci-cd`
  - Meet deployment automation and validation expectations
- `testing`
  - Support smoke/integration validation expectations where defined
- `documentation`
  - Keep operator-facing docs and scripts accurate
- Service image/runtime assumptions from API, auth, dashboard, and economy repos

## Current Priority Areas
- Verify environment defaults do not create cross-service drift
- Verify issuer/env alignment across services
- Verify scripts and overlays are accurate and reproducible
- Improve CI/CD validation if workflows only build/publish without meaningful checks
- Improve operator-facing docs where they drift from real scripts/behavior
- Strengthen startup/runtime validation where configuration mismatches are likely

## Local Requirements
- Keep compose files and overlays consistent
- Keep health checks and startup ordering reliable
- Keep local/test/prod script behavior understandable
- Preserve reproducibility and deployment discipline
- Avoid environment defaults that silently break other repos’ contracts

## Governance Requirements
- Comply with shared `ci-cd`, `testing`, and `documentation` standards
- Treat cross-service runtime consistency as a first-class responsibility
- Do not modify application-level business logic in other repos from this repo

## Out of Scope
- API business logic ownership
- Plugin command behavior
- Dashboard UI behavior
- Auth-server token issuance internals
- API persistence model changes
- Repo-local code changes in other services

## Audit Questions
- Does this repo preserve consistent cross-service runtime behavior?
- Are issuer/env defaults aligned across services?
- Are scripts and docs accurate and reproducible?
- Does CI/CD validate deployment behavior meaningfully, not just publish artifacts?
- Does this repo reduce or amplify cross-repo configuration drift?

## Success Criteria
- Runtime composition is consistent and reproducible
- Environment defaults do not create avoidable contract mismatches
- Docs match scripts and actual behavior
- CI/CD provides meaningful validation signals

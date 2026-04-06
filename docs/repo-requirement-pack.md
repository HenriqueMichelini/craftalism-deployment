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
- `security-access-control`
  - Keep environment/network exposure assumptions explicit and aligned with the shared policy
- Service image/runtime assumptions from API, auth, dashboard, and economy repos

## Current Phase Objective
This phase is limited to:
- verifying runtime/environment alignment behavior owned by this repo
- correcting deployment-local drift that clearly violates shared contracts or standards
- correcting docs only where they directly contradict actual scripts/runtime behavior
- correcting CI/CD or testing gaps only where required standards are clearly violated and materially weaken deployment confidence

This phase is not for changing business logic in service repositories.

## Required This Phase
- Verify owned runtime/environment responsibilities and classify them as:
  - already compliant
  - partially compliant
  - missing
  - incorrectly implemented
- Verify consumed contract alignment, especially issuer/environment wiring
- Implement only confirmed deployment-local gaps
- Verify environment and exposure assumptions are documented accurately
- Fix documentation only where it directly contradicts actual deployment behavior
- Fix CI/CD or testing only where:
  - required standards are clearly violated, and
  - the gap materially weakens confidence in this repo

## Not Required This Phase
- Service business logic changes
- API contract redesign
- Plugin command behavior changes
- Dashboard UI changes
- Auth-server token issuance logic changes
- Broad platform redesign unrelated to deployment-owned responsibilities

## Local Requirements
- Keep compose files and overlays consistent
- Keep health checks and startup ordering reliable
- Keep local/test/prod script behavior understandable
- Preserve reproducibility and deployment discipline
- Avoid environment defaults that silently break other repos’ contracts

## Governance Requirements
- Comply with shared `ci-cd`, `testing`, `documentation`, and `security-access-control` standards
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
- Are environment/network exposure assumptions aligned with the shared security/access-control standard?
- Are scripts and docs accurate and reproducible?
- Does CI/CD provide sufficient confidence for this phase?

## Success Criteria
- Runtime composition is consistent and reproducible
- Environment defaults do not create avoidable contract mismatches
- Exposure assumptions are explicit and documented
- Docs match scripts and actual behavior
- CI/CD and testing meet minimum required confidence for this phase
# Craftalism Deployment Portfolio Backlog

Date: 2026-04-10

## Purpose

This backlog raises `craftalism-deployment` from working Compose orchestration
to a stronger release and operations layer.

Source:

- [portfolio-evolution-roadmap.md](/home/henriquemichelini/IdeaProjects/craftalism/docs/portfolio-evolution-roadmap.md)
- [repo-requirement-pack.md](/home/henriquemichelini/IdeaProjects/craftalism-deployment/docs/repo-requirement-pack.md)

## Now

### High priority

- Add an automated smoke suite that validates:
  auth health, token issuance, protected API write, API read-back, and dashboard
  read path.
- Add stricter `.env` preflight validation for required secrets, issuer
  consistency, hostnames, and invalid config combinations.
- Add a deployment evidence-pack generator that records image digests, service
  status, health responses, and endpoint checks after deploys.
- Add rollback instructions for production digest deployments.

### Medium priority

- Strengthen health checks and startup-order validation so false green boots are
  less likely.
- Add clearer operator-facing failure guidance for partial startup and image
  pull/version mismatch issues.

## Next

### High priority

- Add backup and restore scripts for PostgreSQL and document migration safety
  procedures.
- Add release-promotion flow from tested staging references to production
  digests.
- Record exact git SHAs and image digests used by each deployment run.

### Medium priority

- Add one-command demo boot with seeded data and proof scripts.
- Add stronger local/test/prod parity checks for critical runtime assumptions.

## Later

- Add restart and recovery drills for individual container failure scenarios.
- Add chaos-lite verification around auth-server restarts and dependent-service
  recovery behavior.

## Done When

- The deployment repo proves the platform works, not only that Compose parses.
- Operators can deploy, verify, roll back, and recover with confidence.
- Runtime evidence is easy to preserve for audits and portfolio review.

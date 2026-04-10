# AGENTS.md

## Purpose

This repository owns runtime composition, service wiring, environment alignment, deployment automation, and operational orchestration across the Craftalism stack.

---

## Core Rules

- Work only within this repository's owned responsibilities
- Do not redefine shared contracts or cross-repo behavior
- Do not perform unrelated refactors
- Prefer the smallest correct change
- Maintain senior-level quality in code, design, and security
- Improve performance only if correctness and stability are preserved

---

## Ownership Requirement

Before acting, state:

- whether this repository owns or consumes the behavior

Do not proceed without establishing ownership.

---

## Boundary Rule

If an issue originates outside this repository:

- stop at the boundary
- identify the owning repository
- suggest what should be changed there

Do not implement cross-repo changes locally.

---

## Workflow

Use:

triage → audit → implement → reverify

Or:

audit → implement → reverify

### Audit
- read-only
- identify confirmed issues only

### Implement
- implement only confirmed repo-local issues
- validate changes when possible
- suggest commit message(s)

### Reverify
- read-only
- confirm fixes and check regressions

---

## Source of Truth

When needed, consult:

- repo-local docs (, )
- Craftalism root docs (contracts, standards, governance)

If conflicts exist, follow governance precedence.

---

## Commit Requirement

After implementation, suggest commit message(s) that:

- reflect only the implemented change
- are specific and scoped
- do not mix unrelated work

---

## Additional Guidance

Follow the Codex Usage Checklist when applicable.

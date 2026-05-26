# ADR-003 — Kyverno over OPA Gatekeeper

**Status:** Accepted
**Date:** 2026-05-01

## Context

We need an admission controller to enforce platform policies (require labels, ban `:latest`, verify image signatures, drop capabilities). The two mature options are **Kyverno** and **OPA Gatekeeper**.

## Decision

Use **Kyverno**.

## Rationale

| Factor | Kyverno | Gatekeeper | Winner |
|---|---|---|---|
| Policy language | YAML (Kyverno's own format) | Rego (declarative logic language) | **Kyverno** (no new language) |
| Native image signature verification | Built in (`verifyImages`) | Requires external tooling + custom Rego | **Kyverno** |
| Policy reporting | Built-in PolicyReport CRD | Available via Constraint status | **Kyverno** |
| Mutation support | First-class (mutate rules) | Available but newer | **Kyverno** |
| Auto-generated Pod controllers | Yes (Deployment → Pod template auto-derivation) | Manual | **Kyverno** |
| Community adoption | CNCF graduated | CNCF graduated | Even |
| Operator footprint | Larger (admission + reports + cleanup) | Smaller | **Gatekeeper** |
| Constraint Library reuse | Smaller | Larger (OPA library) | **Gatekeeper** |

## Consequences

**Positive**
- No Rego learning curve — platform team operates entirely in YAML
- Image signature verification is a one-liner instead of a Rego project
- Mutation rules let us add defaults (resource limits, security contexts) gradually as we tighten policy

**Negative**
- Larger memory footprint than Gatekeeper
- Smaller ready-made policy library than the OPA ecosystem
- Lock-in to Kyverno's CRDs

## Migration safety

Both tools express the same intents — if we need to switch, we'd be rewriting ~10 policies. Not free, but bounded. We deem this an acceptable risk for the operational simplicity gain.

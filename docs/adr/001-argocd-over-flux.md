# ADR-001 — Argo CD over Flux

**Status:** Accepted
**Date:** 2026-05-01
**Decision-maker:** Mohammed Abood
**Consulted:** —

## Context

We need a continuous-delivery mechanism that reconciles Git state to Kubernetes clusters. The two viable open-source options in 2026 are **Argo CD** and **Flux CD** — both CNCF-graduated, both production-proven, both following GitOps principles.

## Decision

Use **Argo CD** for this platform.

## Rationale

| Factor | Argo CD | Flux | Winner |
|---|---|---|---|
| Operator experience | First-class UI, real-time graph, app diff | CLI + dashboards via third-party | **Argo CD** |
| Multi-tenancy | AppProject + RBAC built in | Source/Image multi-tenancy via CRDs | Argo CD (simpler model) |
| Templating | ApplicationSet generators (git, list, matrix, cluster) | Same idea via Flux + Kustomization | Roughly even |
| Image-update automation | Argo CD Image Updater (separate component) | Image Reflector / Automation (built-in) | Flux (slight edge) |
| Helm support | First-class | First-class | Even |
| Adoption in MENA / enterprise | Higher visibility, more operator familiarity | Smaller community | Argo CD |
| Footprint | Slightly heavier | Lighter | Flux |

## Consequences

**Positive**
- Lower onboarding cost for the team (UI lowers bar for non-platform engineers)
- Reusable AppProject RBAC pattern for multi-tenant clusters
- Strong fit with Argo Rollouts (same vendor; metadata flows)

**Negative**
- Heavier resource footprint than Flux
- Image-update story needs a separate component (we use Renovate-on-deployments-repo instead)
- Argo CD's CRDs are coupled to its controller; harder to "exit" if we later want to swap

## Alternatives considered

- **Flux** — more lightweight, very strong image-automation, but ops-engineer-centric UX
- **Spinnaker** — too heavy for this scale; more suited to legacy multi-cloud pipelines
- **Jenkins-X** — declining adoption; not aligned with current GitOps practices

## Review

Re-evaluate this decision if:
- Argo CD changes licensing or graduation status
- Team size grows past 50+ engineers (Flux's lighter model may scale better)
- We need first-class multi-cluster pull-based reconciliation across many edge sites

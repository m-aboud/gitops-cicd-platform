# ADR-002 — Kustomize over Helm for application manifests

**Status:** Accepted
**Date:** 2026-05-01

## Context

We need a way to express per-environment variation of application manifests (dev / staging / prod). The two dominant tools are:

- **Helm** — template engine + package manager + chart repository
- **Kustomize** — overlay-based composition with strategic and JSON6902 patches

Both integrate cleanly with Argo CD.

## Decision

- **Application manifests** (this repo's `deployments/`) → **Kustomize**
- **Third-party platform components** (Argo CD, Kyverno, ESO, Argo Rollouts) → **Helm** (in the Terraform module)

## Rationale

**For application manifests:**

| Factor | Helm | Kustomize | Winner |
|---|---|---|---|
| Learning curve | Template syntax + Go templates + sprig | Pure YAML | **Kustomize** |
| Debuggability | Rendered output requires `helm template` | `kubectl kustomize` is built into kubectl | **Kustomize** |
| Variation patterns | `values.yaml` + conditionals | Overlays + strategic patches | Even (different paradigms) |
| Release tracking | Native (Helm releases) | Argo CD provides this anyway | Even |
| Argo CD support | First-class | First-class | Even |
| Risk of "template hell" | High | Low | **Kustomize** |
| Composability | Subcharts (often painful) | `bases` (trivial) | **Kustomize** |

**For platform components:**

Helm wins because every operator publishes a chart, often as the only supported install method. Kustomize would mean re-creating the chart's logic from rendered YAML — a maintenance burden we don't need.

## Consequences

**Positive**
- One mental model for app manifests: "YAML, patched"
- Diffs are readable in PRs; no templating noise
- New engineers can ship to staging within their first week without learning Helm

**Negative**
- Lose Helm's release semantics for apps — mitigated by Argo CD revision tracking
- For complex apps with many variations, Kustomize patches can become numerous; treat that as a signal to split the workload

## Open questions

- Mixed Helm-and-Kustomize per overlay (Argo CD supports it) — we don't currently need it; revisit if a third-party chart needs heavy env-specific patching.

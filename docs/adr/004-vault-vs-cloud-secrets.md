# ADR-004 — HashiCorp Vault vs cloud-native secret managers

**Status:** Accepted (multi-backend stance)
**Date:** 2026-05-01

## Context

External Secrets Operator (ESO) abstracts the **backend** from the **consumer** — application pods read a plain Kubernetes Secret regardless of where it actually lives. The real architectural question is which backend(s) to stand up.

Three credible options exist:

1. **Cloud-native** — AWS Secrets Manager, Azure Key Vault, GCP Secret Manager
2. **HashiCorp Vault** — self-hosted (OSS or Enterprise) or HCP Vault (managed)
3. **Both** — Vault for some workloads, cloud-native for others

## Decision

Support **both backends** via separate `ClusterSecretStore` resources. Pick the one that fits each workload:

| Workload pattern | Backend | Why |
|---|---|---|
| AWS-native app, static credentials, single-cloud | **AWS Secrets Manager** | Simpler, cheaper, IAM-integrated, no infra to run |
| Multi-cloud or hybrid (on-prem + cloud) | **Vault** | Single source of truth across environments |
| Dynamic credentials needed (DB, AWS STS, PKI) | **Vault** | Cloud-native services can't issue ephemeral DB users |
| Regulatory mandate or "Vault required" | **Vault** | Common in MENA banking, government, regulated industries |
| Mature DevSecOps team, willing to operate Vault | **Vault** | Capability ceiling is higher |
| Small team, AWS-only, no special compliance | **AWS Secrets Manager** | Operational simplicity wins |

## Rationale

### What only Vault gives you

1. **Dynamic secrets** — short-lived DB/AWS/SSH credentials minted on demand. Compromised credential? It expired an hour ago.
2. **Transit encryption** — encryption-as-a-service; apps never touch keys
3. **PKI** — internal CA issuing short-lived certificates
4. **Multi-cloud uniformity** — one API for AWS, Azure, on-prem, edge — no app code change
5. **Identity broker** — Vault can issue cloud creds (AWS, Azure, GCP) from a single identity
6. **Audit log granularity** — every secret read is logged with caller identity, path, version

### What cloud-native gives you

1. **Zero operational burden** — no Vault cluster to run, back up, upgrade, unseal
2. **Native IAM integration** — IRSA (AWS), Workload Identity (Azure/GCP) — already in your VPC
3. **Lower cost at low scale** — pay-per-secret pricing beats running Vault for a few hundred secrets
4. **Tighter compliance evidence** — cloud-provider compliance attestations flow through directly
5. **Provider-managed availability** — multi-AZ, encrypted-at-rest, audited by the cloud vendor

### What Vault costs you

- **Operational complexity** — HA cluster, Raft storage, unseal keys, upgrades, certificate rotation, backups
- **Single-point-of-failure risk** — apps can't fetch secrets if Vault is down (mitigated by ESO's cached `Secret` objects, but real)
- **Skill investment** — Vault policies, auth methods, namespaces, replication, performance standbys

## Consequences

**Positive**
- Architecture is **portable** — same ESO consumer pattern moves between backends
- Workload owners choose based on requirements, not on what's installed
- Demonstrates competence with both ecosystems

**Negative**
- Two backends = two sets of operational runbooks, two audit trails to reconcile
- Onboarding documentation must explain "when do I use which"

## Implementation in this repo

- [`cluster-secret-store.yaml`](../../platform/external-secrets/cluster-secret-store.yaml) — AWS Secrets Manager backend
- [`vault-secret-store.yaml`](../../platform/external-secrets/vault-secret-store.yaml) — Vault backend with Kubernetes auth
- [`example-externalsecret.yaml`](../../platform/external-secrets/example-externalsecret.yaml) — consumer for AWS SM
- [`example-vault-externalsecret.yaml`](../../platform/external-secrets/example-vault-externalsecret.yaml) — consumer for Vault, including a **dynamic DB credential** example showing the capability cloud-native can't match

## Review trigger

Re-evaluate this stance if:
- We reach a scale where running Vault is cheaper than per-secret cloud pricing (typically thousands of secrets, daily rotations)
- A single-cloud commitment makes Vault's multi-cloud value moot
- A regulatory change explicitly mandates one backend type

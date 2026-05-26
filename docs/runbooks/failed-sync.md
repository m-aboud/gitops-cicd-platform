# Runbook — Failed Argo CD sync

**Symptom:** An Argo CD Application is `OutOfSync` or `Degraded`. Possibly: the ApplicationSet is creating the app, but the app isn't healthy.

## Triage (first 5 minutes)

1. **Open the Argo CD UI** → click the affected app → check the visual graph for which resource is degraded.
2. **Read the Sync status** (top-left of the app view) for the error message verbatim.

Common patterns and fixes:

### "Failed to load target state: rpc error"

Cause: Argo CD can't reach the Git repo, or the revision doesn't exist.

```bash
# Verify Argo CD can resolve the repo
kubectl exec -n argocd deployment/argocd-repo-server -- \
  argocd-repo-server-cli check-repo \
    --repo https://github.com/mohammedabood/gitops-cicd-platform
```

If repo creds are wrong, re-add via UI or:

```bash
argocd repo add https://github.com/... --username ... --password ...
```

### "Resource not found in kind catalog: ApplicationSet"

Cause: A CRD the manifest references isn't installed (commonly Argo Rollouts, Kyverno, ESO).

```bash
kubectl get crds | grep -E 'rollouts|kyverno|external-secrets'
```

If missing, the platform Helm releases didn't finish:

```bash
kubectl get pods -n argo-rollouts
kubectl get pods -n kyverno
kubectl get pods -n external-secrets
```

Re-run the Terraform apply if any are missing.

### "admission webhook denied the request"

Cause: A Kyverno policy is rejecting the resource — by design.

```bash
# What policy rejected it?
kubectl get policyreports.wgpolicyk8s.io -A | grep <app-name>

# Read the specific rejection
kubectl describe policyreport <name> -n <ns>
```

Fix the manifest to comply, or — if the policy is wrong — open a PR to change `platform/kyverno-policies/`.

### "ComparisonError: failed to find target manifests"

Cause: kustomize render is failing.

```bash
# Render locally to see the same error CI sees
kustomize build deployments/apps/demo-api/overlays/<env>/
```

Usually a typo or a missing resource file. Fix in a PR.

### "Status: Progressing" but stuck

Most often: a Pod can't pull its image (`ImagePullBackOff`) or fails its readiness probe.

```bash
kubectl get pods -n demo-<env>
kubectl describe pod -n demo-<env> <pod>
kubectl logs -n demo-<env> <pod> --previous
```

Image-pull is often a Kyverno `verifyImages` rejection on the new tag — see ADR-003 and verify the image signature exists:

```bash
cosign verify ghcr.io/mohammedabood/demo-api:<tag> \
  --certificate-identity-regexp 'https://github.com/mohammedabood/.+' \
  --certificate-oidc-issuer 'https://token.actions.githubusercontent.com'
```

### "Sync operation in progress" stuck >5min

```bash
argocd app terminate-op demo-api-dev
argocd app sync demo-api-dev
```

If that doesn't clear it, the Argo CD app controller may be backlogged:

```bash
kubectl rollout restart deployment/argocd-application-controller -n argocd
```

## When to escalate

- Sync error referencing the cluster API server (TLS errors, 5xx) — cluster issue, not app
- Multiple apps degraded simultaneously across namespaces — likely a platform component (CoreDNS, CNI) issue
- Sync succeeds but the workload itself is unhealthy — that's an application bug; open a ticket with the app owner

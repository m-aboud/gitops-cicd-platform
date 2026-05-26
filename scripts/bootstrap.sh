#!/usr/bin/env bash
# Bootstrap the GitOps platform after Terraform apply.
# Assumes kubeconfig is already pointed at the new cluster.
#
# Idempotent — safe to re-run.
set -euo pipefail

log() { printf '\033[1;34m[bootstrap]\033[0m %s\n' "$*"; }
die() { printf '\033[1;31m[error]\033[0m %s\n' "$*" >&2; exit 1; }

command -v kubectl >/dev/null || die "kubectl not found"

# Verify cluster reachable
kubectl version --short >/dev/null 2>&1 || die "kubectl can't reach cluster"

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

# ----- Wait for Argo CD to be ready -----
log "Waiting for Argo CD CRDs..."
for i in {1..30}; do
    if kubectl get crd applications.argoproj.io >/dev/null 2>&1; then
        break
    fi
    sleep 5
done
kubectl get crd applications.argoproj.io >/dev/null 2>&1 \
    || die "Argo CD CRDs not present after 150s — was Terraform apply successful?"

log "Waiting for Argo CD controller..."
kubectl wait --for=condition=ready pod \
    -l app.kubernetes.io/name=argocd-application-controller \
    -n argocd --timeout=300s

# ----- Apply AppProject + ApplicationSet -----
log "Applying AppProject..."
kubectl apply -f "$REPO_ROOT/platform/argocd/projects/"

log "Applying ApplicationSet..."
kubectl apply -f "$REPO_ROOT/platform/argocd/applicationset.yaml"

# ----- Apply Kyverno policies -----
log "Applying Kyverno policies..."
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=kyverno -n kyverno --timeout=300s
kubectl apply -f "$REPO_ROOT/platform/kyverno-policies/"

# ----- Apply External Secrets ClusterSecretStore -----
log "Applying External Secrets ClusterSecretStore..."
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=external-secrets \
    -n external-secrets --timeout=300s || true
kubectl apply -f "$REPO_ROOT/platform/external-secrets/cluster-secret-store.yaml"

# ----- Show what Argo CD now manages -----
log "Bootstrap complete. Argo CD is managing:"
kubectl get applications -n argocd

cat <<EOF

Next:
  - Port-forward Argo CD:
      kubectl port-forward svc/argocd-server -n argocd 8080:443
      open https://localhost:8080
  - Watch the prod rollout:
      kubectl argo rollouts get rollout demo-api -n demo-prod --watch
EOF

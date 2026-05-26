#!/usr/bin/env bash
# Post a deploy annotation to Grafana. Designed to be called from CI or from
# the Argo Events workflow.
#
# Usage:
#   post-grafana-annotation.sh <app> <environment> <version> <git_sha>
#
# Env vars (required):
#   GRAFANA_URL        — base URL, e.g. https://grafana.example.com
#   GRAFANA_API_TOKEN  — service account token with annotations:write scope
#
# Optional env vars:
#   GRAFANA_DASHBOARD_UID — pin annotation to a single dashboard
#                            (omit for global annotation visible everywhere)
#   EXTRA_TAGS            — comma-separated extras (e.g. "team:platform,risk:low")

set -euo pipefail

APP="${1:?usage: $0 <app> <env> <version> <git_sha>}"
ENV="${2:?usage: $0 <app> <env> <version> <git_sha>}"
VERSION="${3:?usage: $0 <app> <env> <version> <git_sha>}"
SHA="${4:?usage: $0 <app> <env> <version> <git_sha>}"

: "${GRAFANA_URL:?GRAFANA_URL is required}"
: "${GRAFANA_API_TOKEN:?GRAFANA_API_TOKEN is required}"

# Build tag list
TAGS_JSON='["deploy","'"$APP"'","'"$ENV"'"]'
if [[ -n "${EXTRA_TAGS:-}" ]]; then
    IFS=',' read -ra EXTRA <<< "$EXTRA_TAGS"
    for t in "${EXTRA[@]}"; do
        TAGS_JSON=$(printf '%s' "$TAGS_JSON" | jq -c --arg t "$t" '. + [$t]')
    done
fi

# Build payload
PAYLOAD=$(jq -nc \
    --arg text "Deploy $APP@$VERSION → $ENV (sha $SHA)" \
    --argjson tags "$TAGS_JSON" \
    '{ text: $text, tags: $tags }')

# Optional dashboard scoping
if [[ -n "${GRAFANA_DASHBOARD_UID:-}" ]]; then
    DASH_ID=$(curl -fsSL -H "Authorization: Bearer $GRAFANA_API_TOKEN" \
        "$GRAFANA_URL/api/dashboards/uid/$GRAFANA_DASHBOARD_UID" | jq -r '.dashboard.id')
    PAYLOAD=$(printf '%s' "$PAYLOAD" | jq --argjson id "$DASH_ID" '. + { dashboardId: $id }')
fi

# Post
HTTP_CODE=$(curl -sS -o /tmp/resp.json -w "%{http_code}" \
    -X POST \
    -H "Authorization: Bearer $GRAFANA_API_TOKEN" \
    -H "Content-Type: application/json" \
    "$GRAFANA_URL/api/annotations" \
    -d "$PAYLOAD")

if [[ "$HTTP_CODE" =~ ^2 ]]; then
    ID=$(jq -r '.id' </tmp/resp.json 2>/dev/null || echo unknown)
    echo "✅ Posted Grafana annotation #$ID for $APP@$VERSION → $ENV"
else
    echo "❌ Failed to post annotation (HTTP $HTTP_CODE):"
    cat /tmp/resp.json
    exit 1
fi

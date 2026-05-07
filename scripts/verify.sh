#!/usr/bin/env bash
# End-to-end verification: query Thanos and confirm metrics from all three
# edge clusters are visible. Exits non-zero on any failure.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"
require_cmds kubectl curl

log_step "Verifying federation"

CTX=kind-cluster-central
NS=omni-obs

log_info "starting port-forward to thanos-query (9090)..."
kubectl --context "$CTX" -n "$NS" port-forward svc/thanos-query 19090:9090 \
  >/dev/null 2>&1 &
PF_PID=$!
trap 'kill "$PF_PID" 2>/dev/null || true' EXIT

# Give the port-forward a moment to come up
for _ in {1..10}; do
  if curl -fsS http://localhost:19090/-/ready >/dev/null 2>&1; then
    break
  fi
  sleep 1
done

if ! curl -fsS http://localhost:19090/-/ready >/dev/null; then
  die "thanos-query not ready"
fi
log_ok "thanos-query is ready"

# Stores endpoint should list 3 sidecars
log_info "checking connected stores..."
STORES_JSON="$(curl -fsS http://localhost:19090/api/v1/stores)"
STORE_COUNT="$(printf '%s' "$STORES_JSON" | grep -o '"name"' | wc -l | tr -d ' ')"
if (( STORE_COUNT < 3 )); then
  log_error "expected at least 3 connected stores, got $STORE_COUNT"
  printf '%s\n' "$STORES_JSON"
  exit 1
fi
log_ok "$STORE_COUNT stores connected"

# Query a metric and confirm we see all 3 cluster labels
log_info "querying cross-cluster metric..."
QUERY='count by (cluster) (up{cluster!=""})'
RESULT="$(curl -fsS --data-urlencode "query=$QUERY" http://localhost:19090/api/v1/query)"
CLUSTERS_SEEN="$(printf '%s' "$RESULT" | grep -oE '"cluster":"cluster-[a-z]+"' | sort -u | wc -l | tr -d ' ')"
if (( CLUSTERS_SEEN < 3 )); then
  log_warn "metrics from only $CLUSTERS_SEEN/3 clusters visible (Prometheus may still be warming up — try again in 30s)"
  printf '%s\n' "$RESULT"
  exit 1
fi
log_ok "metrics from all 3 clusters are visible via Thanos"

log_step "Verification passed"

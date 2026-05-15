#!/usr/bin/env bash
# Deploy the observability stack.
#
# Default (multi-cluster): each edge cluster gets OTel Collector + Prometheus +
#   Thanos sidecar + load gen; the central cluster gets Thanos Query + Grafana,
#   configured to connect to each edge sidecar's NodePort over the kind Docker
#   network.
#
# Single-cluster mode (--single): all components land in cluster-local.
#   Thanos querier talks to the sidecar in the same cluster; MinIO provides
#   object storage for block shipping.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"
require_cmds kubectl kustomize docker

MODE=multi
while [[ $# -gt 0 ]]; do
  case "$1" in
    --single) MODE=single; shift ;;
    *) die "Unknown flag: $1 (supported: --single)" ;;
  esac
done

if [[ "$MODE" == single ]]; then
  CTX=kind-cluster-local
  OVERLAY="$REPO_ROOT/kubernetes/overlays/single"

  log_step "Deploying single-cluster stack to $CTX"
  kubectl --context "$CTX" apply -k "$OVERLAY"

  log_step "Waiting for workloads"
  kubectl config use-context "$CTX" >/dev/null
  for d in otel-collector prometheus minio thanos-query grafana; do
    wait_deployment omni-obs "$d" 300s
  done

  log_step "Done"
  cat <<EOF

Deployment complete (single-cluster).

Grafana:       http://localhost:3000  (anonymous viewer; login: admin / admin)

Thanos UI:
  kubectl --context $CTX -n omni-obs port-forward svc/thanos-query 9090:9090
  open http://localhost:9090/stores   # should list one sidecar

MinIO console (optional):
  kubectl --context $CTX -n omni-obs port-forward svc/minio 9001:9001
  open http://localhost:9001          # login: minio / minio123

Tear down:  make clean-single

EOF
  exit 0
fi

EDGES=(aws azure gcp)
SIDECAR_NODEPORT=31901  # see kubernetes/components/edge/prometheus.yaml

log_step "Deploying edge clusters"
for cloud in "${EDGES[@]}"; do
  CTX="kind-cluster-$cloud"
  OVERLAY="$REPO_ROOT/kubernetes/overlays/$cloud"
  log_info "applying $OVERLAY to $CTX"
  kubectl --context "$CTX" apply -k "$OVERLAY"
done

log_step "Waiting for edge workloads to be Available"
for cloud in "${EDGES[@]}"; do
  CTX="kind-cluster-$cloud"
  kubectl config use-context "$CTX" >/dev/null
  for d in otel-collector prometheus telemetrygen; do
    wait_deployment omni-obs "$d" 240s
  done
done

log_step "Discovering edge sidecar endpoints"
for cloud in "${EDGES[@]}"; do
  CLUSTER="cluster-$cloud"
  IP="$(kind_node_ip "$CLUSTER")"
  if [[ -z "$IP" ]]; then
    die "could not discover Docker IP for $CLUSTER"
  fi
  printf -v "ENDPOINT_${cloud}" '%s' "$IP:$SIDECAR_NODEPORT"
  ep_var="ENDPOINT_${cloud}"
  log_info "  $cloud -> ${!ep_var}"
done

log_step "Rendering central overlay with discovered endpoints"
RENDER_DIR="$(mktemp -d)"
trap 'rm -rf "$RENDER_DIR"' EXIT
cp -R "$REPO_ROOT/kubernetes" "$RENDER_DIR/"
CENTRAL_KUST="$RENDER_DIR/kubernetes/overlays/central/kustomization.yaml"
sed -i.bak \
  -e "s|__AWS_SIDECAR_ENDPOINT__|${ENDPOINT_aws}|g" \
  -e "s|__AZURE_SIDECAR_ENDPOINT__|${ENDPOINT_azure}|g" \
  -e "s|__GCP_SIDECAR_ENDPOINT__|${ENDPOINT_gcp}|g" \
  "$CENTRAL_KUST"
rm -f "$CENTRAL_KUST.bak"

log_info "applying rendered central overlay to kind-cluster-central"
kubectl --context kind-cluster-central apply -k "$RENDER_DIR/kubernetes/overlays/central"

log_step "Waiting for central workloads"
kubectl config use-context kind-cluster-central >/dev/null
wait_deployment omni-obs thanos-query 240s
wait_deployment omni-obs grafana       240s

log_step "Done"
cat <<EOF

${C_GREEN}Deployment complete.${C_RESET}

Open Grafana:  http://localhost:3000  (anonymous viewer enabled)
                     login: admin / admin (demo only)

Verify the federation:
  kubectl --context kind-cluster-central -n omni-obs port-forward svc/thanos-query 9090:9090
  open http://localhost:9090/stores

You should see three Thanos sidecars listed (one per edge cluster).

Tear down:  make clean

EOF

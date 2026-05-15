#!/usr/bin/env bash
# Create the kind clusters used by the demo.
#
# Default (multi-cluster): four clusters — cluster-aws, cluster-azure,
#   cluster-gcp (edge) and cluster-central (query-tier + Grafana).
#
# Single-cluster mode (--single): one cluster — cluster-local — with the
#   full stack co-located. Fits comfortably in 5 GB Docker memory.
#
# Idempotent: skips clusters that already exist.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"
require_cmds kind docker

MODE=multi
while [[ $# -gt 0 ]]; do
  case "$1" in
    --single) MODE=single; shift ;;
    *) die "Unknown flag: $1 (supported: --single)" ;;
  esac
done

log_step "Creating kind clusters"

EXISTING="$(kind get clusters 2>/dev/null || true)"

create_if_missing() {
  local name=$1 config=$2
  if grep -qx "$name" <<<"$EXISTING"; then
    log_info "cluster '$name' already exists, skipping."
    return 0
  fi
  log_info "creating cluster '$name'..."
  kind create cluster --name "$name" --config "$config" --wait 60s
  log_ok "cluster '$name' is up."
}

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# Edge cluster config — control plane plus one worker. The host-port mapping is
# omitted because the central cluster reaches edge sidecars over the kind
# Docker network (same docker bridge), not via the host.
make_edge_config() {
  local name=$1 cloud=$2 region=$3
  cat >"$TMP/$name.yaml" <<EOF
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: $name
nodes:
  - role: control-plane
    labels:
      cloud-provider: $cloud
      region: $region
  - role: worker
    labels:
      cloud-provider: $cloud
      region: $region
EOF
  echo "$TMP/$name.yaml"
}

# Central cluster — exposes Grafana on host port 3000 so the user can browse to
# http://localhost:3000 after bootstrap.
make_central_config() {
  cat >"$TMP/cluster-central.yaml" <<'EOF'
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: cluster-central
nodes:
  - role: control-plane
    labels:
      role: query-tier
    extraPortMappings:
      - containerPort: 30300
        hostPort: 3000
        protocol: TCP
EOF
  echo "$TMP/cluster-central.yaml"
}

# Single cluster — full stack on one node. Exposes Grafana on host port 3000.
# Designed for machines with ~5 GB Docker memory (e.g. 8 GB laptop).
make_single_config() {
  cat >"$TMP/cluster-local.yaml" <<'EOF'
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: cluster-local
nodes:
  - role: control-plane
    extraPortMappings:
      - containerPort: 30300
        hostPort: 3000
        protocol: TCP
EOF
  echo "$TMP/cluster-local.yaml"
}

if [[ "$MODE" == single ]]; then
  create_if_missing cluster-local "$(make_single_config)"
  log_step "Cluster contexts"
  kubectl config get-contexts | grep 'kind-cluster-local' || kubectl config get-contexts
  log_ok "Single cluster is ready."
  log_info "Deploy with:  ./scripts/deploy.sh --single"
  log_info "Or run:       make demo-single"
  exit 0
fi

create_if_missing cluster-aws     "$(make_edge_config cluster-aws     aws    us-east-1)"
create_if_missing cluster-azure   "$(make_edge_config cluster-azure   azure  eastus)"
create_if_missing cluster-gcp     "$(make_edge_config cluster-gcp     gcp    us-central1)"
create_if_missing cluster-central "$(make_central_config)"

log_step "Cluster contexts"
kubectl config get-contexts | grep -E 'kind-(cluster|central)' || kubectl config get-contexts

log_ok "All four clusters are ready."

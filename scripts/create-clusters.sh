#!/usr/bin/env bash
# Create the four kind clusters used by the demo:
#   - cluster-aws, cluster-azure, cluster-gcp — edge clusters
#   - cluster-central                          — query-tier + Grafana
# Idempotent: skips clusters that already exist.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"
require_cmds kind docker

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

create_if_missing cluster-aws     "$(make_edge_config cluster-aws     aws    us-east-1)"
create_if_missing cluster-azure   "$(make_edge_config cluster-azure   azure  eastus)"
create_if_missing cluster-gcp     "$(make_edge_config cluster-gcp     gcp    us-central1)"
create_if_missing cluster-central "$(make_central_config)"

log_step "Cluster contexts"
kubectl config get-contexts | grep -E 'kind-(cluster|central)' || kubectl config get-contexts

log_ok "All four clusters are ready."

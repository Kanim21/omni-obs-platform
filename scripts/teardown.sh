#!/usr/bin/env bash
# Tear down the demo. Removes all four kind clusters.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"
require_cmds kind

log_step "Tearing down kind clusters"

for c in cluster-aws cluster-azure cluster-gcp cluster-central; do
  if kind get clusters 2>/dev/null | grep -qx "$c"; then
    log_info "deleting $c"
    kind delete cluster --name "$c"
  else
    log_info "$c not present, skipping"
  fi
done

log_ok "Teardown complete."

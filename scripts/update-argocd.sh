#!/usr/bin/env bash
# Re-download the vendored ArgoCD install manifest from the pinned upstream tag.
# Run this when bumping the ArgoCD version; commit the resulting diff to install.yaml
# so version upgrades are auditable.
#
# Usage: ./scripts/update-argocd.sh [VERSION]
#   VERSION defaults to the value of ARGOCD_VERSION below.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"
require_cmds curl

ARGOCD_VERSION="${1:-v3.4.2}"
DEST="$REPO_ROOT/kubernetes/components/argocd/install.yaml"
URL="https://raw.githubusercontent.com/argoproj/argo-cd/${ARGOCD_VERSION}/manifests/install.yaml"

log_step "Updating ArgoCD install manifest"
log_info "version : $ARGOCD_VERSION"
log_info "source  : $URL"
log_info "dest    : $DEST"

curl -fsSL "$URL" -o "$DEST"
log_ok "Downloaded $(wc -l < "$DEST") lines."
log_info "Review the diff, update the version comment in kubernetes/components/argocd/kustomization.yaml, then commit."

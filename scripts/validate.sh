#!/usr/bin/env bash
# Validate Kubernetes manifests without needing a running cluster.
# - kustomize build of every overlay
# - kubeconform schema validation
# - kube-linter best-practice checks
# This is what CI runs.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"
require_cmds kustomize

OVERLAYS=(aws azure gcp central single)
RENDER_DIR="$(mktemp -d)"
trap 'rm -rf "$RENDER_DIR"' EXIT

log_step "Rendering overlays"
for o in "${OVERLAYS[@]}"; do
  OUT="$RENDER_DIR/$o.yaml"
  log_info "kustomize build overlays/$o -> $OUT"
  if [[ "$o" == "central" ]]; then
    # Substitute placeholders so the render is parseable. Real values are
    # injected at deploy time; for static validation any host:port works.
    cp -R "$REPO_ROOT/kubernetes" "$RENDER_DIR/k8s"
    sed -i.bak \
      -e 's|__AWS_SIDECAR_ENDPOINT__|10.0.0.1:31901|g' \
      -e 's|__AZURE_SIDECAR_ENDPOINT__|10.0.0.2:31901|g' \
      -e 's|__GCP_SIDECAR_ENDPOINT__|10.0.0.3:31901|g' \
      "$RENDER_DIR/k8s/overlays/central/kustomization.yaml"
    rm -f "$RENDER_DIR/k8s/overlays/central/kustomization.yaml.bak"
    kustomize build "$RENDER_DIR/k8s/overlays/central" > "$OUT"
  else
    kustomize build "$REPO_ROOT/kubernetes/overlays/$o" > "$OUT"
  fi
done
log_ok "All overlays rendered."

log_step "Rendering ArgoCD component"
ARGOCD_OUT="$RENDER_DIR/argocd.yaml"
log_info "kustomize build components/argocd -> $ARGOCD_OUT"
kustomize build "$REPO_ROOT/kubernetes/components/argocd" > "$ARGOCD_OUT"
log_ok "ArgoCD component rendered."

log_step "kubeconform schema validation"
if command -v kubeconform >/dev/null 2>&1; then
  ALL_RENDERS=("${OVERLAYS[@]}" argocd)
  for o in "${ALL_RENDERS[@]}"; do
    log_info "kubeconform: $o"
    kubeconform -strict -summary -schema-location default "$RENDER_DIR/$o.yaml"
  done
  log_ok "kubeconform passed for all overlays."
else
  log_warn "kubeconform not installed — skipping. Install: brew install kubeconform"
fi

log_step "kube-linter best-practice checks"
if command -v kube-linter >/dev/null 2>&1; then
  ALL_RENDERS=("${OVERLAYS[@]}" argocd)
  for o in "${ALL_RENDERS[@]}"; do
    log_info "kube-linter: $o"
    kube-linter lint --config "$REPO_ROOT/.kube-linter.yaml" "$RENDER_DIR/$o.yaml" || {
      log_warn "kube-linter reported issues in $o"
    }
  done
else
  log_warn "kube-linter not installed — skipping. Install: brew install kube-linter"
fi

log_ok "Validation complete."

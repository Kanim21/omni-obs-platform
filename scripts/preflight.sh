#!/usr/bin/env bash
# Preflight checks before bootstrapping the demo.
# Exits non-zero if anything is missing or misconfigured.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

log_step "Preflight checks"

# 1. Required CLIs
log_info "checking required tools..."
MISSING=()
for cmd in docker kind kubectl kustomize; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    MISSING+=("$cmd")
  fi
done
if (( ${#MISSING[@]} > 0 )); then
  log_error "Missing tools: ${MISSING[*]}"
  cat <<EOF

Install on macOS with Homebrew:
  brew install docker kind kubectl kustomize

If you already have Docker Desktop, ensure it's running before re-running.
EOF
  exit 1
fi
log_ok "all required CLIs found"

# 2. Docker daemon reachable
log_info "checking Docker daemon..."
if ! docker info >/dev/null 2>&1; then
  die "Docker daemon is not reachable. Start Docker Desktop and try again."
fi
log_ok "Docker daemon is up"

# 3. Tool versions (best-effort, just warnings)
KIND_VERSION="$(kind version 2>/dev/null | awk '{print $2}' || true)"
KUBECTL_VERSION="$(kubectl version --client -o json 2>/dev/null | sed -n 's/.*"gitVersion": *"\([^"]*\)".*/\1/p' | head -n1 || true)"
log_info "kind:    ${KIND_VERSION:-unknown}"
log_info "kubectl: ${KUBECTL_VERSION:-unknown}"

# 4. Docker resources — kind clusters are memory-hungry; warn if the host looks tight
DOCKER_MEM_BYTES="$(docker info --format '{{.MemTotal}}' 2>/dev/null || echo 0)"
DOCKER_MEM_GIB=$(( DOCKER_MEM_BYTES / 1024 / 1024 / 1024 ))
if (( DOCKER_MEM_GIB < 6 )); then
  log_warn "Docker has only ${DOCKER_MEM_GIB} GiB of memory available."
  log_warn "Recommended: 8 GiB+. Increase in Docker Desktop > Settings > Resources."
else
  log_ok "Docker memory: ${DOCKER_MEM_GIB} GiB"
fi

# 5. Port availability for Grafana NodePort exposure (host-side mapping)
for port in 30300 31901; do
  if lsof -nP -iTCP:"$port" -sTCP:LISTEN >/dev/null 2>&1; then
    log_warn "TCP port $port already in use — host-side port mapping may conflict."
  fi
done

# 6. Existing kind clusters that would collide
EXISTING="$(kind get clusters 2>/dev/null || true)"
for c in cluster-aws cluster-azure cluster-gcp cluster-central; do
  if grep -qx "$c" <<<"$EXISTING"; then
    log_warn "kind cluster '$c' already exists — bootstrap will reuse or recreate it."
  fi
done

log_ok "Preflight passed."

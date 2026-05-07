#!/usr/bin/env bash
# Shared helpers for omni-obs scripts. Sourced, not executed.

# Colors (skipped if not a tty so logs to files stay clean)
if [[ -t 1 ]]; then
  C_RESET='\033[0m'
  C_RED='\033[0;31m'
  C_GREEN='\033[0;32m'
  C_YELLOW='\033[0;33m'
  C_BLUE='\033[0;34m'
  C_BOLD='\033[1m'
else
  C_RESET='' C_RED='' C_GREEN='' C_YELLOW='' C_BLUE='' C_BOLD=''
fi

log_info()  { printf "${C_BLUE}[info]${C_RESET}  %s\n" "$*"; }
log_ok()    { printf "${C_GREEN}[ ok ]${C_RESET}  %s\n" "$*"; }
log_warn()  { printf "${C_YELLOW}[warn]${C_RESET}  %s\n" "$*" >&2; }
log_error() { printf "${C_RED}[err ]${C_RESET}  %s\n" "$*" >&2; }
log_step()  { printf "\n${C_BOLD}==> %s${C_RESET}\n" "$*"; }

die() { log_error "$*"; exit 1; }

require_cmd() {
  local cmd=$1
  if ! command -v "$cmd" >/dev/null 2>&1; then
    die "Required command not found: $cmd. See README.md prerequisites."
  fi
}

require_cmds() {
  for c in "$@"; do require_cmd "$c"; done
}

# Wait for a Deployment to become Available. Times out cleanly.
wait_deployment() {
  local ns=$1 deploy=$2 timeout=${3:-180s}
  log_info "waiting for deployment/$deploy in $ns (timeout $timeout)..."
  if ! kubectl -n "$ns" wait --for=condition=Available "deploy/$deploy" --timeout="$timeout"; then
    log_error "deployment/$deploy did not become Available in $timeout"
    kubectl -n "$ns" describe "deploy/$deploy" || true
    kubectl -n "$ns" get pods -l "app=$deploy" -o wide || true
    return 1
  fi
}

# Get the Docker IP of a kind cluster's control-plane node.
# Used so the central cluster can reach edge NodePorts over the kind Docker network.
kind_node_ip() {
  local cluster=$1
  docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' \
    "${cluster}-control-plane" 2>/dev/null | head -n1
}

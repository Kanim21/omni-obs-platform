#!/usr/bin/env bash
# DEPRECATED: this script created only the 3 edge clusters. The demo now also
# requires a 4th 'cluster-central' for Thanos Query and Grafana.
# Use scripts/create-clusters.sh instead, or just `make demo` for end-to-end.

cat <<EOF
This script has been replaced by scripts/create-clusters.sh, which provisions
all four kind clusters (3 edges + 1 central) needed by the demo.

Run instead:

  scripts/create-clusters.sh   # just the clusters
  make demo                    # clusters + deploy + verify

EOF
exit 1

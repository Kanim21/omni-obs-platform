# ADR 0001: Federation strategy — Thanos Sidecar StoreAPI vs. Receive vs. remote-write

- **Status:** Accepted
- **Date:** 2026-04-15
- **Deciders:** project author

## Context

Three independent edge clusters (one per cloud) need to feed a single global query view. There are three mainstream patterns:

1. **Per-cluster Prometheus + Thanos Sidecar, federated via StoreAPI.** Each edge keeps its own TSDB. A central Thanos Query connects to each sidecar and presents a unified PromQL endpoint.
2. **Thanos Receive.** Edge Prometheuses use `remote_write` to push samples into a central Receive cluster, which acts as an ingest tier.
3. **Native Prometheus federation (`/federate`).** Central Prometheus scrapes a curated subset of each edge's metrics.

## Decision

Adopt **option 1** — Sidecar + StoreAPI — for the demo and as the recommended baseline.

## Rationale

- **Edge data stays at the edge.** Each cluster owns its TSDB. If WAN to the central tier is degraded, edge metrics keep landing in local Prometheus and local alerts still fire. Receive centralizes that risk.
- **No write amplification across the WAN.** `remote_write` ships every sample, all the time. StoreAPI is pull-on-query — most samples never cross the WAN.
- **Operationally cheaper for low-cluster-count fleets.** Receive is the right answer when you have many ephemeral edges or need write-path scaling, but it adds a hashring, a write-ahead log, and operational complexity. For ≤10 long-lived edges this is overkill.
- **Native `/federate` is a dead end.** It's polling-based, doesn't preserve histogram buckets cleanly, and doesn't deduplicate HA pairs. It's fine for "promote a few KPIs" but not for a global query view.

## Consequences

**Positive:**

- Edge clusters remain independently operable.
- Adding a new edge is one overlay + one `--endpoint` flag.
- Standard Thanos pattern; documentation and operator knowledge are widely available.

**Negative:**

- Cross-WAN query latency depends on the slowest edge. A degraded edge slows global queries unless `--store.response-timeout` is tuned.
- Edge clusters must be reachable from central (firewall design needed).
- Long-term storage per edge requires per-edge object storage configuration.

## When to revisit

Revisit and consider Thanos Receive if any of the following becomes true:

- Edge clusters become ephemeral (autoscaling, spot-based, short-lived).
- Cross-WAN bandwidth becomes a constraint that pull queries can't manage.
- The number of edges grows past ~20 — service discovery for `--endpoint` flags gets unwieldy and Receive's hashring scales better.

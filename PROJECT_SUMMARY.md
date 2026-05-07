# Project Summary

## What this project demonstrates

A working federated multi-cluster observability platform, built end-to-end:

- **Architecture design** — chose the federated tiered-storage pattern over alternatives (centralized push, hub-and-spoke remote-write) and documented why; see [`governance/adr/0001-federation-strategy.md`](governance/adr/0001-federation-strategy.md).
- **Kubernetes & Kustomize** — base + components + per-environment overlays, no Helm value sprawl, every manifest passes `kubeconform` and `kube-linter`.
- **Observability stack expertise** — OpenTelemetry Collector, Prometheus, Thanos (sidecar + Query), Grafana, configured to actually federate rather than just coexist.
- **Operational discipline** — preflight checks, idempotent bootstrap, an end-to-end verification script, runbooks, SLOs, ADRs, CI validation.
- **Production thinking** — the README is explicit about what's demo-grade and what would change for production. This is more recruiter-attractive than over-claiming.

## Stack

| Layer       | Component                          | Version |
| ----------- | ---------------------------------- | ------- |
| Ingestion   | OpenTelemetry Collector (contrib)  | 0.96.0  |
| TSDB        | Prometheus                         | 2.51.2  |
| Federation  | Thanos (Sidecar + Query)           | 0.34.1  |
| Dashboard   | Grafana                            | 10.4.2  |
| Orchestration | Kubernetes via `kind`            | latest  |
| Configuration | Kustomize                        | v5      |

## Engineering decisions worth highlighting

1. **Four-cluster topology, not three.** Edge clusters and the query tier have different lifecycles, security boundaries, and scaling profiles — they don't belong in the same cluster even in a demo.
2. **Components, not duplicate base manifests.** Edge and central each have a Kustomize component; overlays compose `base + components/<role>`. This keeps drift impossible.
3. **No object storage in the demo, with disclosure.** Adding MinIO would let me claim "tiered storage" for real, but it doubles the moving parts without changing what the demo proves. The README and ADR both say so explicitly rather than papering over it.
4. **Synthetic load via `telemetrygen`.** Real workloads need OTel SDK instrumentation; for a federation demo, a load generator that emits OTLP at a known rate is a stronger signal — you can write deterministic verifications against it.
5. **Bootstrap discovers endpoints at deploy time.** The central overlay has placeholders that the deploy script substitutes with discovered Docker network IPs. This is honest about the demo running on `kind`'s Docker network while keeping the manifest structure identical to what real GitOps would look like.

## What I'd build next

If extending this beyond the demo:

- Add MinIO and configure Thanos sidecar `--objstore.config-file` for real long-term storage with downsampling via Compactor.
- Replace static `--endpoint` flags with Thanos's `--endpoint.sd-config-file` and a service-discovery file updated by an operator.
- Move from sidecar federation to **Thanos Receive** for write-path federation — better for high-cardinality and ephemeral edge clusters.
- Wire OIDC for Grafana (Dex + GitHub or similar).
- Add traces (Tempo) and logs (Loki) to round out the three pillars.
- Replace the deploy script's endpoint discovery with an operator pattern.

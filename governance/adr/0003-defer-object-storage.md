# ADR 0003: Defer object storage in the demo

- **Status:** Accepted
- **Date:** 2026-04-15

## Context

A "tiered-storage" Thanos deployment normally includes object storage (S3, GCS, Azure Blob, or MinIO locally) so the Thanos Sidecar can ship 2-hour TSDB blocks for long-term retention, downsampling via Compactor, and historical query via Store Gateway.

Adding MinIO to each edge plus Compactor + Store Gateway centrally would make this a complete tiered-storage demo.

## Decision

**Defer object storage.** The demo runs with 2-hour Prometheus retention only; the Thanos Sidecar exposes the live TSDB over StoreAPI but does not ship blocks anywhere.

## Rationale

- The thing this demo proves is **federation across clusters** — that part works identically whether or not object storage is wired in.
- Adding MinIO doubles the moving parts (4 new deployments: MinIO + Compactor + Store Gateway + a bucket-init job) and the failure surface.
- A demo that takes 10 minutes to bootstrap and is fragile is worse than one that takes 5 minutes and is reliable.
- The README and `governance/adr/0001` are explicit about this — not papered over.

## What's lost vs. a full tiered demo

- No retention beyond 2 hours.
- No demonstration of downsampling.
- No demonstration of Store Gateway or bucket index.

These are real production needs but not what this repo is showing.

## How to add it later

Sketch:

1. Deploy MinIO via a `components/minio/` Kustomize component, applied to each edge cluster (or one shared MinIO if treated as managed).
2. Add `--objstore.config-file=/etc/thanos/objstore.yaml` to the Thanos sidecar, mounting a Secret with bucket creds.
3. Add `components/storage/` (Thanos Compactor + Store Gateway) to the central overlay.
4. Update Thanos Query in central to add `--endpoint=<store-gateway>:10901`.
5. Update `make verify` to assert blocks land in the bucket within 3h.

Each step is small and additive, which is exactly why deferring this is safe.

# Omni-Obs Multi-Cloud Observability Platform

## 🏗 Architecture
This platform utilizes a **Federated Tiered-Storage** model. Each edge cluster (AWS, Azure, and GCP) runs a local observability stack that is unified by a central Thanos Querier.

- **Collector Tier:** OpenTelemetry (OTLP) receiving telemetry via gRPC/HTTP.
- **Storage Tier:** Prometheus with **Thanos Sidecar** for real-time metrics.
- **Query Tier:** Thanos Querier provides a global, deduplicated view of all clusters.

## 🛠 Features
- **Multi-Cloud:** Unified view across AWS, Azure, and GCP.
- **Self-Healing:** Configured with Liveness and Readiness probes.
- **GitOps Ready:** Managed via Kustomize for environment-specific overlays.

## 🚀 Deployment
```bash
# Deploy to your specific cloud overlay
kubectl apply -k kubernetes/overlays/azure
```

# Quickstart

A 5-minute walkthrough to get the platform running locally.

## 1. Prerequisites

You need Docker plus a few CLIs. On macOS:

```bash
brew install docker kind kubectl kustomize
# Optional, used by `make validate`:
brew install kubeconform kube-linter
```

Make sure **Docker Desktop is running** and has at least **8 GiB of memory** allocated (Settings → Resources → Memory). The demo runs four `kind` clusters and is comfortable inside ~6 GiB but happier with more.

Sanity check:

```bash
docker info | grep -E 'Server Version|Total Memory'
kind version
kubectl version --client
kustomize version
```

## 2. Bootstrap the demo

From the repo root:

```bash
make demo
```

That target runs three phases:

1. **Preflight** — checks tools, Docker, ports.
2. **Cluster creation** — four kind clusters: `cluster-aws`, `cluster-azure`, `cluster-gcp`, `cluster-central`. Idempotent; if a cluster already exists it is reused.
3. **Deploy + verify** — applies the edge overlay to each edge cluster, discovers the Docker IP of each edge's control-plane node, renders the central overlay with those IPs, applies it, and runs an end-to-end check that all three clusters' metrics are visible from the central Thanos Query.

Total time on a recent MacBook: 4–6 minutes, mostly pulling images.

## 3. Explore

### Grafana

The central cluster maps Grafana to host port 3000:

```
http://localhost:3000
```

Login: `admin` / `admin` (anonymous viewer is also enabled, so the dashboard loads without a login). Open the **Omni-Obs / Multi-Cluster Overview** dashboard. Within ~30 seconds you should see three lines on the "OTLP metrics ingested per cluster" panel.

### Thanos Query directly

```bash
kubectl --context kind-cluster-central -n omni-obs port-forward svc/thanos-query 9090:9090
```

Then:

- http://localhost:9090/stores — should list three connected sidecars
- http://localhost:9090/graph — try `count by (cluster) (up)` — should return 3

### Per-cluster Prometheus

```bash
kubectl --context kind-cluster-aws -n omni-obs port-forward svc/prometheus 9091:9090
open http://localhost:9091
```

Repeat with `kind-cluster-azure` (different local port) and `kind-cluster-gcp`.

## 4. Tear down

```bash
make clean
```

Removes all four kind clusters. Docker images stay cached, so re-running `make demo` is faster the second time.

## Troubleshooting

### `make demo` exits at preflight

Re-read the message. Common causes:

- Docker not running → start Docker Desktop.
- Missing CLI → `brew install <name>`.
- Docker memory too low → bump it in Docker Desktop settings.

### A pod is `CrashLoopBackOff`

```bash
kubectl --context kind-cluster-aws -n omni-obs get pods
kubectl --context kind-cluster-aws -n omni-obs logs <pod> -c <container>
```

The two-container Prometheus pod has `prometheus` and `thanos-sidecar` — pass `-c` to pick which one.

### Thanos Query shows fewer than 3 stores

Most likely cause: the central cluster can't reach an edge cluster's NodePort. Check:

```bash
docker network inspect kind | grep -A2 cluster-aws-control-plane
# note the IP, then from inside the central cluster:
kubectl --context kind-cluster-central -n omni-obs run -it --rm netcheck \
  --image=nicolaka/netshoot --restart=Never -- \
  nc -vz <that-ip> 31901
```

If `nc` can't connect, the edge cluster's NodePort isn't bound — verify with:

```bash
kubectl --context kind-cluster-aws -n omni-obs get svc thanos-sidecar-external
```

### Grafana shows "no data"

Wait 30–60 seconds after `make demo` completes — Prometheus needs one or two scrape intervals before metrics appear, and Thanos sidecar needs a 2-hour TSDB block boundary before some queries return. Most demo dashboards work immediately, but historical queries take longer.

If still empty:

```bash
make verify
```

That script asserts metrics from all 3 clusters are visible. If it fails, the error message points at the broken link.

### Port 3000 / 30300 / 31901 already in use

Stop whatever's using them, or edit the NodePort numbers in `kubernetes/components/central/grafana.yaml` (Grafana, host-bound) and `kubernetes/components/edge/prometheus.yaml` (sidecar, internal only) and re-deploy.

### "context kind-cluster-X not found"

```bash
kind get clusters
kind export kubeconfig --name cluster-aws
```

`kind export kubeconfig` re-injects the context into your kubeconfig if it got removed.

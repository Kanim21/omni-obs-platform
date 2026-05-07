# Runbook: High error rate on Thanos Query

**Triggering alert:** `query-success-rate` SLO burn (see `governance/slos/slo-definitions.yaml`).

**Symptom:** Thanos Query is returning 5xx responses at a rate that's burning the error budget faster than 6× (ticket) or 14.4× (page).

## Severity

| Burn rate | Severity | Response time |
| --------- | -------- | ------------- |
| ≥14.4×    | SEV2     | 15 minutes    |
| ≥6×       | SEV3     | 4 hours       |

User-visible: dashboards return errors or partial data. Alerts evaluated in Thanos Ruler may flap.

## First 5 minutes — triage

1. **Is the central cluster healthy?**
   ```bash
   kubectl --context kind-cluster-central -n omni-obs get pods
   ```
   If `thanos-query` is `CrashLoopBackOff`, jump to "Thanos Query crashing" below.

2. **Check stores connectivity.**
   ```bash
   kubectl --context kind-cluster-central -n omni-obs port-forward svc/thanos-query 9090:9090 &
   curl -s http://localhost:9090/api/v1/stores | jq '.data[] | {name, lastCheck, lastError}'
   ```
   Any store with a non-empty `lastError` is the likely culprit. Note which one(s).

3. **Check recent error patterns.**
   ```bash
   kubectl --context kind-cluster-central -n omni-obs logs deploy/thanos-query --tail=200 | grep -iE 'error|warn'
   ```

## Common causes & fixes

### One or more edge sidecars unreachable

`/api/v1/stores` shows lastError like `connection refused` or `i/o timeout`.

```bash
# Identify the broken edge by name (e.g. cluster-aws)
kubectl --context kind-cluster-aws -n omni-obs get pods -l app=prometheus
kubectl --context kind-cluster-aws -n omni-obs logs deploy/prometheus -c thanos-sidecar --tail=100
```

If the sidecar pod is healthy but unreachable from central, the network path is broken. In the demo this means the kind Docker network — confirm the edge cluster's NodePort is bound and the central cluster can reach the edge node IP. In production this would mean a firewall, security group, or VPN tunnel.

**Mitigation:** if one edge is permanently degraded and global queries are timing out, restart `thanos-query` with `--store.unhealthy-timeout=30s` (default is 5m) so it drops the broken store faster:

```bash
kubectl --context kind-cluster-central -n omni-obs edit deploy/thanos-query
# add --store.unhealthy-timeout=30s to args
```

### Thanos Query crashing

```bash
kubectl --context kind-cluster-central -n omni-obs describe pod -l app=thanos-query
```

Look for OOM kills (`Reason: OOMKilled`) — the resource limit in the demo is 512Mi, which can be tight if all three edges return very high-cardinality queries simultaneously. Bump the limit and re-apply:

```bash
kubectl --context kind-cluster-central -n omni-obs set resources deploy/thanos-query \
  --limits=memory=2Gi --requests=memory=512Mi
```

### Edge Prometheus broken

If `lastError` from a store is `gRPC: failed to get info from prometheus`, the sidecar is alive but its Prometheus is not. Check:

```bash
kubectl --context kind-cluster-<cloud> -n omni-obs logs deploy/prometheus -c prometheus --tail=200
```

Common Prometheus failure modes: TSDB corruption (delete the emptyDir, recreate the pod — demo only; real deployments need PVC handling), config reload failure (check the ConfigMap was applied correctly), OOM (raise limit).

## Closing out

Once errors return to <0.5% for 30 minutes:

1. Annotate the incident in Grafana (Annotations panel) so the dashboard shows the recovery.
2. File a follow-up ticket if the root cause warrants tooling, alerting, or doc changes.
3. If the SLO budget for the month was significantly impacted, schedule a postmortem.

## Escalation

- After 30 minutes without progress, page secondary on-call.
- If the issue spans multiple components (e.g. Query AND Sidecars failing simultaneously), suspect the underlying network/cluster health and engage platform infra.

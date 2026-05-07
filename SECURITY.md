# Security

## Reporting a vulnerability

If you find a security issue in this repo, please **do not open a public GitHub issue**. Instead, email the maintainer or use GitHub's private vulnerability reporting (Security tab → Report a vulnerability).

## Demo-grade credentials and configuration

This repo is a local demo. Several things are deliberately insecure for ease of bootstrap and **must not be carried over to a real deployment**:

| Item | Demo state | What production needs |
| --- | --- | --- |
| Grafana admin password | hard-coded `admin` in a Deployment env var | OIDC SSO (Dex / GitHub / Okta), or a strong password from a Secret managed by Vault / External Secrets / Sealed Secrets |
| Grafana anonymous access | enabled (Viewer role) | disabled |
| Thanos sidecar gRPC | exposed on a NodePort, no auth | private LoadBalancer + mTLS, or behind a service mesh |
| OTel Collector OTLP receivers | no auth | bearer-token auth, mTLS, or a private endpoint |
| TSDB storage | `emptyDir` (data lost on pod restart) | PersistentVolumeClaims backed by encrypted EBS / Disk / PD |
| Container images | not pinned by digest | digest-pinned with a registry mirror + image policy admission |
| Secrets | none used (no real ones); demo passwords inline | every secret in a Secret resource, ideally from External Secrets |

## Pod security baseline

What the manifests *do* enforce, even in the demo:

- All containers run as non-root (`runAsNonRoot: true`, explicit non-zero `runAsUser`).
- All containers drop every Linux capability (`capabilities.drop: [ALL]`).
- All containers disallow privilege escalation (`allowPrivilegeEscalation: false`).
- The `omni-obs` namespace enforces the [Pod Security Standards](https://kubernetes.io/docs/concepts/security/pod-security-standards/) `restricted` profile.
- Containers use `seccompProfile: RuntimeDefault`.
- Where possible, containers use `readOnlyRootFilesystem: true`.

## Network exposure

The demo opens these ports on `localhost`:

- `3000` — Grafana (mapped from kind cluster-central NodePort 30300)

No edge cluster ports are mapped to the host. The central cluster reaches edge sidecars over the kind Docker network only.

## Supply chain

- Container images pinned by tag (e.g. `prom/prometheus:v2.51.2`). Production should pin by digest.
- Terraform modules pinned with `~>` constraints; production should consider exact pins plus Renovate/Dependabot.
- CI runs `kube-linter`, `kubeconform`, and `shellcheck` on every push.

## Things explicitly out of scope for the demo

- Automated certificate management (cert-manager).
- Image signature verification (cosign / sigstore).
- Runtime policy enforcement (Kyverno / Gatekeeper / OPA).
- Audit log shipping.
- Secret rotation.

Each of these is essential for a real deployment and is called out in the relevant ADR or the README's "demo-grade vs production" table.

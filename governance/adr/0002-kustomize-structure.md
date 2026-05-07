# ADR 0002: Kustomize structure — base + components + overlays

- **Status:** Accepted
- **Date:** 2026-04-15

## Context

The platform has two cluster roles (edge and central), three edge variants (aws, azure, gcp), and one central variant. Naïvely this is 4 overlays × N resources, with significant overlap.

Three structures were considered:

1. **Single `base/` containing every resource, overlays disable what they don't need.**
2. **Per-role bases:** `base-edge/`, `base-central/`, separate overlays.
3. **One `base/` (just shared resources) + Kustomize `components/` per role + overlays composing them.**

## Decision

Adopt **option 3** — components per role.

## Rationale

- Option 1 forces overlays to *remove* resources they don't want, which is brittle and clutters the rendered output.
- Option 2 duplicates the namespace and any other shared resource, and creates two sources of truth for cross-cutting concerns.
- Option 3 (`base + components`) lets the namespace live in `base/`, edge-specific resources live in `components/edge/`, central-specific in `components/central/`, and overlays just say "I'm an edge in AWS" or "I'm the central tier" by composing the right pieces.

## Consequences

**Positive:**

- Each overlay is small and reads top-to-bottom: which base, which components, what to patch.
- Adding a new edge cluster is copying one overlay file.
- Adding a new shared resource (e.g. a NetworkPolicy) is one file in `base/`, applied everywhere automatically.

**Negative:**

- Components are a Kustomize feature (`v1alpha1`) that some older tooling may not recognize. We pin Kustomize ≥ v5 in CI.
- Slightly more directories to navigate for newcomers. Mitigated by the README's repo-layout section.

## Alternative considered: Helm

Helm with a single chart and per-cloud values files would also work. We chose Kustomize because:

- All transformations are explicit YAML diffs, not Go template logic.
- No release state to manage; `kubectl apply -k` is stateless.
- The team's GitOps tool (Argo CD) renders Kustomize natively.

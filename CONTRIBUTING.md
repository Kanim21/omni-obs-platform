# Contributing

## Development workflow

1. Fork and clone.
2. Install prerequisites — see [QUICKSTART.md](QUICKSTART.md).
3. Make your changes in a topic branch.
4. **Validate locally before pushing:**
   ```bash
   make validate    # static manifest validation, no cluster needed
   make demo        # full bootstrap, if you changed deploy logic or manifests
   make verify      # end-to-end smoke test
   ```
5. Open a PR against `main`. CI will re-run `make validate` automatically.

## Code style

- **Shell**: `set -euo pipefail` at the top of every script. Run `shellcheck` locally before pushing. All scripts source `scripts/lib/common.sh` for logging helpers — please don't reinvent them.
- **YAML**: 2-space indent, no trailing whitespace. Every Kubernetes resource needs a `metadata.labels.app` (or equivalent) and resource requests + limits.
- **Markdown**: keep lines under ~100 chars where reasonable, but don't break inside fenced code blocks.

## Adding a new edge cluster

If you wanted to add, say, an Oracle Cloud edge:

1. Copy `kubernetes/overlays/aws/` to `kubernetes/overlays/oracle/` and search-replace `aws` → `oracle`, `cluster-aws` → `cluster-oracle`.
2. Add the cluster to `EDGES=(aws azure gcp)` in `scripts/deploy.sh`.
3. Add a corresponding kind cluster in `scripts/create-clusters.sh`.
4. Add an `--endpoint=__ORACLE_SIDECAR_ENDPOINT__` line to the central overlay's Thanos Query patch and update `scripts/deploy.sh`'s `sed` to substitute it.

## Reporting bugs

Open an issue with:

- Output of `kind version`, `kubectl version --client`, `kustomize version`, `docker info | grep 'Server Version'`.
- The exact `make` command you ran.
- The error output, including the surrounding context.
- What you expected vs. what happened.

## Pull request checklist

- [ ] `make validate` passes locally.
- [ ] If you touched manifests or scripts, `make demo` completes successfully and `make verify` passes.
- [ ] You updated documentation if behavior changed.
- [ ] Commit messages are descriptive (subject in imperative mood, body explaining why if non-obvious).

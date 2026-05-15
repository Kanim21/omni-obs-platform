.DEFAULT_GOAL := help
SHELL := /usr/bin/env bash

.PHONY: help preflight clusters deploy verify demo clean validate render fmt \
        demo-single clean-single

help: ## Show this help
	@awk 'BEGIN{FS=":.*?## "} /^[a-zA-Z_-]+:.*?## /{printf "  \033[36m%-14s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

preflight: ## Check tools, Docker, ports
	@./scripts/preflight.sh

clusters: preflight ## Create the 4 kind clusters (idempotent)
	@./scripts/create-clusters.sh

deploy: ## Apply edge + central overlays to the running clusters
	@./scripts/deploy.sh

verify: ## End-to-end check that federation is working
	@./scripts/verify.sh

demo: clusters deploy verify ## Full bootstrap: clusters + deploy + verify
	@echo ""
	@echo "Demo is up. Browse to http://localhost:3000 (admin/admin)."

demo-single: preflight ## Single-cluster bootstrap — fits in 5 GB Docker (8 GB laptop)
	@./scripts/create-clusters.sh --single
	@./scripts/deploy.sh --single

clean: ## Tear down all 4 kind clusters
	@./scripts/teardown.sh

clean-single: ## Tear down the single kind cluster (cluster-local)
	@kind delete cluster --name cluster-local 2>/dev/null && echo "cluster-local deleted." || echo "cluster-local not found."

validate: ## Static manifest validation — no cluster needed
	@./scripts/validate.sh

render: ## Render all overlays to stdout (sanity check)
	@for o in aws azure gcp single; do \
	  echo "===== overlays/$$o ====="; \
	  kustomize build kubernetes/overlays/$$o; \
	done

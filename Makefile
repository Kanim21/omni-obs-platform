.DEFAULT_GOAL := help
SHELL := /usr/bin/env bash

.PHONY: help preflight clusters deploy verify demo clean validate render fmt

help: ## Show this help
	@awk 'BEGIN{FS=":.*?## "} /^[a-zA-Z_-]+:.*?## /{printf "  \033[36m%-12s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

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

clean: ## Tear down all 4 kind clusters
	@./scripts/teardown.sh

validate: ## Static manifest validation — no cluster needed
	@./scripts/validate.sh

render: ## Render all overlays to stdout (sanity check)
	@for o in aws azure gcp; do \
	  echo "===== overlays/$$o ====="; \
	  kustomize build kubernetes/overlays/$$o; \
	done

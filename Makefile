# Entry point for the dev container. Wraps `docker compose` so the whole flow
# runs from a shell. The compose file and .env live at the repo root, so no
# extra flags are needed. There is no devcontainer.json: VS Code attaches to the
# container these targets start (see docs/dev/container.md).
#
# Typical flow:  make up  &&  make shell

# Per-user project name so container/volume names don't collide on a shared
# server (compose otherwise defaults to the bare checkout directory name).
# Falls back to `id -un` if USER is unset.
COMPOSE := COMPOSE_PROJECT_NAME=myproject-$(or $(USER),$(shell id -un)) docker compose
SERVICE := dev

.DEFAULT_GOAL := help
.PHONY: help up shell setup build rebuild logs down sync-env

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) \
		| awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-10s\033[0m %s\n", $$1, $$2}'

up: sync-env ## Build (if needed) and start the container, waiting until setup completes
	$(COMPOSE) up -d --wait

shell: ## Open a shell in the running container
	$(COMPOSE) exec $(SERVICE) bash

setup: ## Re-run the idempotent setup inside the running container
	$(COMPOSE) exec $(SERVICE) docker/setup.sh

build: sync-env ## Build the image
	$(COMPOSE) build

rebuild: sync-env ## Rebuild the image from scratch, picking up the latest tools
	$(COMPOSE) build --no-cache

logs: ## Follow container logs
	$(COMPOSE) logs -f

down: ## Stop and remove the container (named volumes are kept)
	$(COMPOSE) down

sync-env:
	@docker/sync-env.sh

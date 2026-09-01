# Terminal entry point for the dev container. Wraps `docker compose` so working
# directly from a shell mirrors the VS Code Dev Containers workflow. The compose
# file and .env live at the repo root, so no extra flags are needed.
#
# Typical flow:  make up  &&  make shell

# Per-user project name so container/volume names don't collide on a shared
# server (the CLI path otherwise defaults to the bare checkout directory name;
# VS Code already isolates per workspace path). Falls back to `id -un` if USER
# is unset.
COMPOSE := COMPOSE_PROJECT_NAME=myproject-$(or $(USER),$(shell id -un)) docker compose
SERVICE := dev

.DEFAULT_GOAL := help
.PHONY: help up shell setup build lock rebuild logs down sync-env

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

lock: ## Update the mise lock
	@docker/lock-tools.sh

rebuild: sync-env ## Rebuild the image from scratch using the tracked lock
	$(COMPOSE) build --no-cache

logs: ## Follow container logs
	$(COMPOSE) logs -f

down: ## Stop and remove the container (named volumes are kept)
	$(COMPOSE) down

sync-env:
	@docker/sync-env.sh

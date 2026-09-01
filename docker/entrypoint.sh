#!/usr/bin/env bash
set -euo pipefail

# Run the idempotent setup, then hand off to the container command (sleep
# infinity). The readiness marker is dropped last so the compose healthcheck —
# and `docker compose up --wait` — only report ready once setup has finished.
READY=/tmp/.devcontainer-ready

rm -f "${READY}"
/workspaces/myproject/docker/setup.sh
touch "${READY}"

exec "$@"

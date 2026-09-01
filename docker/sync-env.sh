#!/usr/bin/env bash
set -euo pipefail

# Populate the root .env with the machine-derived values that docker-compose.yml
# interpolates, so none of them are hand-maintained:
#   IMAGE_TAG          current git release tag (single source of truth; hatch-vcs)
#   HOST_UID/HOST_GID  your host `id -u`/`id -g`, baked into the image so
#                      bind-mounted files are owned by you
# Runs host-side via `make up`/`build`/`rebuild`; run it (via `make up`) before
# attaching VS Code to the running container.

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root_dir="$(dirname "${script_dir}")"
env_file="${root_dir}/.env"

tag="$(git -C "${root_dir}" describe --tags --abbrev=0 2>/dev/null || true)"
if [ -z "${tag}" ]; then
    echo "error: no git tag found (git describe --tags --abbrev=0 returned nothing)." >&2
    echo "       create a release tag (e.g. 'git tag v0.0.1') before building the image." >&2
    exit 1
fi

# Set KEY=VALUE in .env idempotently and in place, preserving line order and any
# adjacent comments (replace the existing line, or append if absent).
set_var() {
    local key="$1" val="$2"
    touch "${env_file}"
    if grep -q "^${key}=" "${env_file}"; then
        awk -v k="${key}" -v v="${val}" 'index($0, k"=")==1 {print k"="v; next} {print}' \
            "${env_file}" >"${env_file}.tmp"
        mv "${env_file}.tmp" "${env_file}"
    else
        printf '%s=%s\n' "${key}" "${val}" >>"${env_file}"
    fi
}

set_var IMAGE_TAG "${tag}"
set_var HOST_UID "$(id -u)"
set_var HOST_GID "$(id -g)"

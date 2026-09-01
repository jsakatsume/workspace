#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root_dir="$(dirname "${script_dir}")"
config_file="${script_dir}/mise/config.toml"
lock_file="${script_dir}/mise/mise.lock"
resolver_path="/mise/installs/node/latest/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
resolver_container=""
staging_dir=""

cleanup() {
    if [ -n "${resolver_container}" ]; then
        docker rm --force "${resolver_container}" >/dev/null 2>&1 || true
    fi
    if [ -n "${staging_dir}" ] && [ -d "${staging_dir}" ]; then
        rm -f -- "${staging_dir}/mise.lock"
        rmdir -- "${staging_dir}" 2>/dev/null || true
    fi
}
trap cleanup EXIT

echo "Resolving mise tool versions..."
resolver_image="$(
    docker build --quiet --target mise --file "${script_dir}/Dockerfile" "${root_dir}"
)"

# Safe mode permits metadata resolution without executing repository hooks or
# scripts. Empty data/cache dirs avoid installed-version bias; the real Node bin
# keeps npm usable.
resolver_container="$(
    docker create \
        --init \
        --env GITHUB_TOKEN \
        --env MISE_GITHUB_TOKEN \
        --env MISE_SAFE=1 \
        --env MISE_DATA_DIR=/tmp/mise-data \
        --env MISE_CACHE_DIR=/tmp/mise-cache \
        --env "PATH=${resolver_path}" \
        --entrypoint mise \
        "${resolver_image}" \
        lock --global --platform linux-arm64,linux-x64
)"
docker cp "${config_file}" "${resolver_container}:/mise/config.toml"

set +e
resolver_output="$(docker start --attach "${resolver_container}" 2>&1)"
resolver_status=$?
set -e
printf '%s\n' "${resolver_output}"

if [ "${resolver_status}" -ne 0 ]; then
    exit "${resolver_status}"
fi

# mise can exit 0 after skips, so accept only its measured success summary.
if grep -Eq '\([1-9][0-9]* skipped\)' <<<"${resolver_output}" ||
    ! grep -Eq 'Updated [1-9][0-9]* platform entries \(0 skipped\)$' <<<"${resolver_output}"; then
    echo "mise lock did not confirm a complete update; keeping the existing lock" >&2
    exit 1
fi

staging_dir="$(mktemp -d "${script_dir}/mise/.mise-lock.XXXXXX")"
docker cp "${resolver_container}:/mise/mise.lock" "${staging_dir}/mise.lock"
chmod 0644 "${staging_dir}/mise.lock"
mv "${staging_dir}/mise.lock" "${lock_file}"
rmdir "${staging_dir}"
staging_dir=""

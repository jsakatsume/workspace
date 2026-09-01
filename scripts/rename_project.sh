#!/usr/bin/env bash
set -euo pipefail

# Replace the placeholder project name with a real one.
#
#   scripts/rename_project.sh my_analysis
#
# Renames src/myproject/ and rewrites `myproject` (package, CLI, container
# paths, compose project) and `MYPROJECT` (the hatch-vcs env var) everywhere
# they appear in tracked text files.

OLD_LOWER="myproject"
OLD_UPPER="MYPROJECT"

if [ "$#" -ne 1 ]; then
    echo "usage: $(basename "$0") <new_name>" >&2
    echo "  <new_name> must be a valid Python identifier: lowercase letters," >&2
    echo "  digits and underscores, not starting with a digit." >&2
    exit 2
fi

NEW_LOWER="$1"
if ! [[ "${NEW_LOWER}" =~ ^[a-z_][a-z0-9_]*$ ]]; then
    echo "error: '${NEW_LOWER}' is not a valid Python identifier." >&2
    echo "       use lowercase letters, digits and underscores; do not start with a digit." >&2
    exit 2
fi
if [ "${NEW_LOWER}" = "${OLD_LOWER}" ]; then
    echo "error: the name is already '${OLD_LOWER}'; nothing to do." >&2
    exit 2
fi

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
root_dir="$(cd -- "${script_dir}/.." && pwd)"
cd "${root_dir}"

if [ ! -d "src/${OLD_LOWER}" ]; then
    echo "error: src/${OLD_LOWER} not found. Has this repository already been renamed?" >&2
    exit 1
fi
if [ -e "src/${NEW_LOWER}" ]; then
    echo "error: src/${NEW_LOWER} already exists." >&2
    exit 1
fi

NEW_UPPER="$(printf '%s' "${NEW_LOWER}" | tr '[:lower:]' '[:upper:]')"

# Text files that may hold the name. Skip caches, the virtualenv, the lock file
# (regenerated afterwards), and every directory holding outputs or data.
# `while read` rather than `mapfile`, so this also runs on the bash 3.2 that
# macOS ships.
changed=0
while IFS= read -r -d '' file; do
    # Skip anything that is not text (images, the odd binary).
    if ! grep -Iq . "${file}" 2>/dev/null; then
        continue
    fi
    if grep -q -e "${OLD_LOWER}" -e "${OLD_UPPER}" "${file}"; then
        perl -pi -e "s/\Q${OLD_UPPER}\E/${NEW_UPPER}/g; s/\Q${OLD_LOWER}\E/${NEW_LOWER}/g" "${file}"
        echo "  rewrote ${file#./}"
        changed=$((changed + 1))
    fi
done < <(
    find . \
        \( -path ./.git \
        -o -path ./.venv \
        -o -path ./data \
        -o -path ./results \
        -o -path ./reports \
        -o -name __pycache__ \
        -o -name .ruff_cache \
        -o -name .pytest_cache \
        -o -name node_modules \
        \) -prune -o \
        -type f ! -name uv.lock -print0
)

mv "src/${OLD_LOWER}" "src/${NEW_LOWER}"
echo "  moved   src/${OLD_LOWER} -> src/${NEW_LOWER}"

echo
echo "Renamed ${OLD_LOWER} -> ${NEW_LOWER} in ${changed} file(s)."
echo
echo "Next:"
echo "  1. uv lock && uv sync --all-groups   # the package name changed"
echo "  2. uv run poe code-check && uv run pytest"
echo "  3. rm -f scripts/rename_project.sh   # this script has done its job"
echo
echo "If a container is already running, the compose project name changed too:"
echo "  make down   # before make up, or the old containers and volumes are orphaned"

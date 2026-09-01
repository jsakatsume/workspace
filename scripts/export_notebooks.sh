#!/usr/bin/env bash
set -euo pipefail

# Resolve paths from script location so it works from any cwd.
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
NOTEBOOKS_DIR="$REPO_ROOT/notebooks"
OUTPUT_DIR="$REPO_ROOT/reports"

mkdir -p "$OUTPUT_DIR"

shopt -s nullglob
notebooks=(
    "$NOTEBOOKS_DIR"/qc_*.py
    "$NOTEBOOKS_DIR"/hypothesis_*.py
)

if [ "${#notebooks[@]}" -eq 0 ]; then
    echo "error: no qc_* or hypothesis_* notebooks found in $NOTEBOOKS_DIR" >&2
    exit 1
fi

for py_file in "${notebooks[@]}"; do
    filename="$(basename "${py_file%.py}")"
    output_file="$OUTPUT_DIR/${filename}.html"

    echo "exporting: $py_file -> $output_file"
    uv run marimo export html "$py_file" -o "$output_file" -f
    echo "exported: $py_file -> $output_file"
done

echo "export complete!"

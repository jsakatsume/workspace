"""Check that files under the given paths contain only ASCII text."""

from __future__ import annotations

import sys
from pathlib import Path

SKIP_DIRS = {"__pycache__", ".git", ".mypy_cache", ".pytest_cache", ".ruff_cache"}


def _iter_files(path: Path) -> list[Path]:
    if path.is_file():
        return [path]
    if not path.is_dir():
        return []
    return [
        child
        for child in path.rglob("*")
        if child.is_file() and not any(part in SKIP_DIRS for part in child.parts)
    ]


def _find_non_ascii(path: Path) -> list[str]:
    try:
        text = path.read_text(encoding="utf-8")
    except UnicodeDecodeError as exc:
        return [f"{path}: not valid UTF-8 text ({exc})"]

    errors: list[str] = []
    for line_no, line in enumerate(text.splitlines(), start=1):
        for column_no, char in enumerate(line, start=1):
            if ord(char) > 0x7F:
                errors.append(
                    f"{path}:{line_no}:{column_no}: non-ASCII character {char!r}"
                )
    return errors


def main(argv: list[str]) -> int:
    roots = [Path(arg) for arg in argv] or [Path("src"), Path("tests")]
    errors: list[str] = []
    for root in roots:
        for path in _iter_files(root):
            errors.extend(_find_non_ascii(path))

    if errors:
        print("Non-ASCII text is not allowed under src/ or tests/:", file=sys.stderr)
        print("\n".join(errors), file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))

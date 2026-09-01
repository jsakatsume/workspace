"""Locate the repository root so code and notebooks can build repo-relative paths."""

from __future__ import annotations

from pathlib import Path

ROOT_MARKER = "pyproject.toml"


def repo_root(start: Path) -> Path:
    """Return the nearest directory at or above `start` that holds the root marker.

    Args:
        start: File or directory inside the checkout.

    Returns:
        The repository root directory.

    Raises:
        FileNotFoundError: If no directory above `start` holds the root marker.
    """
    here = Path(start)
    if here.is_file():
        here = here.parent
    for candidate in [here, *here.parents]:
        if (candidate / ROOT_MARKER).is_file():
            return candidate
    raise FileNotFoundError(f"No {ROOT_MARKER} found at or above {here}")

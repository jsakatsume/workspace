"""Keep every figure in this project on one matplotlib style."""

from __future__ import annotations

from typing import Any

import matplotlib.style

PLOT_STYLE: dict[str, Any] = {
    "axes.grid": True,
    "axes.spines.right": False,
    "axes.spines.top": False,
    "figure.dpi": 120,
    "font.size": 10,
    "grid.alpha": 0.3,
    "savefig.bbox": "tight",
    "savefig.dpi": 200,
}


def use_plot_style() -> None:
    """Apply the shared matplotlib settings to the current session."""
    matplotlib.style.use(PLOT_STYLE)

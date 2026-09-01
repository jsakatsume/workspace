"""Run the example stage and write its outputs to the places this project agreed on."""

from __future__ import annotations

from pathlib import Path

import matplotlib.pyplot as plt
import pandas as pd

from myproject.example_stage.summarize import summarize_table
from myproject.figures.plot_style import use_plot_style

STAGE = "example_stage"


def stage_output_paths(root: Path) -> tuple[Path, Path]:
    """Return the two files this stage writes.

    Machine-readable output goes under `data/processed/<stage>/` and figures go
    under `results/<stage>/`. See docs/dev/io-conventions.md.

    Args:
        root: Repository root the paths are built from.

    Returns:
        The summary table path and the summary figure path.
    """
    return (
        root / "data" / "processed" / STAGE / "summary.tsv",
        root / "results" / STAGE / "summary.png",
    )


def run(input_table: Path, root: Path) -> tuple[Path, Path]:
    """Summarize a tab-separated file and write the summary table and figure.

    Args:
        input_table: Tab-separated input file.
        root: Repository root the output paths are built from.

    Returns:
        The paths written, in the order `stage_output_paths` returns them.
    """
    summary = summarize_table(pd.read_csv(input_table, sep="\t"))

    table_path, figure_path = stage_output_paths(root)
    table_path.parent.mkdir(parents=True, exist_ok=True)
    figure_path.parent.mkdir(parents=True, exist_ok=True)
    summary.to_csv(table_path, sep="\t", index=False)

    use_plot_style()
    figure, axes = plt.subplots()
    axes.bar(summary["column"], summary["mean"], yerr=summary["std"])
    axes.set_xlabel("column")
    axes.set_ylabel("mean (error bar: standard deviation)")
    figure.savefig(figure_path)
    plt.close(figure)

    return table_path, figure_path

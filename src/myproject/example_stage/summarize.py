"""Reduce a table of measurements to one summary row per numeric column."""

from __future__ import annotations

import pandas as pd

SUMMARY_COLUMNS = ["column", "count", "mean", "std"]


def summarize_table(table: pd.DataFrame) -> pd.DataFrame:
    """Return the count, mean and standard deviation of each numeric column.

    Non-numeric columns are dropped. This function reads no files and writes
    none; the pipeline layer decides where the result goes.

    Args:
        table: Measurements with at least one numeric column.

    Returns:
        One row per numeric column, with the columns named in `SUMMARY_COLUMNS`.

    Raises:
        ValueError: If `table` holds no numeric column.
    """
    numeric = table.select_dtypes("number")
    if numeric.empty:
        raise ValueError("table has no numeric column to summarize")
    return pd.DataFrame(
        {
            "column": list(numeric.columns),
            "count": numeric.count().to_numpy(),
            "mean": numeric.mean().to_numpy(),
            "std": numeric.std().to_numpy(),
        }
    )

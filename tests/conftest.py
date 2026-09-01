import matplotlib
import pandas as pd
import pytest

# Tests must never open a window; pick the file-writing backend before pyplot loads.
matplotlib.use("Agg")


@pytest.fixture
def measurements() -> pd.DataFrame:
    """Small table with two numeric columns and one text column."""
    return pd.DataFrame(
        {
            "label": ["a", "b", "c", "d"],
            "value": [1.0, 2.0, 3.0, 4.0],
            "score": [10.0, 20.0, 30.0, 40.0],
        }
    )

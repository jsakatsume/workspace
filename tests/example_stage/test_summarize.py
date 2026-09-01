import pandas as pd
import pytest

from myproject.example_stage.summarize import SUMMARY_COLUMNS, summarize_table


class TestSummarizeTable:
    def test_returns_one_row_per_numeric_column(self, measurements):
        summary = summarize_table(measurements)

        assert list(summary.columns) == SUMMARY_COLUMNS
        assert list(summary["column"]) == ["value", "score"]

    def test_computes_count_mean_and_std(self, measurements):
        summary = summarize_table(measurements).set_index("column")

        assert summary.loc["value", "count"] == 4
        assert summary.loc["value", "mean"] == pytest.approx(2.5)
        assert summary.loc["score", "mean"] == pytest.approx(25.0)

    def test_rejects_a_table_without_a_numeric_column(self):
        with pytest.raises(ValueError, match="no numeric column"):
            summarize_table(pd.DataFrame({"label": ["a", "b"]}))

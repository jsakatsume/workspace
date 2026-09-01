import pandas as pd

from myproject.pipelines.example_stage import run, stage_output_paths


def test_run_writes_the_summary_table_and_figure(tmp_path, measurements):
    input_table = tmp_path / "input.tsv"
    measurements.to_csv(input_table, sep="\t", index=False)

    table_path, figure_path = run(input_table, tmp_path)

    assert (table_path, figure_path) == stage_output_paths(tmp_path)
    assert figure_path.exists()
    assert list(pd.read_csv(table_path, sep="\t")["column"]) == ["value", "score"]

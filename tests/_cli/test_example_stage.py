from typer.testing import CliRunner

from myproject._cli.main import app

runner = CliRunner()


def test_version_flag_prints_something():
    result = runner.invoke(app, ["--version"])

    assert result.exit_code == 0, result.output
    assert result.output.strip()


def test_summarize_writes_the_stage_outputs(tmp_path, measurements):
    input_table = tmp_path / "input.tsv"
    measurements.to_csv(input_table, sep="\t", index=False)

    result = runner.invoke(
        app,
        [
            "example-stage",
            "summarize",
            "--input",
            str(input_table),
            "--root",
            str(tmp_path),
        ],
    )

    assert result.exit_code == 0, result.output
    assert (tmp_path / "data/processed/example_stage/summary.tsv").exists()
    assert (tmp_path / "results/example_stage/summary.png").exists()

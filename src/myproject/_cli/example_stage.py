"""Bridge the example-stage command line to the pipeline that runs it."""

from __future__ import annotations

from pathlib import Path
from typing import Annotated

import typer

from myproject.paths import repo_root
from myproject.pipelines.example_stage import run

app = typer.Typer(
    help="Summarize a table and write the stage outputs.", no_args_is_help=True
)


@app.command()
def summarize(
    input_table: Annotated[
        Path,
        typer.Option(
            "--input", exists=True, dir_okay=False, help="Tab-separated input file."
        ),
    ],
    root: Annotated[
        Path | None,
        typer.Option(
            "--root", help="Repository root to write under. Defaults to this checkout."
        ),
    ] = None,
) -> None:
    """Summarize the input table and write the summary table and figure."""
    table_path, figure_path = run(input_table, root or repo_root(Path(__file__)))
    typer.echo(f"wrote {table_path}")
    typer.echo(f"wrote {figure_path}")

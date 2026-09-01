"""Assemble the command line application from the per-stage command modules."""

from __future__ import annotations

from typing import Annotated

import typer

from myproject import __version__
from myproject._cli import example_stage

app = typer.Typer(help="Analysis project template.", no_args_is_help=True)
app.add_typer(example_stage.app, name="example-stage")


# invoke_without_command lets `--version` run on its own, with no stage command.
@app.callback(invoke_without_command=True)
def main(
    version: Annotated[  # noqa: FBT002
        bool,
        typer.Option("--version", help="Print the installed version and exit."),
    ] = False,
) -> None:
    """Handle the options that apply to every command."""
    if version:
        typer.echo(__version__)
        raise typer.Exit

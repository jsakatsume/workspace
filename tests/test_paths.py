import pytest

from myproject.paths import ROOT_MARKER, repo_root


def test_finds_the_root_from_a_nested_file(tmp_path):
    (tmp_path / ROOT_MARKER).write_text("")
    nested = tmp_path / "a" / "b"
    nested.mkdir(parents=True)
    marked_file = nested / "notebook.py"
    marked_file.write_text("")

    assert repo_root(marked_file) == tmp_path


def test_finds_the_root_from_a_directory(tmp_path):
    (tmp_path / ROOT_MARKER).write_text("")

    assert repo_root(tmp_path) == tmp_path


def test_raises_when_no_marker_is_above(tmp_path):
    with pytest.raises(FileNotFoundError, match=ROOT_MARKER):
        repo_root(tmp_path)

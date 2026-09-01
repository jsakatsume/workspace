# AGENTS.md

このファイルは、このリポジトリで作業する AI コーディングエージェント共通の指針。

## Communication

どの言語で書くか：

- ユーザーとのやり取り（質問・提案・説明・最終回答）は日本語。専門用語・コマンド・ファイル名・コード上の識別子は英語のままでよい。
- コード・コメント・docstring・コミットメッセージは英語。
- 公開ドキュメントや notebook の文章は、そのファイルが今使っている言語に合わせる。
- この指針ファイル自体も日本語で書く（識別子・コマンドは英語のまま）。

どう書くか（日本語・英語、会話・コードのすべてに適用）：

- 専門用語以外は、小学生でも大まかな意味がつかめる語で書く。ただし、正確さを落としてまで易しくしない。
- 一文を短くする。回りくどい言い回しや、英語からの直訳調にしない。
- 抽象名詞でまとめず、何がどうなるかを書く。「適切に処理する」ではなく「欠損した行を捨てる」。
- module 名・関数名・列名・CLI flag としてコードにある語（`example_stage`・`summarize_table` など）は、文章でもその語を使う。コードにない語（orchestration・contract など）は日常語に直す。
- これから付ける変数名・関数名・引数名も同じ基準で選ぶ。既存の名前を、この方針のためだけに改名はしない。

例：

- `Refuse an input whose schema the reader cannot satisfy.` → `Reject a table that has no numeric column.`
- 「stage のオーケストレーション、主要な file I/O、output contract」→「stage を動かす手順、主な file の読み書き、出力する file の決まり」

## Commands

Python・Python の CLI・依存パッケージを使うコマンドは `uv run` / `uv sync` で実行する。system Python や `pip` を直接使わない。`git` や `rg` のような普通の shell command は `uv run` で包まなくてよい。`uv run` は、走らせる前に `uv.lock` に合わせて `.venv` を自動で揃える。

```bash
# 依存パッケージを揃える（全グループ: dev, lint, docs, test）
uv sync --all-groups

# テスト
uv run pytest
uv run pytest tests/example_stage/test_summarize.py::TestSummarizeTable   # 一部だけ実行

# ファイルを書き換えない check（format・lint・型・notebook。個別 task は pyproject.toml 参照）
uv run poe code-check

# CLI
uv run myproject --help
```

## Architecture

`myproject` は、データ解析プロジェクトの雛形となる Python ライブラリ兼 CLI。解析は stage（段階）に分け、各 stage を3つの層にまたがって書く。いまは `example_stage` が1つだけ入っている。

- **stage サブパッケージ**（`example_stage/` など）— 解析そのものの処理を持つ。file の読み書きはしない。
- **`pipelines/<stage>.py`** — stage を動かす手順、主な file の読み書き、出力する file の決まりを持つ。
- **`_cli/<stage>.py`** — Typer との橋渡し（コマンドラインの文字列を値に変える）。

新しい解析処理や、file を読み書きする処理は stage サブパッケージか `pipelines/` に置き、`_cli/` には置かない。

各サブパッケージが何をするか、3つの層の分かれ方、データの流れ、入出力の決まりは `docs/dev/` にある。[Index](#index) を参照。

## Code conventions

- docstring の要約と補足は5行以内に収める（`Args`・`Returns`・`Raises` は除く）。5行に入らない設計の背景や algorithm の解説は `docs/dev/` へ移す。読めば分かる private helper では省いてよい。
- ローカル専用ファイル（`CONTEXT.md`・`docs/adr/`）は、git に入れない決定の記録。調べるために読んでよい。ただし、git で管理している code・test・notebook・公開ドキュメントに、これらの path や ADR 番号を新しく書き足さない。成果物だけを読んで理由が分かるようにし、ずっと残す背景は `docs/dev/` に書く。
- 出力の置き場所：図は `results/<stage>/`、プログラムが読むファイル（`.tsv`/`.npz`/`.txt` など）は `data/processed/<stage>/`（`<stage>` はサブパッケージ名）。詳しくは `docs/dev/io-conventions.md`。
- コミットメッセージは `prefix: message`（命令形、50字以内、末尾ピリオドなし）。prefix は `feat`, `fix`, `docs`, `style`, `refactor`, `perf`, `test`, `chore`。

## Testing

- テストを書く前に、対象 module の既存テストと、`tests/conftest.py` に用意されている fixture を見る。
- fixture は、使う範囲がいちばん狭い場所に置く。複数のテスト module で使うものだけを `conftest.py` に置く。
- 対応する既存テストがあれば、そこに書き足す。
- 新しいテストファイルは、原則として `src/` の module と層の並びに合わせる。ただし、独立した振る舞いや、複数の部品をつないで確かめるテストは別ファイルにしてよい。`_cli/<name>.py` は `tests/_cli/test_<name>.py`、`pipelines/<name>.py` は `tests/pipelines/test_<name>.py` を基本とする。

## Git operations

- コミットは、ユーザーに頼まれなくても、会話で許可を取らずに `git commit` を試してよい。
- 実行してよいかどうかは、各エージェントに設定済みの hook や rules が判定する。その判定に従う。
- push と、Git の履歴・ref・worktree・remote を変える操作は、ユーザーがはっきり頼んだときだけ行う。

## Notebooks

`notebooks/` の notebook は marimo の `.py` ファイル（`.ipynb` ではない）で、上から下までエラーなく実行できる必要がある。`ruff check` と `ty` は notebook を見ないので、代わりに `marimo check`（`poe nb-check`）がチェックする。整形は `ruff format` が notebook も対象にする。notebook の処理やデータの流れを変えたときは、必要な data が手元にあれば `marimo export html` などで上から下まで実行して確かめる。実行できないときは、確かめていないことと、その理由を報告する。

## Templates

notebook・PR・issue を新しく作るときは、まず対応する template を見て、そこから始める。task に関係する section だけを使い、関係ない section や、中身が空の項目は残さない。

- ノートブック（レポート系）: `notebooks/_template_qc.py`（QC 用）、`notebooks/_template_hypothesis.py`（仮説検証用）
- PR: `.github/pull_request_template.md`
- issue: `.github/ISSUE_TEMPLATE/`（`bug_fix.yml` / `change.yml` / `research.yml`）

## Index

必要に応じて参照：

- 各サブパッケージが何をするか → `docs/dev/architecture.md`
- パイプラインと CLI の全体像、最初に動かす手順 → `README.md`
- 開発環境（docker compose: `make up` / `make shell`）の作り方 → `docs/dev/container.md`

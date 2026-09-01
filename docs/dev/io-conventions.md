# 入出力の決まり

どのファイルをどこに置くか。`.gitignore` がこの決まりを実際に守らせている。

## ディレクトリ

| 場所                      | 何を置くか                                                       | git に入るか         |
| ------------------------- | ---------------------------------------------------------------- | -------------------- |
| `data/raw/`               | 元データ。手で置くか、取得スクリプトで落とす。**書き換えない。** | 入らない             |
| `data/external/`          | 外から持ってきた参照データ（対応表・コード一覧など）             | 入らない             |
| `data/meta/`              | 入力の一覧を書いた `.toml`。手で書く、変更を追いたい約束事       | **`.toml` だけ入る** |
| `data/processed/<stage>/` | プログラムが読むための出力（`.tsv`・`.npz`・`.txt` など）        | 入らない             |
| `results/<stage>/`        | 人が見るための図（`.png`・`.svg` など）                          | 入らない             |
| `reports/`                | notebook から書き出した `.html`                                  | **入る**             |
| `notebooks/`              | marimo の `.py`                                                  | 入る                 |
| `scripts/`                | 補助スクリプト                                                   | 入る                 |
| `src/myproject/`          | ライブラリ本体                                                   | 入る                 |
| `tests/`                  | テスト                                                           | 入る                 |
| `docs/`                   | ドキュメント                                                     | 入る                 |

`<stage>` は stage サブパッケージの名前（`example_stage` など）。

## なぜ `reports/` だけ git に入るのか

`data/` と `results/` は作り直せる。元データとコードがあれば同じものが出る。
`reports/` の HTML は「そのとき何を見て、どう判断したか」の記録なので、作り直せない。だから commit する。

このため、notebook が HTML に書き出す path は必ず **repo 相対**にする。絶対 path を書くと、誰か1人のマシンの構成が記録に焼き付く。`repo_root(Path(__file__))` を起点にするのはこのため。

## `.gitignore` の該当部分

```gitignore
data/**
!data/**/
!data/**/.gitkeep
# input manifests are hand-written, committed contracts (derived manifests stay ignored)
!data/meta/*.toml

results/*
!results/.gitkeep
```

`data/` と `results/` は中身を無視し、ディレクトリの形（`.gitkeep`）だけ残す。`data/meta/*.toml` は例外で、手で書いた入力の一覧なので commit する。

ほかに、次の場所は「ローカル専用」として無視される。中身を見てよいが、git 管理下のファイルからこれらの path を参照しない。

- `__local__/` — 自分の環境でしか動かないスクリプト（社内サーバから落とす、など）
- `__archive__/` — 捨てる前に置いておくもの
- `tmp/` — 一時的な確認用の出力
- `CONTEXT.md`・`docs/adr/` — git に入れない決定の記録

## notebook の名前

`scripts/export_notebooks.sh` は次の2つの glob だけを拾って `reports/*.html` に書き出す。

```
notebooks/qc_*.py
notebooks/hypothesis_*.py
```

つまり、書き出したい notebook は **`qc_` か `hypothesis_` で始める**。テンプレート（`_template_qc.py`・`_template_hypothesis.py`）は `_` で始まるので拾われない。

```bash
cp notebooks/_template_qc.py notebooks/qc_input_coverage.py
# 中身を書く
scripts/export_notebooks.sh
# -> reports/qc_input_coverage.html
```

## pipeline から出力先を決める

出力先は手で書かず、`pipelines/<stage>.py` の `stage_output_paths()` に集める。

```python
def stage_output_paths(root: Path) -> tuple[Path, Path]:
    return (
        root / "data" / "processed" / STAGE / "summary.tsv",
        root / "results" / STAGE / "summary.png",
    )
```

`root` を引数にしておくと、テストで `tmp_path` を渡せる。テストが本物の `data/` を汚さない。

# Architecture

`myproject` は、データ解析プロジェクトの雛形。解析は **stage**（段階）に分け、各 stage を3つの層にまたがって書く。

いま入っているのは `example_stage` だけ。中身は「表を読んで、数値列ごとに件数・平均・標準偏差を出す」という、置き換えられる前提の例。

## 3つの層

```
src/myproject/
├── example_stage/summarize.py   ← 層1: 解析そのもの
├── pipelines/example_stage.py   ← 層2: 動かす手順と file の読み書き
└── _cli/example_stage.py        ← 層3: Typer との橋渡し
```

### 層1: stage サブパッケージ（`example_stage/`）

解析そのものの処理を持つ。**file を読み書きしない。** 入力も出力も Python の値（DataFrame・配列・数値）にする。

```python
def summarize_table(table: pd.DataFrame) -> pd.DataFrame:
```

こうしておくと、テストに一時ファイルが要らない。`tests/example_stage/test_summarize.py` は小さな DataFrame を渡すだけで済む。

### 層2: `pipelines/<stage>.py`

stage を動かす手順を持つ。file を読み、層1を呼び、決まった場所に書く。

```python
def stage_output_paths(root: Path) -> tuple[Path, Path]:  # 出力先の決まり
def run(input_table: Path, root: Path) -> tuple[Path, Path]:  # 手順
```

出力先を `stage_output_paths` に切り出してあるので、「この stage は何を作るのか」を1か所で読める。置き場所の決まりは `io-conventions.md` を参照。

### 層3: `_cli/<stage>.py`

Typer との橋渡しだけ。コマンドラインの文字列を値に変え、層2を呼び、書いた場所を表示する。**解析も file の読み書きもここに置かない。**

`_cli/main.py` が各 stage の Typer app をまとめ、`pyproject.toml` の
`myproject = "myproject._cli.main:app"` がその入口を指す。

## データの流れ

```
data/raw/ または data/external/
        │  （手で置く、または取得スクリプトで置く）
        ▼
  _cli/<stage>.py  ──呼ぶ──▶  pipelines/<stage>.py
                                    │  読む
                                    ▼
                            <stage>/*.py（純粋な処理）
                                    │  返す
                                    ▼
              data/processed/<stage>/  と  results/<stage>/
                                    │
                                    ▼
                       notebooks/ が読んで reports/*.html を作る
```

## 共通の部品

- `paths.py` — `repo_root(start)`。`pyproject.toml` を持つ一番近い上位ディレクトリを返す。notebook も pipeline も、これを起点に repo 相対の path を組む。絶対 path を書かないため。
- `figures/plot_style.py` — `use_plot_style()`。すべての図を同じ見た目に揃える。

## stage を足す

1. `src/myproject/<stage>/` を作り、処理を純粋な関数として書く。
1. `src/myproject/pipelines/<stage>.py` に `stage_output_paths` と `run` を書く。
1. `src/myproject/_cli/<stage>.py` に Typer の command を書く。
1. `_cli/main.py` に `app.add_typer(<stage>.app, name="<stage>")` を足す。
1. テストを層ごとに置く（`tests/<stage>/`・`tests/pipelines/`・`tests/_cli/`）。

`example_stage` を丸ごと真似すれば、この5つはそのままなぞれる。

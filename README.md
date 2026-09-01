# myproject

データ解析プロジェクトの雛形。`uv` + Docker + AI コーディングエージェント向けの設定を最初から揃えてある。

`myproject` は差し替える前提の仮の名前。`scripts/rename_project.sh` で一括で変えられる。

## 入っているもの

- **Python 環境** — `uv`、Python 3.12 固定、`uv.lock` 付き
- **品質チェック** — `ruff`（format + lint）、`ty`（型）、`pytest`、`deptry`、pre-commit（`prek`）
- **解析プロジェクトの骨組み** — 3層に分けた stage 構造、`data/`・`results/`・`reports/` の置き場所の決まり
- **notebook** — marimo（`.py` 形式）と、QC 用・仮説検証用のテンプレート2種
- **開発コンテナ** — `docker compose` で Ubuntu 環境を立てる。VS Code Dev Containers 対応
- **CI** — GitHub Actions で format・lint・型・テストを回す
- **エージェント設定** — Claude Code と Codex の共通指針（`AGENTS.md`）、git 操作を止める hook、PR / issue テンプレート

## 最初にやること

### 1. git repository にする

`uv` も `docker/sync-env.sh` も、version を git の tag から取る。tag が無いと動かない。

```bash
git init
git add -A
git commit -m "chore: start from the template"
git tag v0.1.0
```

### 2. 名前を変える

```bash
scripts/rename_project.sh my_analysis
```

`myproject` を使っている場所（`pyproject.toml`・`src/`・docker の path・Makefile など）をまとめて置き換える。名前は Python の識別子として使える形（小文字・数字・`_`、数字始まりは不可）にする。

### 3. 動かす

```bash
uv sync --all-groups     # 依存パッケージを入れる
uv run pytest            # テスト
uv run poe code-check    # format・lint・型・notebook のチェック
uv run myproject --help  # CLI
```

コンテナで開発するなら、代わりに `make up && make shell`。詳しくは [docs/dev/container.md](docs/dev/container.md)。

## ディレクトリ

```
src/myproject/    ライブラリ本体。stage を3層に分けて書く
tests/            テスト。src/ の層の並びに合わせる
notebooks/        marimo の notebook（.py 形式）
data/             入力と中間出力。git に入らない
results/          図。git に入らない
reports/          notebook から書き出した HTML。git に入る
scripts/          補助スクリプト
docs/dev/         設計・入出力・コンテナの説明
docker/           コンテナの定義と setup
```

- 3層の分け方と stage の足し方 → [docs/dev/architecture.md](docs/dev/architecture.md)
- どのファイルをどこに置くか → [docs/dev/io-conventions.md](docs/dev/io-conventions.md)
- コンテナの使い方 → [docs/dev/container.md](docs/dev/container.md)
- エージェントへの指針 → [AGENTS.md](AGENTS.md)（`CLAUDE.md` は symlink）

## 例として入っている `example_stage`

「表を読んで、数値列ごとに件数・平均・標準偏差を出す」だけの stage。3層それぞれに置いた最小の例なので、真似したら消してよい。

```bash
printf 'label\tvalue\na\t1\nb\t2\nc\t3\n' > /tmp/input.tsv
uv run myproject example-stage summarize --input /tmp/input.tsv
# -> data/processed/example_stage/summary.tsv
# -> results/example_stage/summary.png
```

## 使う前に決めること

このテンプレートには、元の環境の都合がそのまま残っている部分がある。自分の環境に合わせて直すか、消す。

**ホストのデータ mount** — `docker-compose.yml` の末尾で `/work`・`/work2`・`/work3` を mount する。実在しない環境では、`.env` で `WORK_MOUNT_SOURCE` などを向け直すか、その3行を消す（`.env.example` を参照）。

**statusline が token を読む** — `docker/statusline.sh` は利用量を出すために、Claude の OAuth token を macOS Keychain・`~/.claude/.credentials.json`・Linux keyring から読み、`https://api.anthropic.com/api/oauth/usage` に問い合わせる。不要なら `.claude/settings.json` の `statusLine` を消す。

**agent skill** — `docker/Dockerfile` の末尾で外部の skill を4つ入れる。`docs/agents/` の内容はそのうち `mattpocock/skills` を前提にしている。要らない行は消してよい。

**個人の設定** — `.claude/settings.json` には git 操作を止める hook と statusline だけを入れてある。model や effort など自分だけの設定は `.claude/settings.local.json` に書く（git に入らない）。

**release の自動化は入っていない** — CI は format・lint・型・テストだけ。リリース手順は各自で足す。

## ライセンス

MIT。`LICENSE` の著作権者を自分の名前に変える。

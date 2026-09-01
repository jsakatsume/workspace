# myproject

データ解析プロジェクトの雛形。`uv` + Docker + AI コーディングエージェント向けの設定を最初から揃えてある。

**開発は Docker コンテナの中で行う。** ホストに要るのは `git`・`make`・`docker` の3つだけ。Python も `uv` もホストには入れない。

`myproject` は差し替える前提の仮の名前。`scripts/rename_project.sh` で一括で変えられる。

## Quick start

Docker が動いていること（Docker Desktop か Docker Engine）が前提。

### A. テンプレートから新しく始める

ホストで実行する。

```bash
scripts/rename_project.sh my_analysis    # 1. 名前を変える
git init && git add -A && git commit -m "chore: start from the template"
git tag v0.1.0                           # 2. tag が無いと 4 が失敗する
cp .env.example .env                     # 3. ホストの mount を合わせる
make up                                  # 4. build して起動（初回は数分）
make shell                               # 5. コンテナに入る
```

この順番になる理由：

1. **名前が先。** compose の `working_dir`・image 名・entrypoint の path に `myproject` が入っている。`make up` の後で変えると、古い名前のコンテナと volume が取り残される。
1. **tag が無いと止まる。** `docker/sync-env.sh` が image のタグを `git describe --tags --abbrev=0` から取る。tag が無いと `make up` はここで失敗する。
1. **`.env` はホストごとの設定。** `docker-compose.yml` はホストの `/work`・`/work2`・`/work3` を mount する。手元に無いなら、`.env` で実在する path に向け直すか、`docker-compose.yml` からその3行を消す（→ 後の「使う前に決めること」）。`.env` は git に入らない。

`make up` は先に `docker/sync-env.sh` を走らせ、`.env` に `IMAGE_TAG`・`HOST_UID`・`HOST_GID` を書く。`docker compose` を直接叩くとこれが走らず、`IMAGE_TAG` 未設定で失敗する。

### B. すでにある repo に参加する

```bash
git clone <url> && cd <repo>
cp .env.example .env   # 必要なら path を直す
make up && make shell
```

### C. コンテナの中で動かす

`make up` の中で `docker/setup.sh` が `uv sync --all-groups` まで済ませている。入ったらそのまま動く。

```bash
uv run pytest              # テスト
uv run poe code-check      # format・lint・型・notebook のチェック
uv run my_analysis --help  # CLI（A で付けた名前。変えていなければ myproject）
```

A で名前を変えたときだけ、最初に一度 lock を作り直す。`uv.lock` は `scripts/rename_project.sh` の書き換え対象から外してあるため。

```bash
uv lock && uv sync --all-groups
```

コンテナから `git push` するなら、一度だけ `gh auth login` する。コンテナに SSH 鍵は無いので、`docker/setup.sh` が GitHub の remote を HTTPS に向け、`gh` の token を認証に使う。

## 日々のコマンド

ホストで（コンテナの操作）：

| コマンド     | 何をするか                                  |
| ------------ | ------------------------------------------- |
| `make up`    | build して起動し、setup が終わるまで待つ    |
| `make shell` | 動いているコンテナで bash を開く            |
| `make setup` | コンテナの中で setup をやり直す             |
| `make down`  | コンテナを止めて消す（named volume は残る） |

残りは `make help` で出る。詳しくは [docs/dev/container.md](docs/dev/container.md)。

コンテナの中で（開発）：

| コマンド                | 何をするか                            |
| ----------------------- | ------------------------------------- |
| `uv run pytest`         | テスト                                |
| `uv run poe code-check` | format・lint・型・notebook を見るだけ |
| `uv run poe code-fix`   | 直せるものを直す                      |
| `uv sync --all-groups`  | 依存パッケージを揃え直す              |

VS Code で書くなら、`make up` の後に **Attach to Running Container** で入る。`.devcontainer/devcontainer.json` は置いていないので、「Reopen in Container」は使わない。

コンテナを使わず、ホストに `uv` を入れて直接動かすこともできる（→ [docs/dev/container.md](docs/dev/container.md)）。

## 入っているもの

- **開発コンテナ** — `docker compose` で Ubuntu 環境を立てる。起動中のコンテナに VS Code から Attach できる
- **Python 環境** — `uv`、Python 3.12 固定、`uv.lock` 付き
- **品質チェック** — `ruff`（format + lint）、`ty`（型）、`pytest`、`deptry`、pre-commit（`prek`）
- **解析プロジェクトの骨組み** — 3層に分けた stage 構造、`data/`・`results/`・`reports/` の置き場所の決まり
- **notebook** — marimo（`.py` 形式）と、QC 用・仮説検証用のテンプレート2種
- **CI** — GitHub Actions で format・lint・型・テストを回す
- **エージェント設定** — Claude Code と Codex の共通指針（`AGENTS.md`）、git 操作を止める hook、PR / issue テンプレート

## ディレクトリ

repo はコンテナの `/workspaces/myproject` に bind mount される。ホストで編集した内容はそのままコンテナに見える。

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

「表を読んで、数値列ごとに件数・平均・標準偏差を出す」だけの stage。3層それぞれに置いた最小の例なので、真似したら消してよい。コンテナの中で動かす。

```bash
printf 'label\tvalue\na\t1\nb\t2\nc\t3\n' > /tmp/input.tsv
uv run myproject example-stage summarize --input /tmp/input.tsv
# -> data/processed/example_stage/summary.tsv
# -> results/example_stage/summary.png
```

## 使う前に決めること

このテンプレートには、元の環境の都合がそのまま残っている部分がある。自分の環境に合わせて直すか、消す。

**ホストのデータ mount** — `docker-compose.yml` の末尾で `/work`・`/work2`・`/work3` を mount する。実在しない環境では、`.env` で `WORK_MOUNT_SOURCE` などを向け直すか、その3行を消す（`.env.example` を参照）。`MOUNT_ACCESS_MODE=ro` にしておくと、元データを誤って書き換えずに済む。

**statusline が token を読む** — `docker/statusline.sh` は利用量を出すために、Claude の OAuth token を macOS Keychain・`~/.claude/.credentials.json`・Linux keyring から読み、`https://api.anthropic.com/api/oauth/usage` に問い合わせる。不要なら `.claude/settings.json` の `statusLine` を消す。

**agent skill** — `docker/Dockerfile` の末尾で外部の skill を4つ入れる。`docs/agents/` の内容はそのうち `mattpocock/skills` を前提にしている。要らない行は消してよい。

**個人の設定** — `.claude/settings.json` には git 操作を止める hook と statusline だけを入れてある。model や effort など自分だけの設定は `.claude/settings.local.json` に書く（git に入らない）。

**release の自動化は入っていない** — CI は format・lint・型・テストだけ。リリース手順は各自で足す。

## ライセンス

MIT。`LICENSE` の著作権者を自分の名前に変える。

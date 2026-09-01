# 開発コンテナ

`docker compose` で Ubuntu のコンテナを立て、その中で開発する。ターミナルから `make up && make shell` で入る。VS Code で書くなら、立てておいたコンテナに Attach する（後述）。

コンテナを使わず、ホストで直接開発してもよい。ホストに `uv` を入れて `uv sync --all-groups` すれば動く。その場合、この文書の残りは読まなくてよい。

## 使う前に

`docker/sync-env.sh` は image のタグを **git の release tag** から取る。tag が無いと `make up` は止まる。

```bash
git init && git add -A && git commit -m "chore: start from the template"
git tag v0.1.0
```

## コマンド

```bash
make up       # image を build（必要なら）してコンテナを起動し、setup 完了まで待つ
make shell    # 動いているコンテナで bash を開く
make setup    # コンテナの中で setup をやり直す（何度実行してもよい）
make build    # image を build する
make lock     # mise の lock（docker/mise/mise.lock）を更新する
make rebuild  # cache を使わず image を build し直す
make logs     # ログを追う
make down     # コンテナを止めて消す（named volume は残る）
```

`make up` は先に `docker/sync-env.sh` を走らせ、`.env` に `IMAGE_TAG`・`HOST_UID`・`HOST_GID` を書く。`docker compose` を直接叩くとこれが走らないので、`IMAGE_TAG` 未設定で失敗する。

コンテナ名と volume 名には `COMPOSE_PROJECT_NAME=myproject-$USER` が付く（`Makefile`）。共有サーバで複数人が同じ repo を使っても衝突しない。

## VS Code から入る

`.devcontainer/devcontainer.json` は置いていない。だから「Reopen in Container」は使えない。代わりに、動いているコンテナに Attach する。

1. ターミナルで `make up`。`.env` を書き、image を build し、setup 完了まで待つ。
1. Dev Containers 拡張を入れ、コマンドパレットで **Dev Containers: Attach to Running Container** を選ぶ。
1. `myproject-<ユーザー名>-dev-1` を選び、開いたウィンドウで `/workspaces/myproject` を開く。

## 中で何が起きるか

1. `docker/entrypoint.sh` が `docker/setup.sh` を呼ぶ。
1. `docker/setup.sh` が、毎回同じ結果になる形で次を行う。
    - named volume の持ち主を `ubuntu` に直す
    - `/var/run/docker.sock` の GID に合わせてグループを作り、`ubuntu` を入れる
    - `uv python install 3.12` と `uv sync --all-groups`
    - `prek install`（git hook）
    - agent の設定を symlink する（`docker/CLAUDE.md` を `~/.claude/CLAUDE.md` などへ）
    - herdr の連携を入れる
    - GitHub の SSH remote を HTTPS に書き換え、`gh` の token を認証に使う
1. 終わったら `/tmp/.devcontainer-ready` を作る。compose の healthcheck がこれを見るので、`make up` は setup 完了まで返らない。

## 残るもの（named volume）

`.venv` は bind mount 上にあるので、`uv sync` で作り直せる。作り直しに時間がかかるものだけ volume に置く。

| volume            | 中身                           |
| ----------------- | ------------------------------ |
| `uv-cache`        | uv のダウンロードキャッシュ    |
| `uv-python`       | uv が入れた Python             |
| `claude-config`   | `~/.claude`                    |
| `codex-config`    | `~/.codex`                     |
| `herdr-state`     | herdr のレイアウトとセッション |
| `herdr-worktrees` | herdr が作る worktree          |
| `gh-config`       | `gh` の OAuth token            |

`make down` では消えない。消したいときは `docker volume rm` を使う。

## Docker-out-of-Docker

`/var/run/docker.sock` をホストから mount している。コンテナの中で `docker` を叩くと、**ホストの** daemon が動く。コンテナの中に daemon は無い。

## ホストのデータを mount する

`docker-compose.yml` の末尾で、ホストの `/work`・`/work2`・`/work3` をコンテナに mount している。これはこのテンプレートの元になった環境の名残。

```yaml
- ${WORK_MOUNT_SOURCE:-/work}:/work:${MOUNT_ACCESS_MODE:-rw}
```

自分の環境に合わせて、次のどれかにする。

- `.env` で `WORK_MOUNT_SOURCE` などを実在する path に向ける（`.env.example` を参照）
- 使わないなら、`docker-compose.yml` からその3行を消す

`MOUNT_ACCESS_MODE=ro` にしておくと、元データを誤って書き換えずに済む。

## statusline

`.claude/settings.json` は statusline に `docker/statusline.sh` を使う（`docker/setup.sh` が `~/.claude/statusline.sh` へ symlink する）。

このスクリプトは model 名・コンテキスト量・git branch などを出すが、**利用量の表示のために Claude の OAuth token を読む**。読む先は macOS の Keychain、`~/.claude/.credentials.json`、Linux の keyring。読んだ token は `https://api.anthropic.com/api/oauth/usage` への問い合わせにだけ使い、結果を `/tmp/claude/statusline-usage-cache.json` にキャッシュする。

これが不要なら、`.claude/settings.json` の `statusLine` を消す。表示の時刻帯は `STATUSLINE_TZ` 環境変数で変えられる（既定は `UTC`）。

## agent skill

`docker/Dockerfile` の末尾で、外部の agent skill を4つ入れている。

```dockerfile
RUN npx skills@latest add mattpocock/skills -g -a claude-code -a codex -y \
    && npx skills@latest add marimo-team/skills -g -a claude-code -a codex -y \
    && npx skills@latest add ogulcancelik/herdr -g -a claude-code -a codex -y \
    && npx skills@latest add marimo-team/marimo-pair -g -a claude-code -a codex -y
```

`docs/agents/` の内容（issue tracker の使い方、triage label、CONTEXT.md の読み方）は `mattpocock/skills` を前提にしている。要らない行は消してよい。

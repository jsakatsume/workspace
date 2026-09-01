# Pin tool images as named stages so Dependabot tracks them (its docker updater
# only reads `FROM`, not `COPY --from=<image>`). The copies below reference these.
FROM ghcr.io/astral-sh/uv:0.12.5 AS uv
FROM ghcr.io/j178/prek:0.4.14 AS prek
FROM ghcr.io/jdx/mise:2026.8.10 AS mise
FROM docker:29.7.2-cli AS docker-cli

FROM ubuntu:24.04

RUN apt-get update && \
    apt-get install --no-install-recommends -y \
        bubblewrap ca-certificates curl file gcc git git-lfs jq sudo vim && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# UTF-8 locale (handles non-ASCII incl. Japanese text without locale-gen)
ENV LANG=C.UTF-8

# grant the image's default non-root user passwordless sudo (setup.sh relies on it)
RUN echo 'ubuntu ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/ubuntu && chmod 0440 /etc/sudoers.d/ubuntu

ARG HOST_UID=1000
ARG HOST_GID=1000

RUN set -eux; \
    if getent group "${HOST_GID}" >/dev/null; then \
        usermod -u "${HOST_UID}" -g "${HOST_GID}" ubuntu; \
    else \
        groupmod -g "${HOST_GID}" ubuntu; \
        usermod -u "${HOST_UID}" -g "${HOST_GID}" ubuntu; \
    fi; \
    chown -R "${HOST_UID}:${HOST_GID}" /home/ubuntu

# install uv (dev environment: pinned bootstrap)
COPY --from=uv /uv /uvx /usr/local/bin/
RUN uv --version

# install prek (dev environment: git hooks)
COPY --from=prek /prek /usr/local/bin/prek
RUN chmod +x /usr/local/bin/prek

# install mise (tool-environment manager) from its published image. noble's glibc
# (2.39) satisfies the image binary, so a direct copy replaces the install script.
COPY --from=mise /usr/local/bin/mise /usr/local/bin/mise
RUN mise --version

# install the Docker CLI (+ compose/buildx plugins) for Docker-out-of-Docker
# from the Docker Official Image, matching the pinned-COPY pattern used for uv/
# prek/mise above. The daemon is the host's, reached via the mounted
# /var/run/docker.sock (see docker-compose.yml and docker/setup.sh); no daemon
# runs in this container.
COPY --from=docker-cli /usr/local/bin/docker /usr/local/bin/docker
COPY --from=docker-cli /usr/local/libexec/docker/cli-plugins/ /usr/local/libexec/docker/cli-plugins/
RUN docker --version

USER ubuntu
WORKDIR /home/ubuntu

# Pre-create the named-volume mount-point parents as ubuntu. Otherwise Docker
# creates /home/ubuntu/.cache and /home/ubuntu/.local as root, and ubuntu can't
# create sibling dirs at runtime — breaking prek (.cache/prek), uv (.local/bin)
# and the VS Code server (.cache/Microsoft).
RUN mkdir -p /home/ubuntu/.cache/uv /home/ubuntu/.local/bin /home/ubuntu/.local/share/uv

# put mise-managed tool shims on PATH for every (incl. non-interactive) context
ENV PATH="/home/ubuntu/.local/share/mise/shims:${PATH}"

# install the tool environment at build time, pinned by mise.lock
COPY --chown=ubuntu:ubuntu docker/mise/config.toml docker/mise/mise.lock /home/ubuntu/.config/mise/
RUN mise install --locked

# add agent skills (uses node provided by mise)
RUN mkdir -p /home/ubuntu/.claude /home/ubuntu/.codex
RUN npx skills@latest add mattpocock/skills -g -a claude-code -a codex -y \
    && npx skills@latest add marimo-team/skills -g -a claude-code -a codex -y \
    && npx skills@latest add ogulcancelik/herdr -g -a claude-code -a codex -y \
    && npx skills@latest add marimo-team/marimo-pair -g -a claude-code -a codex -y

# add uv completion + starship prompt to bashrc, and auto-activate the project
# venv on shell entry so `python`/`pytest`/`ruff` work directly (a bare `make
# shell` is otherwise non-activated). `uv run` still works; guarded so the line
# is harmless before the first `uv sync`.
RUN echo 'eval "$(uv generate-shell-completion bash)"' >> /home/ubuntu/.bashrc \
    && echo 'eval "$(starship init bash)"' >> /home/ubuntu/.bashrc \
    && echo 'if [ -f /workspaces/myproject/.venv/bin/activate ]; then . /workspaces/myproject/.venv/bin/activate; fi' >> /home/ubuntu/.bashrc

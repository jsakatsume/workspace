#!/usr/bin/env bash
set -euo pipefail

# Idempotent container setup. Run by docker/entrypoint.sh on every start and
# re-runnable by hand via `make setup`. Works regardless of the entry path
# (VS Code Dev Containers or a plain `docker compose up`).
workspace="${containerWorkspaceFolder:-/workspaces/myproject}"
cd "${workspace}"

fix_volume_ownership() {
    sudo chown -R ubuntu:ubuntu \
        /home/ubuntu/.cache/uv \
        /home/ubuntu/.local/share/uv \
        /home/ubuntu/.config/gh

    # These mount points are empty or image-seeded when their named volumes are
    # first created. Only their roots need correction; their contents are
    # created by the unprivileged user.
    sudo mkdir -p \
        /home/ubuntu/.codex \
        /home/ubuntu/.config/herdr \
        /home/ubuntu/.herdr/worktrees
    sudo chown ubuntu:ubuntu \
        /home/ubuntu/.codex \
        /home/ubuntu/.config/herdr \
        /home/ubuntu/.herdr \
        /home/ubuntu/.herdr/worktrees
}

configure_docker_socket() {
    # Docker-out-of-Docker: grant the ubuntu user non-sudo access to the mounted
    # host socket by adding it to a group matching the socket's GID. Reads the
    # live socket so it self-corrects without a rebuild; no-op when unmounted.
    local sock=/var/run/docker.sock
    [ -S "${sock}" ] || return 0
    local gid grp
    gid="$(stat -c '%g' "${sock}")"
    grp="$(getent group "${gid}" | cut -d: -f1 || true)"
    if [ -z "${grp}" ]; then
        if getent group docker-host >/dev/null; then
            sudo groupmod -g "${gid}" docker-host
        else
            sudo groupadd -g "${gid}" docker-host
        fi
        grp=docker-host
    fi
    if ! id -nG ubuntu | tr ' ' '\n' | grep -qx "${grp}"; then
        sudo usermod -aG "${grp}" ubuntu
    fi
}

sync_python_environment() {
    uv python install 3.12
    uv sync --all-groups
}

install_git_hooks() {
    prek install
}

link_agent_config() {
    mkdir -p /home/ubuntu/.agents /home/ubuntu/.claude/skills /home/ubuntu/.codex

    ln -sfn "${workspace}/docker/CLAUDE.md" /home/ubuntu/.claude/CLAUDE.md
    ln -sfn "${workspace}/docker/CLAUDE.md" /home/ubuntu/.agents/AGENTS.md
    ln -sfn "${workspace}/docker/CLAUDE.md" /home/ubuntu/.codex/AGENTS.md
    ln -sfn "${workspace}/docker/statusline.sh" /home/ubuntu/.claude/statusline.sh

    # The persisted Claude config volume hides image-created links. Recreate
    # them from the canonical global skill directory on every container start.
    local skill_dir skill_name target synced=0
    for skill_dir in /home/ubuntu/.agents/skills/*; do
        [ -d "${skill_dir}" ] || continue
        skill_name="${skill_dir##*/}"
        target="/home/ubuntu/.claude/skills/${skill_name}"
        if [ -e "${target}" ] && [ ! -L "${target}" ]; then
            echo "Claude skill already exists, leaving it unchanged: ${target}" >&2
            continue
        fi
        ln -sfn "../../.agents/skills/${skill_name}" "${target}"
        synced=$((synced + 1))
    done

    # Linking nothing means the canonical directory moved, not that every skill
    # was removed — leave the volume's links alone rather than pruning them all.
    if [ "${synced}" -eq 0 ]; then
        echo "No canonical global skills found; left /home/ubuntu/.claude/skills untouched." >&2
        return 0
    fi

    # Skills come from rolling-latest sources, so upstream renames leave links
    # behind in the volume. Retire ours; never touch links pointing elsewhere.
    for target in /home/ubuntu/.claude/skills/*; do
        [ -L "${target}" ] || continue
        [ -e "${target}" ] && continue
        case "$(readlink "${target}")" in
            */.agents/skills/*) rm -f "${target}" ;;
        esac
    done
}

configure_herdr_integrations() {
    local agent status

    herdr integration install claude
    herdr integration install codex

    status="$(herdr integration status)"
    printf '%s\n' "${status}"
    for agent in claude codex; do
        if ! grep -q "^${agent}: current " <<<"${status}"; then
            echo "Herdr ${agent} integration is not current." >&2
            return 1
        fi
    done
}

reload_herdr_config() {
    local result status
    status="$(herdr status server 2>/dev/null || true)"
    if grep -q '^status: running$' <<<"${status}"; then
        if ! result="$(herdr server reload-config)"; then
            printf '%s\n' "${result}"
            echo "Herdr config reload command failed." >&2
            return 1
        fi
        printf '%s\n' "${result}"
        if ! jq -e \
            '.result.status == "applied" and .result.diagnostics == []' \
            <<<"${result}" >/dev/null; then
            echo "Herdr config reload was not applied cleanly." >&2
            return 1
        fi
    fi
}

configure_git_https() {
    # The repo is bind-mounted from the host, where origin is an SSH URL
    # (git@github.com:…), but the container ships no SSH key/agent. Rewrite GitHub
    # SSH remotes to HTTPS *globally* — never the shared repo .git/config — and let
    # gh's token serve as the credential. ~/.gitconfig is not a persisted volume,
    # so re-apply on every start. The token itself lives in the gh-config volume;
    # until the user runs `gh auth login` once, wire-up is skipped with a hint.
    git config --global url."https://github.com/".insteadOf "git@github.com:"
    if gh auth status >/dev/null 2>&1; then
        gh auth setup-git
    else
        echo "gh not authenticated — run 'gh auth login' once to enable git over HTTPS." >&2
    fi
}

fix_volume_ownership
configure_docker_socket
sync_python_environment
install_git_hooks
link_agent_config
configure_herdr_integrations
reload_herdr_config
configure_git_https

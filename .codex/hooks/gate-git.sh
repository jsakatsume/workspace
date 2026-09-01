#!/usr/bin/env bash
# Block destructive Git operations. Approval-required operations are handled by
# .codex/rules; hooks cannot request approval.

set -u

INPUT=$(cat)

command -v jq >/dev/null 2>&1 || exit 0
command -v uv >/dev/null 2>&1 || exit 0

TOOL_NAME=$(printf '%s' "$INPUT" | jq -r '.tool_name // .toolName // empty' 2>/dev/null) \
  || exit 0
[ "$TOOL_NAME" = "Bash" ] || exit 0

COMMAND=$(printf '%s' "$INPUT" | jq -r '.tool_input.command // .toolInput.command // empty' 2>/dev/null) \
  || exit 0
[ -n "$COMMAND" ] || exit 0

CODEX_GIT_GATE_COMMAND=$COMMAND \
  UV_CACHE_DIR="${TMPDIR:-/tmp}/myproject-codex-hook-uv-cache" \
  VIRTUAL_ENV= \
  uv run --no-sync python <<'PY'
import os
import re
import shlex
import sys


def shell_commands(source):
    lexer = shlex.shlex(source, posix=True, punctuation_chars=";&|()\n")
    lexer.whitespace = " \t\r"
    lexer.whitespace_split = True
    lexer.commenters = "#"
    command = []
    try:
        for token in lexer:
            if token and not token.strip(";&|()\n"):
                if command:
                    yield command
                    command = []
            else:
                command.append(token)
    except ValueError:
        return
    if command:
        yield command


def git_command(words):
    while words and re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*=.*", words[0]):
        words.pop(0)
    if not words or words[0].rsplit("/", 1)[-1] != "git":
        return None

    value_options = {
        "--config-env",
        "--exec-path",
        "--git-dir",
        "--namespace",
        "--super-prefix",
        "--work-tree",
        "-C",
        "-c",
    }
    index = 1
    while index < len(words):
        arg = words[index]
        if arg == "--":
            index += 1
            break
        if arg in value_options:
            index += 2
        elif arg.startswith("-"):
            index += 1
        else:
            return arg, words[index + 1 :]
    if index < len(words):
        return words[index], words[index + 1 :]
    return None


def has_short_option(args, option):
    return any(
        arg.startswith("-")
        and not arg.startswith("--")
        and option in arg[1:]
        for arg in args
    )


def first_operand(args):
    return next((arg for arg in args if not arg.startswith("-")), None)


def destructive_reason(subcommand, args):
    if subcommand == "push" and (
        any(
            arg in {"--mirror", "--prune"}
            or arg.startswith("--force")
            or arg.startswith("+")
            for arg in args
        )
        or has_short_option(args, "f")
    ):
        return "rewrites or broadly deletes remote refs"
    if subcommand == "reset" and "--hard" in args:
        return "discards local work with reset --hard"
    if subcommand == "clean" and (
        "--force" in args or has_short_option(args, "f")
    ):
        return "deletes untracked files with forced clean"
    if subcommand == "branch" and (
        "--force" in args
        or has_short_option(args, "D")
        or has_short_option(args, "f")
    ):
        return "force-moves or force-deletes a branch"
    if subcommand == "checkout" and "." in args:
        return "discards changes across the whole worktree"
    if subcommand == "restore" and "." in args:
        staged = "--staged" in args or has_short_option(args, "S")
        worktree = "--worktree" in args or has_short_option(args, "W")
        if not staged or worktree:
            return "discards changes across the whole worktree"
    if subcommand == "stash" and first_operand(args) in {"clear", "drop"}:
        return "deletes stash recovery data"
    if subcommand == "reflog" and first_operand(args) in {"delete", "expire"}:
        return "deletes reflog recovery data"
    if subcommand == "worktree" and first_operand(args) == "remove" and (
        "--force" in args or has_short_option(args, "f")
    ):
        return "force-removes a worktree"
    if subcommand == "gc" and "--prune=now" in args:
        return "immediately prunes unreachable recovery objects"
    if subcommand == "filter-branch":
        return "rewrites repository history with filter-branch"
    return None


for words in shell_commands(os.environ.get("CODEX_GIT_GATE_COMMAND", "")):
    parsed = git_command(words)
    if parsed is None:
        continue
    reason = destructive_reason(*parsed)
    if reason is not None:
        print(f"BLOCKED: '{shlex.join(words)}' {reason}.", file=sys.stderr)
        raise SystemExit(2)
raise SystemExit(0)
PY

#!/usr/bin/env bash
# Gate git commands behind a guardrail (Claude Code PreToolUse, matcher: Bash).
#
# Reads the tool-call JSON on stdin and, for the Bash command:
#   - blocks (exit 2) irreversible/destructive ops: force push, reset --hard,
#     clean -f, branch -D, checkout ., restore .
#   - asks (permissionDecision=ask) for `git commit` / non-force `git push`
#   - allows everything else (exit 0)
# Fails safe to "ask" when the input cannot be parsed.
#
# Pure bash + jq so it needs no project virtualenv (works in docker/worktrees).

set -u

# Emit a PreToolUse "ask" decision on stdout and exit 0.
ask() {
  cat <<EOF
{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"ask","permissionDecisionReason":"$1"}}
EOF
  exit 0
}

INPUT=$(cat)

# Fail safe to ask when jq is missing or the input is unparseable.
command -v jq >/dev/null 2>&1 || ask "git-gate hook: jq unavailable; asking to be safe"
TOOL_NAME=$(printf '%s' "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null) \
  || ask "git-gate hook could not parse input; asking to be safe"

[ "$TOOL_NAME" = "Bash" ] || exit 0

COMMAND=$(printf '%s' "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null) \
  || ask "git-gate hook could not parse input; asking to be safe"

# --- block tier: irreversible / destructive ops (exit 2) ---
# Force push is matched before the ask tier so normal push stays ask-only.
BLOCK_PATTERNS=(
  'git .*push .*--force'      # --force and --force-with-lease
  'git .*push .*-f($| )'      # short -f force flag
  'git .*reset .*--hard'
  'git .*clean .*-[A-Za-z]*f' # -f, -fd, -fdx, ...
  'git .*branch .*-D'
  'git checkout -- \.'        # git checkout -- .
  'git checkout \.'           # git checkout .
  'git restore -- \.'         # git restore -- .
  'git restore \.'            # git restore .
)
for p in "${BLOCK_PATTERNS[@]}"; do
  if printf '%s' "$COMMAND" | grep -qE "$p"; then
    echo "BLOCKED: '$COMMAND' is a destructive git operation (pattern: $p). You do not have authority to run this." >&2
    exit 2
  fi
done

# --- ask tier: needs manual approval (exit 0 with ask decision) ---
ASK_PATTERNS=(
  'git .*commit'
  'git .*push'
)
for p in "${ASK_PATTERNS[@]}"; do
  if printf '%s' "$COMMAND" | grep -qE "$p"; then
    ask "git commit/push requires manual approval"
  fi
done

exit 0

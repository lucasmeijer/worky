#!/bin/bash
set -euo pipefail

worktree_path=${1:-}
if [[ -z "$worktree_path" ]]; then
  echo "Usage: $0 <worktree-path>" >&2
  echo "no"
  exit 0
fi

if [[ ! -d "$worktree_path" ]]; then
  echo "Worktree not found: $worktree_path" >&2
  echo "no"
  exit 0
fi

# Ensure common paths are available when launched from GUI apps.
export PATH="/usr/local/bin:/opt/homebrew/bin:$HOME/.local/bin:$HOME/bin:/usr/bin:/bin:/usr/sbin:/sbin${PATH:+:$PATH}"

target_ref=${WORKY_RENAME_TARGET_REF:-origin/main}

committed_diff=""
if /usr/bin/env git -C "$worktree_path" rev-parse --verify "$target_ref" >/dev/null 2>&1; then
  if committed=$(/usr/bin/env git -C "$worktree_path" diff --no-color --no-ext-diff "$target_ref...HEAD" 2>/dev/null); then
    committed_diff=$committed
  fi
fi

staged_diff=$(/usr/bin/env git -C "$worktree_path" diff --cached --no-color --no-ext-diff)
unstaged_diff=$(/usr/bin/env git -C "$worktree_path" diff --no-color --no-ext-diff)
untracked_diff=""
while IFS= read -r -d '' file; do
  patch=$(/usr/bin/env git -C "$worktree_path" diff --no-color --no-ext-diff --no-index /dev/null "$file" 2>/dev/null || true)
  if [[ -n "$patch" ]]; then
    untracked_diff+="$patch"
    untracked_diff+=$'\n'
  fi
done < <(/usr/bin/env git -C "$worktree_path" ls-files --others --exclude-standard -z)

diff_output=""
if [[ -n "$committed_diff" ]]; then
  diff_output+="$committed_diff"
  diff_output+=$'\n'
fi
if [[ -n "$staged_diff" ]]; then
  diff_output+="$staged_diff"
  diff_output+=$'\n'
fi
if [[ -n "$unstaged_diff" ]]; then
  diff_output+="$unstaged_diff"
fi
if [[ -n "$untracked_diff" ]]; then
  diff_output+=$'\n'
  diff_output+="$untracked_diff"
fi

if [[ -z "$diff_output" ]]; then
  echo "no"
  exit 0
fi

prompt="Come up with a good branchname for the work in this git diff. The branchname must be a single slug with no slashes. If there is not enough context to come up with a good branchname respond with 'no'. Otherwise respond only with the new branchname."
claude_cmd="${CLAUDE_CMD:-claude}"
if ! /usr/bin/command -v "$claude_cmd" >/dev/null 2>&1; then
  for candidate in "$HOME/.local/bin/claude" "$HOME/bin/claude" "/opt/homebrew/bin/claude" "/usr/local/bin/claude"; do
    if [[ -x "$candidate" ]]; then
      claude_cmd="$candidate"
      break
    fi
  done
fi

if ! /usr/bin/command -v "$claude_cmd" >/dev/null 2>&1; then
  echo "Claude CLI not found in PATH or common locations." >&2
  echo "no"
  exit 0
fi
claude_args=()

if [[ -n "${CLAUDE_ARGS:-}" ]]; then
  # shellcheck disable=SC2206
  claude_args=(${CLAUDE_ARGS})
else
  if "$claude_cmd" --help </dev/null 2>&1 | /usr/bin/grep -q -- "--print"; then
    claude_args+=(--print)
  fi
fi

prompt_input="${prompt}\n\n${diff_output}"

set +e
suggestion=$(printf "%b" "$prompt_input" | "$claude_cmd" "${claude_args[@]}")
status=$?
set -e

if [[ $status -ne 0 ]]; then
  echo "no"
  exit 0
fi

suggestion=$(printf "%s" "$suggestion" | /usr/bin/head -n 1 | /usr/bin/tr -d '\r' | /usr/bin/sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
if [[ -z "$suggestion" ]]; then
  echo "no"
  exit 0
fi

lower=$(/usr/bin/printf "%s" "$suggestion" | /usr/bin/tr '[:upper:]' '[:lower:]')
if [[ "$lower" == "no" ]]; then
  echo "no"
  exit 0
fi

if /usr/bin/printf "%s" "$suggestion" | /usr/bin/grep -q '[[:space:]]'; then
  echo "no"
  exit 0
fi

current_branch=$(/usr/bin/env git -C "$worktree_path" rev-parse --abbrev-ref HEAD)
if [[ "$suggestion" == "$current_branch" ]]; then
  echo "no"
  exit 0
fi

/usr/bin/env git -C "$worktree_path" branch -m "$suggestion"

echo "$suggestion"

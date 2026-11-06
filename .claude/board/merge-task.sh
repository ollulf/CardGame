#!/usr/bin/env bash
set -u

branch="${1:?usage: merge-task.sh <task-branch>}"
godot="${GODOT:-/c/Users/maxbr/Downloads/Godot_v4.5.1-stable_win64.exe/Godot_v4.5.1-stable_win64_console.exe}"
root="$(git rev-parse --show-toplevel)"
merge_branch="$branch-merge"
slug="${branch//\//-}"
worktree="$root/.claude/worktrees/merge-$slug"
logs="$(mktemp -d)"

report() {
  echo "MERGE_BRANCH: $merge_branch"
  echo "MERGE_WORKTREE: $worktree"
  echo "MERGE_COMMIT: $(git -C "$worktree" rev-parse --short HEAD 2>/dev/null)"
  echo "OUTCOME: $1"
  echo "DETAIL: $2"
  echo "LOGS: $logs"
}

discard() {
  git -C "$root" worktree remove --force "$worktree"
  git -C "$root" branch -D "$merge_branch" >/dev/null
}

git -C "$root" rev-parse --verify --quiet "$branch" >/dev/null || { echo "OUTCOME: error"; echo "DETAIL: no branch $branch"; exit 1; }
git -C "$root" worktree add -q -B "$merge_branch" "$worktree" "$branch" || { echo "OUTCOME: error"; echo "DETAIL: could not create worktree"; exit 1; }

if ! git -C "$worktree" merge --no-edit -m "Merge main into $branch

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>" main >"$logs/merge.log" 2>&1; then
  files="$(git -C "$worktree" diff --name-only --diff-filter=U | tr '\n' ' ')"
  git -C "$worktree" merge --abort
  discard
  echo "OUTCOME: needs-agent"
  echo "DETAIL: conflicts in $files"
  exit 2
fi

changed="$(git -C "$worktree" diff --name-only main...HEAD)"

flagged="$(echo "$changed" | grep -iE '\.html?$|(^|/)docs/|\.md$' | grep -vE '^(README\.md|CLAUDE\.md|\.claude/)' | tr '\n' ' ')"
if [ -n "$flagged" ]; then
  discard
  echo "OUTCOME: needs-agent"
  echo "DETAIL: docs or HTML added to the repo: $flagged"
  exit 2
fi

if ! echo "$changed" | grep -q '^card-game/'; then
  report ready "checks skipped, no game files changed"
  exit 0
fi

if ls "$worktree"/card-game/tests/*.tscn >/dev/null 2>&1; then
  discard
  echo "OUTCOME: needs-agent"
  echo "DETAIL: card-game/tests exists, test scenes must be run"
  exit 2
fi

timeout 300 "$godot" --headless --path "$worktree/card-game" --import >"$logs/import.log" 2>&1
import_code=$?
timeout 120 "$godot" --headless --path "$worktree/card-game" --quit >"$logs/quit.log" 2>&1
quit_code=$?

errors="$(grep -hE 'SCRIPT ERROR|Parse Error|Failed to load|Could not find type|Failed loading' "$logs/import.log" "$logs/quit.log" | sort -u | head -5)"

git -C "$worktree" status --porcelain | awk '$1=="M"{print $2}' | grep -E '\.import$|project\.godot$' | while read -r f; do
  if ! echo "$changed" | grep -qxF "$f"; then
    git -C "$worktree" restore -- "$f"
  fi
done

if [ "$import_code" -ne 0 ] || [ "$quit_code" -ne 0 ] || [ -n "$errors" ]; then
  discard
  echo "OUTCOME: needs-agent"
  echo "DETAIL: checks failed (import exit $import_code, quit exit $quit_code): $errors"
  echo "LOGS: $logs"
  exit 2
fi

report ready "load check passed, gameplay not exercised"
exit 0

#!/usr/bin/env bash
set -u

[ $# -ge 1 ] || { echo "usage: merge-task.sh <task-branch> [<task-branch> ...]"; exit 1; }
godot="${GODOT:-/c/Users/maxbr/Downloads/Godot_v4.5.1-stable_win64.exe/Godot_v4.5.1-stable_win64_console.exe}"
root="$(git rev-parse --show-toplevel)"
if [ $# -eq 1 ]; then
  merge_branch="$1-merge"
else
  merge_branch="task/batch-$(date +%Y%m%d-%H%M%S)-merge"
fi
slug="${merge_branch//\//-}"
worktree="$root/.claude/worktrees/merge-$slug"
logs="$(mktemp -d)"
merged=()
skipped=()

report() {
  echo "MERGE_BRANCH: $merge_branch"
  echo "MERGE_WORKTREE: $worktree"
  echo "MERGE_COMMIT: $(git -C "$worktree" rev-parse --short HEAD 2>/dev/null)"
  echo "MERGED: ${merged[*]:-}"
  echo "SKIPPED: ${skipped[*]:-}"
  echo "OUTCOME: $1"
  echo "DETAIL: $2"
  echo "LOGS: $logs"
}

discard() {
  git -C "$root" worktree remove --force "$worktree"
  git -C "$root" branch -D "$merge_branch" >/dev/null
}

for b in "$@"; do
  git -C "$root" rev-parse --verify --quiet "$b" >/dev/null || { echo "OUTCOME: error"; echo "DETAIL: no branch $b"; exit 1; }
done

git -C "$root" worktree add -q -B "$merge_branch" "$worktree" main || { echo "OUTCOME: error"; echo "DETAIL: could not create worktree"; exit 1; }

for b in "$@"; do
  if git -C "$worktree" merge --no-edit -m "Merge $b into main

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>" "$b" >>"$logs/merge.log" 2>&1; then
    merged+=("$b")
  else
    files="$(git -C "$worktree" diff --name-only --diff-filter=U | tr '\n' ' ')"
    git -C "$worktree" merge --abort
    skipped+=("$b(conflicts: $files)")
  fi
done

if [ ${#merged[@]} -eq 0 ]; then
  discard
  echo "SKIPPED: ${skipped[*]}"
  echo "OUTCOME: needs-agent"
  echo "DETAIL: conflicts in every branch"
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

cache="$root/card-game/.godot"
if [ -d "$cache/imported" ]; then
  mkdir -p "$worktree/card-game/.godot"
  for item in imported uid_cache.bin global_script_class_cache.cfg scene_groups_cache.cfg; do
    [ -e "$cache/$item" ] && cp -r "$cache/$item" "$worktree/card-game/.godot/"
  done
fi

import_code=1
for attempt in 1 2 3; do
  timeout 300 "$godot" --headless --path "$worktree/card-game" --import >"$logs/import.log" 2>&1
  import_code=$?
  if [ "$import_code" -eq 0 ] && ! grep -q 'Failed loading resource: res://.godot/imported' "$logs/import.log"; then
    break
  fi
done
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
  echo "MERGED: ${merged[*]:-}"
  echo "SKIPPED: ${skipped[*]:-}"
  echo "OUTCOME: needs-agent"
  echo "DETAIL: checks failed (import exit $import_code, quit exit $quit_code): $errors"
  echo "LOGS: $logs"
  exit 2
fi

report ready "load check passed, gameplay not exercised"
exit 0

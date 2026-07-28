#!/usr/bin/env bash
# Install jira-git-sync OpenCode slash-commands (and skill) for the current user.
# Safe to re-run: overwrites existing symlinks.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
COMMANDS_SRC="$REPO_DIR/.opencode/commands"
COMMANDS_DST="${HOME}/.config/opencode/commands"
SKILL_DST="${HOME}/.agents/skills/jira-git-sync"

mkdir -p "$COMMANDS_DST" "${HOME}/.agents/skills"

# 1. Skill (router) — one symlink to the repo
ln -sfn "$REPO_DIR" "$SKILL_DST"
echo "skill:    $SKILL_DST -> $REPO_DIR"

# 2. Slash-commands — one symlink per wrapper file
for f in "$COMMANDS_SRC"/*.md; do
  name="$(basename "$f")"
  ln -sfn "$f" "$COMMANDS_DST/$name"
  echo "command:  $COMMANDS_DST/$name -> $f"
done

echo
echo "Done. Restart OpenCode, then try: /jira-new-branch DC-443"
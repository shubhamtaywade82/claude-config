#!/usr/bin/env bash
set -euo pipefail

# ─────────────────────────────────────────────
# Claude Config Sync
# Pulls latest skills FROM your machine INTO this repo
# Run this before committing to keep the repo current
# Usage: ./sync.sh
# ─────────────────────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GLOBAL_SKILLS_DIR="$HOME/.claude/skills"
WORKSPACE_ROOT="${WORKSPACE_ROOT:-$HOME/project}"

GREEN='\033[0;32m'
CYAN='\033[0;36m'
NC='\033[0m'

log()  { echo -e "${GREEN}✓${NC} $1"; }
info() { echo -e "${CYAN}→${NC} $1"; }

echo "Claude Config Sync (machine → repo)"
echo ""

# ─── Global skills ────────────────────────────

echo "═══ Syncing global skills"
mkdir -p "$SCRIPT_DIR/global-skills"

# Sync skill directories (new format: each skill is a directory with SKILL.md)
for dir in "$GLOBAL_SKILLS_DIR"/*/; do
  [ -d "$dir" ] || continue
  name="$(basename "$dir")"
  dst="$SCRIPT_DIR/global-skills/$name"
  rm -rf "$dst"
  cp -r "$dir" "$dst"
  log "global: $name/"
done

# ─── Workspace skills + AGENTS.md ─────────────

for workspace in trading-workspace ai-workspace; do
  echo ""
  echo "═══ Syncing $workspace"
  src="$WORKSPACE_ROOT/$workspace"

  if [ ! -d "$src" ]; then
    echo "  (not found — skipping)"
    continue
  fi

  mkdir -p "$SCRIPT_DIR/$workspace/skills"

  # AGENTS.md
  if [ -f "$src/AGENTS.md" ]; then
    cp "$src/AGENTS.md" "$SCRIPT_DIR/$workspace/AGENTS.md"
    log "$workspace: AGENTS.md"
  fi

  # .claude/skills/ — sync skill directories
  if [ -d "$src/.claude/skills" ]; then
    for dir in "$src/.claude/skills"/*/; do
      [ -d "$dir" ] || continue
      name="$(basename "$dir")"
      dst="$SCRIPT_DIR/$workspace/skills/$name"
      rm -rf "$dst"
      cp -r "$dir" "$dst"
      log "$workspace: $name/"
    done
  fi
done

echo ""
echo "─────────────────────────────────────"
echo "Sync complete. Changes ready to commit:"
echo ""
cd "$SCRIPT_DIR" && git status --short 2>/dev/null || echo "(not a git repo yet — run: git init && git add . && git commit)"

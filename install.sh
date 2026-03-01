#!/usr/bin/env bash
set -euo pipefail

# ─────────────────────────────────────────────
# Claude Config Installer
# Sets up global skills, workspace skills, and AGENTS.md
# Usage:
#   ./install.sh                    # full install
#   ./install.sh --global-only      # only global skills
#   ./install.sh --workspace-only   # only workspace skills + AGENTS.md
#   ./install.sh --dry-run          # preview without writing
# ─────────────────────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GLOBAL_SKILLS_DIR="$HOME/.claude/skills"
WORKSPACE_ROOT="${WORKSPACE_ROOT:-$HOME/project}"

DRY_RUN=false
GLOBAL_ONLY=false
WORKSPACE_ONLY=false

for arg in "$@"; do
  case $arg in
    --dry-run)       DRY_RUN=true ;;
    --global-only)   GLOBAL_ONLY=true ;;
    --workspace-only) WORKSPACE_ONLY=true ;;
  esac
done

# ─── Helpers ──────────────────────────────────

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

log()     { echo -e "${GREEN}✓${NC} $1"; }
info()    { echo -e "${CYAN}→${NC} $1"; }
warn()    { echo -e "${YELLOW}⚠${NC} $1"; }

copy_file() {
  local src="$1" dst="$2"
  if $DRY_RUN; then
    info "[DRY RUN] cp $src → $dst"
  else
    mkdir -p "$(dirname "$dst")"
    cp "$src" "$dst"
    log "$(basename "$src") → $dst"
  fi
}

copy_dir() {
  local src="$1" dst="$2"
  if $DRY_RUN; then
    info "[DRY RUN] cp -r $src/ → $dst/"
  else
    mkdir -p "$dst"
    cp -r "$src/." "$dst/"
    log "$(basename "$src")/ → $dst/"
  fi
}

# ─── Global Skills ────────────────────────────

install_global_skills() {
  echo ""
  echo "═══ Global Skills → $GLOBAL_SKILLS_DIR"

  if $DRY_RUN; then
    info "[DRY RUN] mkdir -p $GLOBAL_SKILLS_DIR"
  else
    mkdir -p "$GLOBAL_SKILLS_DIR"
  fi

  for file in "$SCRIPT_DIR/global-skills"/*.md; do
    [ -f "$file" ] && copy_file "$file" "$GLOBAL_SKILLS_DIR/$(basename "$file")"
  done

  if [ -d "$SCRIPT_DIR/global-skills/solid-references" ]; then
    copy_dir "$SCRIPT_DIR/global-skills/solid-references" "$GLOBAL_SKILLS_DIR/solid-references"
  fi
}

# ─── Workspace Skills + AGENTS.md ─────────────

install_workspace() {
  local name="$1"        # e.g. "trading-workspace"
  local workspace_path="$WORKSPACE_ROOT/$name"

  echo ""
  echo "═══ $name → $workspace_path"

  if [ ! -d "$workspace_path" ]; then
    warn "$workspace_path does not exist — skipping $name"
    warn "Create it first: mkdir -p $workspace_path"
    return
  fi

  # AGENTS.md
  local agents_src="$SCRIPT_DIR/$name/AGENTS.md"
  if [ -f "$agents_src" ]; then
    copy_file "$agents_src" "$workspace_path/AGENTS.md"
  fi

  # .claude/skills/
  local skills_src="$SCRIPT_DIR/$name/skills"
  if [ -d "$skills_src" ]; then
    local skills_dst="$workspace_path/.claude/skills"
    if $DRY_RUN; then
      info "[DRY RUN] mkdir -p $skills_dst"
    else
      mkdir -p "$skills_dst"
    fi
    for file in "$skills_src"/*.md; do
      [ -f "$file" ] && copy_file "$file" "$skills_dst/$(basename "$file")"
    done
  fi
}

# ─── Main ─────────────────────────────────────

echo "Claude Config Installer"
echo "Script dir:     $SCRIPT_DIR"
echo "Workspace root: $WORKSPACE_ROOT"
$DRY_RUN && echo "Mode:           DRY RUN (no files will be written)"
echo ""

if ! $WORKSPACE_ONLY; then
  install_global_skills
fi

if ! $GLOBAL_ONLY; then
  install_workspace "trading-workspace"
  install_workspace "ai-workspace"
fi

echo ""
echo "─────────────────────────────────────"
if $DRY_RUN; then
  echo "Dry run complete. Run without --dry-run to apply."
else
  echo "Done. Restart Claude TUI to load new skills."
  echo ""
  echo "Global skills available in any session:"
  ls "$GLOBAL_SKILLS_DIR"/*.md 2>/dev/null | xargs -I{} basename {} .md | sed 's/^/  \//'
fi

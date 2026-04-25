#!/usr/bin/env bash
# Auto-diff patch generator for safe-cleanup steps.
#
# Usage:
#   bash scripts/generate_patch.sh start <step-number> <description>
#   bash scripts/generate_patch.sh end   <step-number>
#
# Workflow:
#   1. Run `start` before making any changes for a step — records baseline commit
#   2. Make changes (apply HIGH-confidence findings)
#   3. Run `end` after changes — generates a patch file and commit
#
# Patches land in patches/step-N-description.patch
# Apply a patch: git apply patches/step-N-description.patch
# Discard a patch: git checkout -- .
set -euo pipefail

COMMAND="${1:-}"
STEP="${2:-}"
DESCRIPTION="${3:-cleanup}"
PATCHES_DIR="patches"

mkdir -p "$PATCHES_DIR"

case "$COMMAND" in

  start)
    [ -z "$STEP" ] && { echo "Usage: generate_patch.sh start <step> <description>"; exit 1; }
    BRANCH="cleanup/step-${STEP}-${DESCRIPTION}"

    echo "Starting patch capture for Step $STEP..."

    # Ensure working tree is clean
    if ! git diff --quiet; then
      echo "ERROR: Working tree has uncommitted changes. Commit or stash first."
      exit 1
    fi

    # Record the baseline SHA for patch generation
    git rev-parse HEAD > "$PATCHES_DIR/.step-${STEP}-baseline"

    echo "Baseline SHA recorded: $(cat "$PATCHES_DIR/.step-${STEP}-baseline")"
    echo ""
    echo "Make your Step $STEP changes now."
    echo "When done, run: bash scripts/generate_patch.sh end $STEP"
    ;;

  end)
    [ -z "$STEP" ] && { echo "Usage: generate_patch.sh end <step>"; exit 1; }
    BASELINE_FILE="$PATCHES_DIR/.step-${STEP}-baseline"

    [ -f "$BASELINE_FILE" ] || { echo "ERROR: No baseline found. Run 'start' first."; exit 1; }

    BASELINE_SHA=$(cat "$BASELINE_FILE")
    PATCH_FILE="$PATCHES_DIR/step-${STEP}-${DESCRIPTION}.patch"

    echo "Generating patch for Step $STEP..."

    # Generate patch from baseline to current working tree
    git diff "$BASELINE_SHA" -- > "$PATCH_FILE"

    LINES=$(wc -l < "$PATCH_FILE")
    FILES=$(grep -c "^diff --git" "$PATCH_FILE" || echo 0)

    echo ""
    echo "Patch generated: $PATCH_FILE"
    echo "  Files changed: $FILES"
    echo "  Patch size:    $LINES lines"
    echo ""
    echo "Commands:"
    echo "  Review:  cat $PATCH_FILE"
    echo "  Apply:   git apply $PATCH_FILE"
    echo "  Discard: git checkout -- ."
    echo ""

    # Clean up baseline marker
    rm -f "$BASELINE_FILE"

    # Run verification
    echo "Running verification..."
    bash scripts/verify.sh "$STEP" || {
      echo ""
      echo "Verification failed. Discard changes and review the patch manually:"
      echo "  git checkout -- ."
      echo "  cat $PATCH_FILE"
      exit 1
    }

    echo ""
    echo "Patch verified. Commit with:"
    echo "  git add -p && git commit -m 'cleanup: step $STEP — $DESCRIPTION'"
    ;;

  review)
    [ -z "$STEP" ] && { echo "Usage: generate_patch.sh review <step>"; exit 1; }
    PATCH=$(ls "$PATCHES_DIR"/step-${STEP}-*.patch 2>/dev/null | head -1)
    [ -z "$PATCH" ] && { echo "No patch found for step $STEP in $PATCHES_DIR/"; exit 1; }
    echo "=== Patch: $PATCH ==="
    cat "$PATCH"
    ;;

  apply)
    [ -z "$STEP" ] && { echo "Usage: generate_patch.sh apply <step>"; exit 1; }
    PATCH=$(ls "$PATCHES_DIR"/step-${STEP}-*.patch 2>/dev/null | head -1)
    [ -z "$PATCH" ] && { echo "No patch found for step $STEP in $PATCHES_DIR/"; exit 1; }
    echo "Applying patch: $PATCH"
    git apply "$PATCH"
    echo "Applied. Run scripts/verify.sh $STEP to confirm."
    ;;

  list)
    echo "Available patches:"
    ls -1 "$PATCHES_DIR"/*.patch 2>/dev/null || echo "  (none)"
    ;;

  *)
    echo "Usage:"
    echo "  generate_patch.sh start  <step> <description>   Start patch capture"
    echo "  generate_patch.sh end    <step>                  End capture + generate patch"
    echo "  generate_patch.sh review <step>                  Show patch contents"
    echo "  generate_patch.sh apply  <step>                  Apply a saved patch"
    echo "  generate_patch.sh list                           List all patches"
    exit 1
    ;;
esac

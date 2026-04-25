#!/usr/bin/env bash
# Run after each cleanup step to verify nothing broke.
# Exits non-zero if any check fails — treat as a hard stop.
set -euo pipefail

STEP="${1:-?}"
FAILED=0

echo "=== Verification: Step $STEP ==="
echo ""

# ─── Ruby / Rails ─────────────────────────────────────────────────────────────

if command -v bundle &>/dev/null && [ -f "Gemfile" ]; then

  echo "→ RSpec..."
  if bundle exec rspec --format progress 2>&1 | tee /tmp/rspec_out.txt; then
    echo "  RSpec: PASS"
  else
    echo "  RSpec: FAIL ← STOP. Revert changes for Step $STEP."
    FAILED=1
  fi

  echo ""
  echo "→ Rails boot check..."
  if bundle exec rails runner "puts 'BOOT OK'" 2>&1 | grep -q "BOOT OK"; then
    echo "  Boot: PASS"
  else
    echo "  Boot: FAIL ← STOP. App won't start after Step $STEP changes."
    FAILED=1
  fi

fi

# ─── JavaScript / TypeScript ──────────────────────────────────────────────────

if [ -f "package.json" ] && command -v npx &>/dev/null; then

  echo ""
  echo "→ Jest / npm test..."
  if npm test -- --ci --passWithNoTests 2>&1 | tee /tmp/jest_out.txt; then
    echo "  Jest: PASS"
  else
    echo "  Jest: FAIL ← STOP. Revert changes for Step $STEP."
    FAILED=1
  fi

  if [ -f "tsconfig.json" ]; then
    echo ""
    echo "→ TypeScript type check..."
    TSC_ERRORS=$(npx tsc --noEmit 2>&1 | grep -c "error TS" || true)
    BASELINE_ERRORS=$(grep -c "error TS" tmp/tsc_baseline.txt 2>/dev/null || echo "0")

    if [ "$TSC_ERRORS" -le "$BASELINE_ERRORS" ]; then
      echo "  tsc: PASS ($TSC_ERRORS errors, baseline was $BASELINE_ERRORS)"
    else
      NEW=$((TSC_ERRORS - BASELINE_ERRORS))
      echo "  tsc: FAIL — $NEW new type errors introduced ← STOP."
      FAILED=1
    fi
  fi

fi

# ─── Git diff summary ─────────────────────────────────────────────────────────

echo ""
echo "→ Git diff (Step $STEP changes):"
git diff --stat HEAD 2>/dev/null || git diff --stat 2>/dev/null || echo "  (no git)"

# ─── Result ───────────────────────────────────────────────────────────────────

echo ""
if [ "$FAILED" -eq 0 ]; then
  echo "✓ Step $STEP verification PASSED — safe to continue."
  exit 0
else
  echo "✗ Step $STEP verification FAILED."
  echo ""
  echo "  Rollback command:"
  echo "    git checkout -- ."
  echo "  Or if committed:"
  echo "    git revert HEAD --no-edit"
  exit 1
fi

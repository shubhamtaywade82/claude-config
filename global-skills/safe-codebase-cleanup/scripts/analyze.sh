#!/usr/bin/env bash
# Capture static analysis baseline before cleanup begins.
# Run once at the start. Compare output in tmp/ after each step.
set -euo pipefail

mkdir -p tmp

echo "Running static analysis baseline..."

# Ruby: Rubocop
if command -v bundle &>/dev/null && bundle exec rubocop --version &>/dev/null 2>&1; then
  echo "  → RuboCop..."
  bundle exec rubocop --format json --out tmp/rubocop_baseline.json 2>/dev/null || true
  RUBOCOP_OFFENSES=$(bundle exec rubocop --format progress 2>/dev/null | tail -1 || echo "N/A")
  echo "  RuboCop: $RUBOCOP_OFFENSES"
else
  echo "  [skip] RuboCop not available"
fi

# JS/TS: ESLint
if [ -f "package.json" ] && command -v npx &>/dev/null; then
  echo "  → ESLint..."
  npx eslint . --format json --output-file tmp/eslint_baseline.json 2>/dev/null || true
  echo "  ESLint: baseline saved to tmp/eslint_baseline.json"
else
  echo "  [skip] ESLint not available"
fi

# Dead code: knip
if command -v npx &>/dev/null && [ -f "package.json" ]; then
  echo "  → knip (dead code)..."
  npx knip --reporter json > tmp/knip_baseline.json 2>/dev/null || true
  KNIP_COUNT=$(cat tmp/knip_baseline.json 2>/dev/null | grep -c '"name"' || echo "0")
  echo "  knip: $KNIP_COUNT potential dead exports"
fi

# Circular deps: madge
if command -v npx &>/dev/null && [ -f "package.json" ]; then
  SRC_DIR="${1:-src}"
  if [ -d "$SRC_DIR" ]; then
    echo "  → madge (circular deps in $SRC_DIR)..."
    npx madge --circular "$SRC_DIR" > tmp/circular_deps.txt 2>/dev/null || true
    CYCLE_COUNT=$(grep -c "→" tmp/circular_deps.txt 2>/dev/null || echo "0")
    echo "  madge: $CYCLE_COUNT circular dependency cycles"
  fi
fi

# TypeScript
if [ -f "tsconfig.json" ] && command -v npx &>/dev/null; then
  echo "  → TypeScript (type errors)..."
  npx tsc --noEmit 2>tmp/tsc_baseline.txt || true
  TSC_ERRORS=$(grep -c "error TS" tmp/tsc_baseline.txt 2>/dev/null || echo "0")
  echo "  tsc: $TSC_ERRORS type errors"
fi

echo ""
echo "Baseline saved to tmp/"
echo "  tmp/rubocop_baseline.json"
echo "  tmp/eslint_baseline.json"
echo "  tmp/knip_baseline.json"
echo "  tmp/circular_deps.txt"
echo "  tmp/tsc_baseline.txt"
echo ""
echo "Run scripts/verify.sh after each cleanup step to check for regressions."

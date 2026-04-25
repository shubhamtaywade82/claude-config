# Pre-Run Safety Checklist

Verify ALL items before starting any cleanup step. If any item fails, stop and report.

---

## Git State

- [ ] Working tree is clean: `git status` shows no uncommitted changes
  - If not clean: stash or commit before proceeding
  - `git stash push -m "pre-cleanup-$(date +%Y%m%d)"`
- [ ] On a dedicated cleanup branch (not main/master)
  - `git checkout -b cleanup/safe-run-$(date +%Y%m%d)`
- [ ] Remote is up to date: `git fetch origin && git status`

## Test Baseline

- [ ] Full test suite passes before any changes:
  - Ruby: `bundle exec rspec --format progress`
  - JS/TS: `npm test -- --ci`
  - Record baseline pass count — any regression after a step = revert immediately

## Boot Check

- [ ] Application boots without errors:
  - Rails: `rails runner "puts 'BOOT OK'"`
  - Node: `node -e "require('./src/index')" 2>&1 | head -5`

## Static Analysis Baseline

- [ ] Run `bash scripts/analyze.sh` to capture pre-run baseline
  - Outputs: `tmp/rubocop_baseline.json`, `tmp/eslint_baseline.json`, `tmp/knip_baseline.json`, `tmp/circular_deps.txt`
  - These baselines are used to diff findings per step

## Scope Confirmation

- [ ] `config.yaml` ignore list reviewed — paths that should not be touched are listed
- [ ] Trading critical paths listed in `config.yaml` under `trading_critical_paths`
- [ ] `$ARGUMENTS` scope is correct (directory or file to clean up)

## Patch Mode (Optional)

- [ ] If running in patch/review mode: confirm `patches/` directory exists
  - `mkdir -p patches`
  - Set `patch_mode.enabled: true` in `config.yaml`

---

## Checklist Sign-off

All items above must pass. Record:
```
Pre-run checklist: PASSED
Branch: [branch name]
Baseline tests: [N passing]
Date: [date]
```

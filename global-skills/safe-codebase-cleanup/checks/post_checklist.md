# Post-Step Verification Checklist

Run after EVERY step. A single failure means: revert the step, report the issue, stop.

---

## After Each Step

### Tests
- [ ] Ruby: `bundle exec rspec --format progress`
  - Must match or exceed baseline pass count
  - Zero new failures allowed
- [ ] JS/TS: `npm test -- --ci`
  - Zero new failures allowed

### Type Checks
- [ ] TypeScript: `npx tsc --noEmit`
  - Zero new errors allowed (pre-existing errors are acceptable if unchanged)

### Boot Check
- [ ] Rails: `rails runner "puts 'BOOT OK'"`
  - Must exit 0 with no exceptions

### Lint (informational, not blocking)
- [ ] `bundle exec rubocop --format simple 2>/dev/null | tail -5`
- [ ] `npm run lint -- --quiet 2>/dev/null | tail -5`
  - Compare against baseline — note new violations but don't block on pre-existing ones

### Git Diff Review
- [ ] `git diff --stat` — review every changed file
- [ ] Confirm: only files targeted by this step were modified
- [ ] Confirm: no accidental whitespace/formatting changes in untargeted files
- [ ] Confirm: no import paths broken

### Critical Flow Spot-Check (Steps 3, 6, 7 only)
For steps that delete code, manually verify:
- [ ] Order placement path: can still place an order (smoke test or trace the code)
- [ ] Kill switch / drawdown halt: still reachable and functional
- [ ] WebSocket handlers: no missing handler registrations

---

## Verification Result Format

After each step, record:
```
Step N verification:
  Tests:      PASS (N passing, 0 failed)
  Type check: PASS / SKIP (no TS)
  Boot:       PASS
  Diff:       N files changed, N insertions(+), N deletions(-)
  Status:     CLEAN
```

---

## Rollback Procedure

If any check fails:
```bash
# Revert step changes (before committing)
git checkout -- .

# Or if committed:
git revert HEAD --no-edit
```

Then report:
```
Step N FAILED verification:
  Failure: [test name / boot error / type error]
  Action: Changes reverted
  Recommendation: [inspect finding manually]
```

---
name: safe-codebase-cleanup
description: 7-pass safe codebase cleanup. Detects, classifies (HIGH/MEDIUM/LOW), and applies only HIGH-confidence changes. Never deletes without proof. Use when asked to clean up, remove dead code, fix error handling, or reduce tech debt safely.
argument-hint: [directory-or-file]
allowed-tools: Read, Glob, Grep, Bash, Edit
---

# Safe Codebase Cleanup — Orchestrator

Perform a safe, deterministic cleanup of `$ARGUMENTS` (default: entire codebase) across 7 isolated passes.

**Core contract:** No behavior changes. No speculative refactors. No deletions without proof. If uncertain → mark and skip.

---

## Pre-Run: Safety Gate

Before starting ANY step, verify all items in [checks/pre_checklist.md](checks/pre_checklist.md).

If any gate fails → **STOP. Report the failure. Do not proceed.**

Run baseline analysis:
```bash
bash scripts/analyze.sh
```

---

## Execution Model (repeat for each step)

```
1. INSPECT   — read relevant files, understand patterns
2. CLASSIFY  — assign HIGH / MEDIUM / LOW to every finding (see checks/risk_matrix.md)
3. APPLY     — implement ONLY HIGH-confidence findings
4. VERIFY    — run checks/post_checklist.md after each step
5. REPORT    — output structured findings table
```

**Abort conditions:**
- Post-step verification fails → revert the step's changes, report failure, stop
- Ambiguous confidence → default to MEDIUM, skip apply
- Trading-critical path touched → see [checks/trading_safety.md](checks/trading_safety.md), cap at MEDIUM

---

## Step 1 — Deduplication

See [runners/step1_deduplication.md](runners/step1_deduplication.md)

Goal: Eliminate provably identical logic. DRY only where it genuinely simplifies.

---

## Step 2 — Type Consolidation

See [runners/step2_type_consolidation.md](runners/step2_type_consolidation.md)

Goal: Single source of truth for types. Eliminate drift between definitions.

---

## Step 3 — Dead Code Removal

See [runners/step3_dead_code.md](runners/step3_dead_code.md)

For Rails projects, also run: [runners/step3_dead_code_rails.md](runners/step3_dead_code_rails.md)

Goal: Remove confirmed-dead code only. Suspected-dead → report, skip.

---

## Step 4 — Circular Dependencies

See [runners/step4_circular_deps.md](runners/step4_circular_deps.md)

Goal: Break cycles by extracting neutral shared modules. No new abstractions for their own sake.

---

## Step 5 — Type Strengthening

See [runners/step5_type_strengthening.md](runners/step5_type_strengthening.md)

Goal: Replace `any`/`unknown`/untyped with explicit types. Keep boundary types as-is.

---

## Step 6 — Error Handling Cleanup

See [runners/step6_error_handling.md](runners/step6_error_handling.md)

Goal: Remove silent swallowers. Every rescue must log, re-raise, or translate.

---

## Step 7 — Deprecated Code & AI Artifacts

See [runners/step7_deprecated_ai.md](runners/step7_deprecated_ai.md)

Goal: Remove provably dead flags, placeholder logic, and narrative comments. Rewrite surviving comments to explain WHY.

---

## Post-Run Verification

Run full verification:
```bash
bash scripts/verify.sh
```

Check all items in [checks/post_checklist.md](checks/post_checklist.md).

---

## Output Format (per step)

```
## Step N — [Name]

### Findings

| Item | Location | Confidence | Action |
|------|----------|------------|--------|
| [description] | file:line | HIGH/MEDIUM/LOW | Applied / Skipped / Reported |

### Changes Applied
- [list of actual changes made]

### Skipped (with reason)
- [item] — reason: [dynamic call / uncertain intent / trading path / etc.]

### Verification
- Tests: PASS / FAIL
- Boot: PASS / FAIL
- Type check: PASS / FAIL
```

---

## Quick Reference

| Confidence | Action |
|------------|--------|
| HIGH | Apply immediately |
| MEDIUM | Report only, do not modify |
| LOW | Ignore entirely |

See [checks/risk_matrix.md](checks/risk_matrix.md) for classification rules.

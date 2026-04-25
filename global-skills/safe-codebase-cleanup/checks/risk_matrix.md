# Risk Classification Matrix

Apply this matrix to every finding before acting. When in doubt, go one tier lower.

---

## HIGH — Auto-Apply

Changes are safe to apply immediately without additional review.

| Pattern | Example | Verification Required |
|---------|---------|----------------------|
| Exact duplicate private method (same body, same signature) | `def format_price(v) = v.round(2)` in 3 files | Grep all call sites |
| Dead file with zero references | `app/services/legacy_importer.rb` — 0 grep hits, not in routes | Grep + routes check |
| `rescue nil` with no logging or re-raise | `user = find_user rescue nil` | Confirm no caller depends on nil return |
| Byte-identical type definition in 2+ files | `interface OrderParams` defined in `orders.ts` and `trading.ts` identically | Check all imports |
| Feature flag constant hard-coded to `false` | `ENABLE_LEGACY_FLOW = false` — never toggled | Grep for all usages |
| `raise NotImplementedError` in unreferenced method | `def legacy_sync; raise NotImplementedError; end` — 0 callers | Grep + dynamic call check |
| `any` type on a value whose type is obvious from usage | `const price: any = order.price` where `price` is always a number | Run tsc after fix |
| Empty `catch {}` block | `catch (e) {}` with no logging | Confirm caller doesn't depend on suppression |
| Narrative comment describing git history | `# Added this in Dec 2023 to fix the broker timeout issue` | None |

---

## MEDIUM — Report Only

List in output but do NOT modify. Flag for human review.

| Pattern | Example | Why Not HIGH |
|---------|---------|--------------|
| Similar but not identical logic | Two services both format currency but with different rounding | Different intent possible |
| Possibly dead via dynamic dispatch | `def process_#{action}` — referenced nowhere statically | `send()` / metaprogramming could reach it |
| Partial type overlap across files | `OrderParams` in two files with 90% same fields | Could have diverged intentionally |
| TODO chain (2+ items) without linked ticket | `# TODO: remove after migration` | May still be needed |
| Feature flag with mixed `true`/`false` usage | `ENABLE_NEW_FLOW = ENV.fetch('NEW_FLOW', 'false') == 'true'` | Still runtime-configurable |
| Error rescue with logging but no re-raise | `rescue => e; logger.error(e); end` | Swallowing, but intentionally at boundary |
| Circular dep affecting readability only | `A → B → A` where both are pure utilities | No correctness impact |
| Dead job class (ActiveJob) | `class LegacyReportJob < ApplicationJob` — no `.perform_later` calls | Could be enqueued via string in config |

---

## LOW — Skip Entirely

Do not report, do not modify.

| Pattern | Reason |
|---------|--------|
| Structural refactor opportunity | Out of scope — behavior change risk |
| Business logic that could be merged | Different semantic domains |
| "Could be cleaner" intuitions | Subjective, not provable |
| Test setup duplication | Context-specific, not safe to share |
| Any finding in `vendor/`, `node_modules/`, `tmp/` | Outside scope |
| Anything touching a trading critical path | See trading_safety.md — cap at MEDIUM |

---

## Escalation Rules

1. If a HIGH finding touches a trading critical path → downgrade to MEDIUM
2. If a finding's verification step fails (grep finds dynamic usage) → downgrade one tier
3. If two findings conflict (removing A would affect B) → downgrade both to MEDIUM
4. If unsure which tier → always choose the lower tier

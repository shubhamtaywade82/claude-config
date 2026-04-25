# Step 1 — Deduplication

## Goal
Eliminate provably identical logic. Apply DRY only where it genuinely reduces complexity without obscuring intent. Never merge code that merely looks similar but serves different business purposes.

---

## Detect

Search for:

1. **Identical private method bodies** — same name or different name, same implementation
   ```bash
   # Ruby: find methods with identical bodies across files
   grep -rn "def " app/ --include="*.rb" | sort
   ```

2. **Copy-pasted helper blocks** — 5+ line blocks that appear verbatim in 2+ files

3. **Repeated transformation logic** — e.g., price formatting, date parsing, response building appearing in multiple service/model files

4. **Redundant module includes** — the same `include SomeModule` functionality reimplemented inline

---

## Classify

### HIGH — Apply
- Exact duplicate private method: identical body, identical signature, no contextual difference
  - Verification: grep all call sites — same arguments, same expected return
- Verbatim copy-paste block (5+ lines) in 2+ files with identical call sites
- Helper method defined in both parent and child class with same body

### MEDIUM — Report Only
- Similar private methods with minor differences (different variable names, one extra guard)
- Same logic in files from different business domains (e.g., `OrderService` and `ReportService` both format currency)
- Shared pattern that's customized differently in each location

### LOW — Skip
- Any method that has even one meaningful semantic difference
- Test helpers (each spec context has different setup semantics)
- Controller callbacks that look similar but guard different conditions

---

## Apply (HIGH only)

For each HIGH finding:

1. Identify the canonical location for the shared method:
   - Shared utility module (`lib/utils/`, `app/lib/`, `src/utils/`)
   - Concern/mixin if Rails and all users are models/controllers
   - Base class if all duplicates are in subclasses of the same parent

2. Extract the method to the canonical location

3. Replace all original definitions with a call to the shared version

4. Verify all call sites still work identically:
   - Same arguments
   - Same return type/shape
   - No hidden state difference

5. Run post-checklist before moving to next finding

---

## Verify

After each extraction:
```bash
bundle exec rspec --format progress   # or npm test
git diff --stat
```

Confirm: no test failures, no new lint errors, diff shows only the intended files.

---

## Report

```
## Step 1 — Deduplication

### Findings

| Method/Block | Locations | Lines | Confidence | Action |
|---|---|---|---|---|
| `format_price(v)` | orders.rb:42, report.rb:87 | 3 lines | HIGH | Extracted to PriceFormatter |
| `build_response(data)` | 3 controllers | 8 lines | HIGH | Extracted to ApplicationController |
| `validate_quantity` | OrderService, TradeService | 5 lines (minor diff) | MEDIUM | Reported — different rounding intent |

### Changes Applied
- Extracted `format_price` → `app/lib/price_formatter.rb`
- Updated 2 call sites

### Skipped
- `validate_quantity` — MEDIUM: different rounding in each context (intentional)
```

# Step 4 — Circular Dependencies

## Goal
Detect and break circular import/require cycles. Extract shared logic to neutral modules. Do not introduce abstraction layers just to break a cycle — the fix must be simpler than the problem.

---

## Tools

### TypeScript / JavaScript
```bash
npx madge --circular src/ > tmp/circular_deps.txt
npx madge --circular --image tmp/dep-graph.svg src/ 2>/dev/null || true
cat tmp/circular_deps.txt
```

### Ruby
```bash
# madge doesn't support Ruby — use manual require graph
grep -rn "require\|require_relative\|autoload" app/ lib/ --include="*.rb" | \
  grep -v "spec\|test\|vendor" | sort > tmp/ruby_deps.txt

# For specific suspected cycles, trace manually:
# A includes B → B includes A?
grep -rn "require.*module_b\|include ModuleB" app/module_a.rb
grep -rn "require.*module_a\|include ModuleA" app/module_b.rb
```

---

## Detect

From the madge output or manual trace, identify:

1. **Direct cycles**: A → B → A
2. **Indirect cycles**: A → B → C → A
3. **Self-referencing**: A → A (import within same module via barrel file)

For each cycle, assess impact:

| Impact Level | Description |
|---|---|
| Correctness | Cycle causes initialization-order bugs or undefined behavior |
| Testability | Either module cannot be unit-tested in isolation |
| Maintainability | Changes to A always require understanding B and vice versa |
| None | Tools flag it but runtime handles it fine |

---

## Classify

### HIGH — Apply
- Cycle that causes initialization-order bugs (e.g., class undefined at load time)
- Cycle between a model and a service that makes the model untestable in isolation
- Cycle that madge flags AND there is a clean, obvious extraction point

### MEDIUM — Report Only
- Cycle that is functionally correct but reduces testability
- Indirect cycle (3+ hops) — fix strategy is complex
- Cycle where the fix would require a new abstraction layer (don't do it speculatively)

### LOW — Skip
- Cycle flagged by tools but with no runtime impact and no testability concern
- Cycle in test/spec files
- Cycles in generated code

---

## Fix Strategy (HIGH only)

**Option A: Extract to a neutral shared module**

Before:
```
A (model) → B (service) → A (model)  # B uses A's constants
```

After:
```
A → SharedConstants ← B  # both depend on neutral module, no cycle
```

Implementation:
1. Identify exactly what B needs from A (usually constants, types, or simple helpers)
2. Extract those to a new neutral module (`lib/shared/`, `app/lib/`, `src/shared/`)
3. Have both A and B import from the neutral module
4. Remove the original dependency direction that created the cycle

**Option B: Dependency Injection**

Before:
```
OrderService.new calls RiskService, RiskService imports OrderService
```

After:
```
OrderService.new(risk_service:) — inject at call site, no import needed
```

**Never do:**
- Create an abstract base class just to break a cycle
- Add an intermediary module that just re-exports without adding value
- Move code into a shared location without it making semantic sense there

---

## Verify

```bash
# Confirm cycle is broken
npx madge --circular src/ | grep "module_a"
# Should show 0 results for the fixed modules

# Run tests
bundle exec rspec   # or npm test
```

---

## Report

```
## Step 4 — Circular Dependencies

### Cycles Found

| Cycle | Impact | Confidence | Fix |
|---|---|---|---|
| OrderService → RiskService → OrderService | Testability | HIGH | Extract RiskLimits to lib/shared |
| UserModel → AuthService → UserModel | Correctness (init order) | HIGH | DI: inject UserModel at call site |
| ReportBuilder → DataFormatter → ReportBuilder | None (functionally fine) | MEDIUM | Reported — no runtime impact |

### Changes Applied
- Extracted `RiskLimits` constants → `app/lib/shared/risk_limits.rb`
- Injected `UserModel` into `AuthService.new(user_model:)`, removed import

### Skipped
- `ReportBuilder` cycle — MEDIUM: no correctness/testability impact
```

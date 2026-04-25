# Step 2 — Type Consolidation

## Goal
Establish a single source of truth for shared types. Eliminate drift between duplicate definitions. Merge only when types are truly shared — not when they happen to look similar.

---

## Detect

### TypeScript / JavaScript
Search for duplicate interface/type definitions:
```bash
# Find all type/interface definitions
grep -rn "^export type\|^export interface\|^interface\|^type " src/ --include="*.ts" | sort -t: -k3

# Find identically-named types in multiple files
grep -rn "^export.*interface\|^export.*type " src/ --include="*.ts" | awk -F'[ <{]' '{print $NF}' | sort | uniq -d
```

### Ruby (dry-types / Sorbet / PORO)
```bash
# Find struct/type definitions
grep -rn "Types::\|T\.struct\|Dry::Struct\|Data\.define" app/ --include="*.rb" | sort
```

Look for:
- Same type name defined in multiple files
- Types with same fields that have quietly diverged (one has an extra optional field)
- Interfaces that are subsets of each other
- Duplicated enum-like constants

---

## Classify

### HIGH — Apply
- Byte-identical type definition in 2+ files (same fields, same types, same optionality)
- Type defined in a feature file but imported by 3+ other feature files (should be in `types/`)
- Identical enum object defined in multiple files

### MEDIUM — Report Only
- Same name, 90%+ same fields but with 1-2 differences — could be intentional divergence
- Type that shares fields but represents a different domain concept (e.g., `UserParams` for create vs update)
- Partial overlap that might need a discriminated union instead of a merge

### LOW — Skip
- Types that look similar but are in completely different domains
- Test-only types and mocks
- Generated types from OpenAPI/GraphQL schemas

---

## Apply (HIGH only)

For TypeScript:
1. Create canonical type in `src/types/` (or `src/shared/types.ts` if small)
2. Replace all duplicate definitions with an import
3. Run `npx tsc --noEmit` after each consolidation

For Ruby (dry-types):
1. Move to `app/lib/types/` or `app/contracts/`
2. Update all references

For Ruby (PORO contracts):
1. Extract to shared contract class
2. Use `include` or inheritance if appropriate

---

## Verify

```bash
npx tsc --noEmit          # TypeScript
bundle exec rspec         # Ruby
grep -rn "duplicate_type_name" src/  # Confirm old definition is gone
```

---

## Report

```
## Step 2 — Type Consolidation

### Findings

| Type | Locations | Difference | Confidence | Action |
|---|---|---|---|---|
| `OrderParams` | orders/types.ts, trading/types.ts | Identical | HIGH | Moved to src/types/orders.ts |
| `ApiResponse<T>` | 4 service files | Identical | HIGH | Moved to src/types/api.ts |
| `UserProfile` | auth.ts, profile.ts | 1 extra optional field | MEDIUM | Reported — possible intentional divergence |

### Changes Applied
- `OrderParams` → `src/types/orders.ts`, updated 2 imports
- `ApiResponse` → `src/types/api.ts`, updated 4 imports

### Skipped
- `UserProfile` — MEDIUM: `profile.ts` version has `avatarUrl?` which auth version lacks
```

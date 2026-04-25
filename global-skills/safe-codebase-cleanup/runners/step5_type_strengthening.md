# Step 5 — Type Strengthening

## Goal
Replace weak types (`any`, `unknown`, untyped parameters, implicit `Object`) with explicit, domain-appropriate types. Preserve legitimate boundary types where `unknown` is the correct choice.

---

## Detect

### TypeScript
```bash
# Find all 'any' usages
grep -rn ": any\|<any>\|as any\| any " src/ --include="*.ts" --include="*.tsx" | grep -v "//.*any"

# Find untyped function parameters
grep -rn "function\|=>" src/ --include="*.ts" | grep -v ": " | grep -v "void\|never\|Promise"

# Find implicit any (catch blocks)
grep -rn "catch (e)" src/ --include="*.ts"
# Modern: should be catch (e: unknown) or catch (e) with type narrowing
```

### Ruby (Sorbet / RBS)
```bash
# Find T.untyped
grep -rn "T\.untyped\|# typed: ignore\|# typed: false" app/ lib/ --include="*.rb"

# Find methods with no sig block in Sorbet-typed files
grep -rn "# typed: strict" app/ --include="*.rb" | while read -r file; do
  grep -L "sig {" "$file"
done
```

---

## Classify

### HIGH — Apply
- `any` type on a value whose actual type is clear from surrounding code:
  - `const price: any = order.price` where `price` is always `number`
  - `params: any` where params is always a specific request shape
- `catch (e)` without type annotation when the error type is known
- Untyped function return when return value is always the same shape
- `T.untyped` used for a value that Sorbet could infer if annotated

### MEDIUM — Report Only
- `any` at a function boundary where input comes from an external API
- `unknown` used correctly but with a missing type guard
- Complex generic that would require significant refactor to type properly
- `T.untyped` on a method that touches many callers

### LOW — Skip
- `unknown` at true system boundaries (webhook payloads, external API responses, `JSON.parse()` output)
- `any` in generated files or type declaration stubs
- `any` in test files for mock flexibility
- Existing `@ts-ignore` or `@ts-expect-error` with a documented reason

---

## Research Before Replacing

For each `any`, determine the correct type by:

1. **Trace the value's origin** — where is it created? What shape does it have?
2. **Check how it's used downstream** — what properties are accessed?
3. **Look at related types** — is there already a type for this shape in the codebase?
4. **Check package types** — does the library export a type for this?

```bash
# Find existing type definitions for the domain
grep -rn "interface\|type " src/types/ --include="*.ts"

# Check library types
cat node_modules/@types/some-lib/index.d.ts | grep "interface\|type " | head -20
```

---

## Apply (HIGH only)

Batch approach — fix by file, verify after each file:

```typescript
// Before
function processOrder(params: any): any {
  return { id: params.id, price: params.price * 1.1 }
}

// After
interface OrderInput {
  id: string
  price: number
}

interface OrderResult {
  id: string
  price: number
}

function processOrder(params: OrderInput): OrderResult {
  return { id: params.id, price: params.price * 1.1 }
}
```

After each file:
```bash
npx tsc --noEmit
```

---

## Boundary Type Rules

Keep `unknown` (do NOT replace) when:
- Value comes from `JSON.parse()` — content is truly unknown at compile time
- Value is a webhook payload from an external service
- Value is a raw database query result without an ORM type
- Value is from `process.env` (always `string | undefined`)

These are correct uses of `unknown`. Replacing them with a specific type creates a false guarantee.

---

## Report

```
## Step 5 — Type Strengthening

### Findings

| Location | Weak Type | Replacement | Confidence | Action |
|---|---|---|---|---|
| orders.ts:42 | `params: any` | `OrderParams` | HIGH | Replaced |
| trading.ts:88 | `result: any` | `ExecutionResult` | HIGH | Replaced |
| webhooks.ts:12 | `payload: any` | `unknown` (boundary) | LOW | Kept as-is |
| api_client.ts:55 | Complex generic | Needs refactor | MEDIUM | Reported |

### Changes Applied
- orders.ts: `params: any` → `OrderParams` (type imported from src/types/orders.ts)
- trading.ts: `result: any` → `ExecutionResult`

### Type Check Result
npx tsc --noEmit: 0 errors (was 0 before — no regressions)

### Skipped
- webhooks.ts — LOW: legitimate system boundary, `unknown` is correct
- api_client.ts — MEDIUM: complex generic requires broader refactor
```

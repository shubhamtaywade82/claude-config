# Step 6 — Error Handling Cleanup

## Goal
Remove silent error swallowers. Remove fallbacks that mask real problems. Every error handler must have a clear purpose: log, re-raise, or translate to a domain error. No error hiding.

---

## Detect

### Ruby
```bash
# Find rescue nil (silent swallow)
grep -rn "rescue nil\|rescue => _\|rescue => e$" app/ lib/ --include="*.rb"

# Find empty rescue blocks
grep -rn -A2 "rescue" app/ lib/ --include="*.rb" | grep -B1 "^--$\|^end$" | grep "rescue"

# Find blanket rescue Exception
grep -rn "rescue Exception\|rescue StandardError$" app/ lib/ --include="*.rb"

# Find || {} or || [] as error masking
grep -rn "|| {}\||| \[\]\|| false$\|| nil$" app/ lib/ --include="*.rb"
```

### TypeScript / JavaScript
```bash
# Find empty catch blocks
grep -rn "catch" src/ --include="*.ts" --include="*.js" -A3 | grep -B2 "^}"

# Find catch with only assignment (swallow)
grep -rn "catch.*=>" src/ --include="*.ts" | grep -v "logger\|log\|throw\|reject\|console"

# Find try/catch with no error use
grep -rn "catch (e)" src/ --include="*.ts" -A5 | grep -B4 "^}" | grep "catch"
```

---

## Classify

### HIGH — Apply (Remove / Fix)
- `rescue nil` with no logging — silently converts exceptions to nil
- `catch (e) {}` — completely empty, exception disappears
- `rescue => e` with no body (or only a comment)
- `rescue => _` (underscore) — explicitly discarded error
- `|| {}` or `|| false` as a default that masks a failed operation
- `rescue Exception` (Ruby) — swallows Interrupt, SignalException, SystemExit

### MEDIUM — Report Only
- `rescue => e; logger.error(e); end` — logs but doesn't re-raise (swallows at boundary, may be intentional)
- `rescue SomeError => e; retry` — retry without limit or backoff
- `catch (e) { return defaultValue }` — has a return, but defaultValue may mask the error
- Error handler that logs but always returns `nil`/`null` regardless of error type

### LOW — Skip
- `rescue ActiveRecord::RecordNotFound => e; render not_found; end` — correct boundary handling
- `rescue => e; raise MyDomainError, e.message; end` — translation pattern, correct
- `rescue => e; logger.error(e); raise; end` — log + re-raise, correct
- `try { ... } catch (e) { logger.error(e); throw e }` — JS equivalent of log + re-raise

---

## Fix Patterns

### Pattern 1: `rescue nil` → explicit handling
```ruby
# Before
user = find_user(id) rescue nil

# After — if nil is an acceptable result
user = find_user(id)
rescue UserNotFound
  nil

# After — if this should raise
user = find_user(id)  # let it raise naturally
```

### Pattern 2: Empty catch → log or re-raise
```typescript
// Before
try {
  await submitOrder(params)
} catch (e) {}

// After
try {
  await submitOrder(params)
} catch (e) {
  logger.error('Order submission failed', { error: e, params })
  throw e  // or: translate to domain error
}
```

### Pattern 3: Blanket `rescue Exception` → specific class
```ruby
# Before
rescue Exception => e
  puts e.message
end

# After
rescue StandardError => e
  logger.error(e.message)
  raise
end
```

### Pattern 4: Default masking `|| {}`
```ruby
# Before
config = load_config rescue {}

# After
begin
  config = load_config
rescue ConfigLoadError => e
  logger.error("Config load failed: #{e.message}")
  raise  # or use a Config.default if that's the correct fallback
end
```

---

## Apply (HIGH only)

For each HIGH finding:
1. Determine what the error handler SHOULD do (log? re-raise? translate?)
2. Check if callers depend on the nil/default return — if so, MEDIUM not HIGH
3. Apply the appropriate fix pattern
4. Run post-checklist immediately

**Check caller dependency:**
```bash
METHOD="some_method"
grep -rn "${METHOD}" app/ spec/ | grep -v "def ${METHOD}"
# If callers check for nil: inspect — may need MEDIUM classification
```

---

## Rules for Every Rescue

A rescue block is acceptable only if it does at least one of:
- `logger.error` / `Rails.logger.error` / structured logging
- `raise` (re-raise original or translated error)
- `Sentry.capture_exception(e)` or equivalent error tracker
- Returns a meaningful domain result (not just `nil` or `{}`)

---

## Report

```
## Step 6 — Error Handling Cleanup

### Findings

| Location | Pattern | Callers Expect nil? | Confidence | Action |
|---|---|---|---|---|
| orders.rb:42 | `rescue nil` | No | HIGH | Removed, let raise |
| api_client.rb:88 | `catch (e) {}` | No | HIGH | Added logger.error + throw |
| user_service.rb:15 | `rescue => e; logger.error(e)` | Yes (boundary) | MEDIUM | Reported |
| webhooks.rb:30 | `rescue Exception` | No | HIGH | Changed to rescue StandardError + raise |

### Changes Applied
- orders.rb:42 — removed `rescue nil`, exception now propagates naturally
- api_client.rb:88 — added `logger.error('Order submission failed', { error: e }); throw e`
- webhooks.rb:30 — `rescue Exception` → `rescue StandardError => e; logger.error(e); raise`

### Skipped
- user_service.rb:15 — MEDIUM: boundary logger, swallows intentionally, caller handles nil
```

# Step 3 (Rails Extension) — Rails-Aware Dead Code Detection

## When to Use
Run this AFTER the generic [step3_dead_code.md](step3_dead_code.md) for any Rails application. Rails has many framework conventions that static analysis tools miss.

---

## Rails-Specific Dead Code Categories

### 1. Background Jobs (Sidekiq / ActiveJob)

Before marking a job class dead, verify:

```bash
# Check Sidekiq schedule
grep -rn "ClassName\|class_name\|worker" config/sidekiq.yml config/schedule.yml 2>/dev/null

# Check .perform_later / .perform_async calls
grep -rn "ClassName\.perform" app/ lib/ spec/

# Check string-based enqueuing
grep -rn "\"ClassName\"\|'ClassName'" app/ lib/ config/

# Check Sidekiq::Client.push with class string
grep -rn "Sidekiq::Client\|sidekiq_options\|enqueue" app/ lib/
```

**Rule:** A job class is HIGH (dead) ONLY if it has zero `.perform_later`, `.perform_async`, string-based queue references, and no entry in schedule files.

### 2. ActiveRecord Callbacks

```bash
# Check after_save, before_create, etc. — these run automatically, not called directly
grep -rn "after_save\|before_create\|after_commit\|before_destroy\|after_update" app/models/

# The method referenced in a callback is NOT dead just because it has no direct callers
# e.g., after_save :sync_to_cache → sync_to_cache has 0 explicit callers, but IS alive
```

**Rule:** Any private method referenced in a `before_*`, `after_*`, `around_*` callback is NOT dead.

### 3. Concerns & Mixins

```bash
# Find all modules defined as concerns
ls app/models/concerns/ app/controllers/concerns/ 2>/dev/null

# For each concern, verify it's included somewhere
CONCERN="MyModule"
grep -rn "include ${CONCERN}\|extend ${CONCERN}\|prepend ${CONCERN}" app/ lib/
```

**Rule:** A concern with zero `include`/`extend`/`prepend` references in the codebase — AND not extended by `ActiveSupport::Concern` in a way that auto-includes — is HIGH (dead).

### 4. Routes → Controller Actions

```bash
# Get list of routed controller#action pairs
rails routes --no-header 2>/dev/null | awk '{print $NF}' | grep '#' | sort -u

# For a specific controller action, check if it's routed
rails routes --no-header 2>/dev/null | grep "orders#legacy_index"
```

**Rule:** A controller action with no route entry AND no direct call via `process_action` or internal redirect is HIGH (dead) — but verify it's not reachable via a wildcard route (`match '*path'`).

### 5. Webhook Endpoints

Before removing any controller action that receives external webhooks:

- [ ] Check external service documentation for configured webhook URLs
- [ ] Check application configuration: `config/initializers/`, environment variables
- [ ] Check database for webhook registration records
- [ ] Check provider dashboard if accessible

**Rule:** Any webhook endpoint → MEDIUM maximum. Never delete without external service confirmation.

### 6. STI Subclasses (Single Table Inheritance)

```bash
# Find STI classes
grep -rn "< ApplicationRecord\|< ActiveRecord::Base" app/models/ --include="*.rb" | \
  while read -r line; do
    class=$(echo "$line" | grep -oP "class \K\w+")
    parent=$(echo "$line" | grep -oP "< \K\w+")
    grep -rn "\"${class}\"\|'${class}'\|type.*${class}" db/ app/ | grep -v "class ${class}"
  done
```

**Rule:** A class whose name appears in a `type` column (STI) is NEVER dead — even with zero code references.

### 7. Autoloaded Constants via `const_get` / `constantize`

```bash
grep -rn "constantize\|const_get\|Object\.const_defined\|Module\.const_get" app/ lib/
```

If any pattern like `"#{type.camelize}Service".constantize` exists, any class matching that pattern is NOT safely deletable.

### 8. Observers & Event Handlers

```bash
grep -rn "ActiveRecord::Observer\|observe\|after_create.*:send_notification\|Wisper\|ActiveSupport::Notifications" app/ lib/
```

Any class registered as an observer or subscriber is alive even if it has no direct callers.

---

## Rails-Specific Classification

| Finding | Confidence | Reason |
|---------|------------|--------|
| Job class, 0 `.perform_later`, not in schedule | HIGH | Confirmed dead |
| Concern, 0 `include`/`extend`, not in base class | HIGH | Confirmed dead |
| Controller action, not in `rails routes` output, no wildcard | HIGH | Confirmed dead |
| Callback target method (after_save :method_name) | LOW | Framework calls it |
| STI subclass | LOW | Type column can reference it |
| Webhook controller | MEDIUM max | External config unknown |
| Job class with string reference in config | MEDIUM | Dynamic reference |
| Any class in scope of `constantize` pattern | MEDIUM | Dynamic lookup possible |

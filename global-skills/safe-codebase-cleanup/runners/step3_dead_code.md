# Step 3 — Dead Code Removal (Generic)

## Goal
Remove confirmed-dead code only. Suspected-dead → report, do not delete. The burden of proof is on confirmation of death, not suspicion of it.

For Rails projects, also run [step3_dead_code_rails.md](step3_dead_code_rails.md) after this step.

---

## Tools

### TypeScript / JavaScript
```bash
npx knip --reporter json > tmp/knip_baseline.json
# Review: unused exports, unresolved imports, unlisted binaries
```

### Ruby
```bash
# Manual grep approach (no autoloader-safe tool exists)
grep -rn "def " app/ lib/ --include="*.rb" | while read -r line; do
  method=$(echo "$line" | grep -oP "def \K\w+")
  file=$(echo "$line" | cut -d: -f1)
  count=$(grep -rn "\b${method}\b" app/ lib/ spec/ --include="*.rb" | grep -v "def ${method}" | wc -l)
  [ "$count" -eq 0 ] && echo "POSSIBLY DEAD: $method in $file"
done
```

---

## Detect

1. **Unused exported symbols** (TS): functions/classes exported but never imported anywhere
2. **Unreferenced private methods** (Ruby/TS): private methods with zero callers in the codebase
3. **Orphaned files**: files with no imports pointing to them and no known entry point
4. **Dead constants**: constants defined but never referenced
5. **Unreachable branches**: `if false`, `if ENV['FEATURE'] == 'false'` with hardcoded value

---

## Mandatory Verification Before Delete

For EVERY candidate, verify ALL of the following before classifying as HIGH:

### Dynamic Call Check
```bash
# Ruby: check for send/public_send/method(:name)
grep -rn "send.*:${METHOD_NAME}\|public_send.*:${METHOD_NAME}\|method(:${METHOD_NAME})" app/ lib/

# Ruby: check constantize / const_get
grep -rn "constantize\|const_get\|const_missing" app/ lib/

# JS/TS: check string-based require/import
grep -rn "require(['\"].*${MODULE}" src/
```

### Framework Convention Check
- Rails: see [step3_dead_code_rails.md](step3_dead_code_rails.md) for full framework checklist
- Express: check route registration files for string-based handler names
- Background jobs: check scheduler config files (cron, Sidekiq schedule.yml)

### Config / Initializer Reference Check
```bash
grep -rn "${CLASS_OR_METHOD}" config/ initializers/ .env* *.yml *.yaml
```

### Test-Only Usage Check
```bash
# If only used in specs → NOT dead in production, but worth noting
grep -rn "${METHOD}" spec/ test/
```

---

## Classify

### HIGH — Apply (Delete)
All of the following must be true:
- Zero static references in application code
- Zero dynamic dispatch references (send, constantize, string require)
- Not registered in any config file, routes, or scheduler
- Not a framework-conventional entrypoint (e.g., `perform` on a job class)
- Confirmed: not used in any active background queue

### MEDIUM — Report Only
- Zero static references but dynamic call pattern exists in codebase
- Referenced only in specs (not dead, but possibly over-tested)
- File appears orphaned but path matches a naming pattern used by a loader
- Orphaned file in `lib/` (may be loaded by requiring the whole directory)

### LOW — Skip
- Anything with `send`, `constantize`, or `method(:name)` anywhere in codebase
- Framework hook methods (`before_action`, `after_commit`, `perform`, `call`)

---

## Apply (HIGH only)

For each confirmed dead item:
1. Delete the file or method
2. Run post-checklist immediately
3. If tests fail → restore and downgrade to MEDIUM

---

## Report

```
## Step 3 — Dead Code Removal

### Findings

| Item | File | Refs | Dynamic? | Framework? | Confidence | Action |
|---|---|---|---|---|---|---|
| `LegacyImporter` | app/services/legacy_importer.rb | 0 | No | No | HIGH | Deleted |
| `format_legacy_date` | app/helpers/date_helper.rb | 0 | No | No | HIGH | Deleted |
| `process_webhook` | app/controllers/webhooks.rb | 0 | send() found | - | MEDIUM | Reported |

### Changes Applied
- Deleted app/services/legacy_importer.rb
- Deleted private method `format_legacy_date` from app/helpers/date_helper.rb

### Skipped
- `process_webhook` — MEDIUM: `send("process_#{type}")` pattern found in webhooks controller
```

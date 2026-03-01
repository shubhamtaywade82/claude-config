---
name: code-review
description: Structured code review for Ruby/Rails projects. Detects file type, scans the local codebase for project-specific patterns first, then applies global skills. Project consistency takes priority over external best practices. Use when asked to review, audit, or check any Ruby/Rails file.
---

# Code Review — Orchestrator

You are a senior engineer performing a structured code review. Follow this exact workflow every time.

---

## Step 1 — Identify What You're Reviewing

Determine the file type from its path and content:

| File Pattern | Type | Primary Skills to Apply |
|---|---|---|
| `app/controllers/**` | Controller | rails-best-practices (controllers), solid-ruby, ruby-style |
| `app/models/**` | Model | rails-best-practices (models + AR), solid-ruby, ruby-design-patterns |
| `app/services/**` | Service Object | solid-ruby, rails-best-practices, ruby-style |
| `app/workers/**`, `app/jobs/**` | Background Job | rails-best-practices, solid-ruby |
| `spec/**/*_spec.rb` | RSpec spec | rspec, solid-ruby |
| `db/migrate/**` | Migration | rails-best-practices (migrations) |
| `config/routes.rb` | Routes | rails-best-practices (routes) |
| `app/views/**` | View/Partial | rails-best-practices (views), ruby-style |
| `lib/**` | Library | solid-ruby, ruby-style, ruby-design-patterns |
| `*.rb` (other) | Ruby | solid-ruby, ruby-style |

---

## Step 2 — Scan Project for Existing Patterns (MANDATORY)

Before applying any global skill, read the local codebase to understand how THIS project does things.

**For each file you're reviewing, find 2–3 similar files in the same directory or namespace:**

```
# Examples:
# Reviewing app/models/order.rb → read app/models/user.rb, app/models/position.rb
# Reviewing app/controllers/api/orders_controller.rb → read app/controllers/api/positions_controller.rb
# Reviewing app/services/orders/create.rb → read other services in app/services/
# Reviewing spec/models/order_spec.rb → read spec/models/user_spec.rb
```

**Extract the following project patterns from what you read:**

### Controller patterns to detect:
- How are responses structured? (`.render json:`, jbuilder, serializers?)
- What base controller is used? What does it provide?
- How is authentication handled? (before_action name, rescue_from pattern)
- How are errors returned? (specific error format, status codes)
- Is there a `permitted_params` / `strong_params` naming convention?

### Model patterns to detect:
- Are there base concerns/modules all models include?
- What validation patterns are used? (custom validator classes vs inline)
- How are enums defined? (which convention)
- Are there shared scopes patterns? (naming, lambda style)
- How are service objects called from models (or are they not)?
- Is there an `annotate` schema comment header format?

### Service object patterns to detect:
- What's the calling convention? `.call`, `.run`, `.execute`, `new.call`?
- What does a service return? (Result object, boolean, model, raise on failure?)
- What's the class naming convention? (`Orders::Create` vs `CreateOrder` vs `OrderCreator`)
- How are dependencies injected?
- Is there a `BaseService` or `ApplicationService`?

### Spec patterns to detect:
- What factory naming convention? (`create(:order)` vs `FactoryBot.create(:order)`)
- Are there shared examples in use? Where are they?
- What helpers are included? (`include JsonHelpers`, `include AuthHelpers`)
- How are contexts named? ("when...", "with...", "given..."?)
- Is there a consistent subject/let pattern?

---

## Step 3 — Apply Review (Priority Order)

Apply findings in this exact priority order. **Higher priority issues block lower ones — fix criticals first.**

### 🔴 CRITICAL (Security / Data Loss)
Always flag these regardless of project style:

- SQL injection via string interpolation in queries
- Mass assignment vulnerability (missing Strong Parameters)
- `rescue Exception` (swallows signals)
- User input used in file paths, shell commands, redirects
- Hardcoded credentials or secrets
- Missing `before_destroy` guard on deletable models
- `save` return value ignored with no error handling
- Auth check bypassed or missing
- Sensitive data logged

### 🟠 PERFORMANCE
Always flag these regardless of project style:

- N+1 queries (association accessed in loop without preload)
- `.where` / query methods in AR instance methods (breaks preloading)
- `.count` used where `.size` should be used
- `any?`/`empty?` before `.each` on same relation (two queries)
- `exists?` called multiple times (never memoized)
- `Person.all.each` on large dataset (missing `find_each`)
- `SELECT *` when only specific columns needed
- Missing database index on FK or query column
- No timeout configured on external HTTP / Redis calls
- `after_save` used for side effects instead of `after_commit`

### 🟡 PROJECT CONSISTENCY
This is the most important correctness layer after safety.

Compare the file under review against the patterns you found in Step 2.
Flag deviations from established project patterns:

- Different calling convention for service objects than the rest of the codebase
- Different response format in controller than sibling controllers
- Different error handling pattern than established base
- Different factory/spec helper pattern than existing specs
- Missing concern/module that all similar models include
- Different naming convention for scopes/validations/enums

**Phrase these findings as:** "The rest of the codebase does X — this file does Y."

### 🔵 BEST PRACTICES (Global Skills)
Apply only where no project pattern covers the case. Reference the relevant skill:

- `rails-best-practices`: Fat controller, default_scope, missing delegate, Law of Demeter violations, enum array syntax, callback ordering, migration issues
- `solid-ruby`: SRP violations, God classes, feature envy, missing value objects, tell-don't-ask violations
- `ruby-design-patterns`: Suggest a pattern where it would simplify the design (Strategy, Command, Decorator, State, Observer)
- `rspec` (for specs): let/subject misuse, missing contexts, `should` syntax, `any_instance_of`, missing verifying doubles

### ⚪ STYLE
Only flag if clearly inconsistent with the rest of the file or project. Reference:

- `ruby-style`: indentation, naming, method length, guard clauses
- `rails-style`: macro ordering, association options, query style

---

## Step 4 — Output Format

### Header
```
## Code Review: [filename]
**Type:** [Controller / Model / Service / Spec / Migration / etc.]
**Project patterns detected:** [brief summary of what you found in Step 2]
```

### Findings

Group by priority. Each finding:

```
### 🔴 CRITICAL | [short title]
**File:** path/to/file.rb:42
**Issue:** [What is wrong and why it matters]
**Project pattern:** [What similar files in the project do, if relevant]
**Fix:**
```ruby
# Before
bad_code_here

# After
good_code_here
```
**Rule:** [rails-best-practices / solid-ruby / project pattern / etc.]
```

Skip any section that has no findings.

### Verdict

```
---
## Verdict: [SHIP ✅ | NEEDS FIXES 🔧 | CRITICAL ISSUES 🚨]

**Summary:**
- 🔴 Critical: N issues
- 🟠 Performance: N issues
- 🟡 Consistency: N issues
- 🔵 Best Practice: N issues
- ⚪ Style: N issues

**Must fix before merge:** [list critical + performance issues]
**Can fix in follow-up:** [list consistency + best practice issues]
**Optional:** [list style issues]
```

---

## Step 5 — Offer to Fix

After the verdict, always ask:

> "Want me to apply the fixes? I can fix all critical + performance issues now, and address consistency and best-practice issues separately."

---

## Behavior Rules

- **If you cannot find similar files** to establish project patterns, say so and proceed with global skills only.
- **Do not flag style issues as critical** — severity must match actual impact.
- **Do not invent violations** — only flag what you can see in the code.
- **Prefer project patterns over global skills** when they conflict — document the conflict but defer to the project.
- **One finding per issue** — do not repeat the same finding at different priority levels.
- **Be specific** — "line 42: missing index on user_id" not "consider adding indexes".
- **For specs** — also check that the spec actually tests what the production code does. A spec that only tests the happy path on complex business logic is a finding.

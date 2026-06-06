# Ruby / Rails — AI Slop Patterns & Idiomatic Fixes

## Service Object Anti-Patterns

### 1. Trivial Single-Method Service
**Smell:** `UserRegistrationService` with only `call` that delegates to `User.create`.
**Fix:** Collapse into model method or controller flow if no orchestration.
**Safety check:** Ensure no transaction wrapping, no multi-model coordination, no external API calls.

```ruby
# BEFORE (AI slop)
class UserRegistrationService
  def self.call(params)
    User.create(params)
  end
end

# AFTER (idiomatic)
# In controller:
user = User.create(user_params)
```

### 2. Fragmented Orchestration
**Smell:** `OrderProcessor`, `OrderHandler`, `OrderManager` each doing one step.
**Fix:** Merge into a single transaction object or explicit workflow step sequence.
**Safety check:** Verify each step's side effects and rollback behavior.

```ruby
# BEFORE
OrderProcessor.new(order).validate
OrderHandler.new(order).charge
OrderManager.new(order).notify

# AFTER
OrderCheckout.new(order).call # one transaction, explicit steps
```

### 3. Fake Inheritance Chain
**Smell:** `BaseService` → `ApplicationService` → `UserService` with no polymorphism.
**Fix:** Delete the chain. Use modules for shared behavior or plain POROs.
**Safety check:** Check if any code does `is_a?(BaseService)` or relies on `super`.

## Controller Anti-Patterns

### 4. Repeated Param Sanitization
**Smell:** `params[:foo].to_s.strip` repeated across controllers.
**Fix:** Extract to strong parameters or a form object only if reused ≥3 times.
**Safety check:** Verify all call sites use the same logic.

### 5. Before-Action Business Logic
**Smell:** `before_save` doing business logic that belongs in explicit workflow.
**Fix:** Flag for discussion. Do not move without checking all call paths (seeds, console, background jobs).
**Safety check:** Search for `.create`, `.save`, `.update` calls on the model across the entire repo.

## Model Anti-Patterns

### 6. Unnecessary Concerns
**Smell:** Concern used in exactly one model, or concern is just a method extracted for "reuse" that never got reused.
**Fix:** Inline back into the model if no other consumer exists.
**Safety check:** `grep` for `include MyConcern` across the repo.

### 7. Duplicated Validations
**Smell:** `validates :email, presence: true` in both `User` and `Admin`.
**Fix:** Extract to shared concern or custom validator only if the validation is complex. Simple validations can duplicate.
**Safety check:** Ensure error messages and conditional logic (`if:`, `unless:`) match exactly.

### 8. Scope vs Service Confusion
**Smell:** Service object that only builds a `where` chain.
**Fix:** Convert to model scope.
**Safety check:** Check if the service adds pagination, authorization, or other non-query logic.

```ruby
# BEFORE
class RecentPostsService
  def self.call(user)
    Post.where(user: user).where("created_at > ?", 1.week.ago).order(created_at: :desc)
  end
end

# AFTER
# In Post model:
scope :recent, -> { where("created_at > ?", 1.week.ago).order(created_at: :desc) }
# In controller:
user.posts.recent
```

## Naming Noise

### 9. Verb-Inflation Cluster
**Smell:** `do_process`, `execute_action`, `perform_task`, `run_operation` for the same concept.
**Fix:** Standardize on one verb (prefer `call` for services, `handle` for events, `process` for pipelines).
**Safety check:** Update all call sites simultaneously to avoid mixed naming.

### 10. Manager/Processor/Handler/Coordinator Suffixes
**Smell:** Class names with enterprise suffixes that do trivial work.
**Fix:** Rename to what it actually does: `EmailSender`, `PaymentCapture`, `ReportGenerator`.
**Safety check:** Check for constant references (`EmailManager` used in strings, metaprogramming).

# Boolean Logic — Clean Ruby

## Extract to Named Variables

When a boolean expression isn't immediately obvious, store the result in a descriptively named variable.

```ruby
# Before — reader must parse the condition
def respawn(player)
  if player.time_until_spawn <= 0 && player.health == 0
    respawn_at_base
  end
end

# After — variable name explains the intent
def respawn(player)
  ready_to_spawn = player.time_until_spawn <= 0 && player.health == 0
  respawn_at_base if ready_to_spawn
end
```

**Caution**: Extracting to a variable breaks short-circuit evaluation. If the first condition guards against nil, the second line will still execute and may raise.

```ruby
# Broken — `can_edit` executes even if user is nil
user_exists = !user.nil?
can_edit = user.editor? && !user.disabled?  # NoMethodError if user is nil

# Fixed — guard first
return unless user

can_edit = user.editor? && !user.disabled?
```

## Extract to Named Methods (preferred)

For reusable or complex conditions, a predicate method is better than a variable.

```ruby
# Before — inline boolean soup
def send_order_followup_email(order)
  all_delivered = order.items.all?(&:delivered?)
  if all_delivered && order.purchase_date < Time.now
    # send email
  end
end

# After — intent is the method name
def send_order_followup_email(order)
  return unless order_delivered?(order)

  # send email
end

def order_delivered?(order)
  order.items.all?(&:delivered?) && order.purchase_date < Time.now
end
```

Benefits: reusable, independently testable, keeps parent method focused.

## Unless: Avoid It

`unless` is the inverse of `if`. For simple single conditions it can read well, but it becomes confusing with:
- Compound conditions (`unless a && b` — what does this even mean?)
- Double negatives
- Else clauses

**Rule**: Don't use `unless`. Use `if !condition` or invert the predicate method name. If you must use `unless`, limit it to single, simple conditions with no `else`.

```ruby
# Acceptable (barely)
unless user_authenticated?
  redirect_to login_path
end

# Better — explicit
if !user_authenticated?
  redirect_to login_path
end

# Best — invert the predicate
if unauthenticated?
  redirect_to login_path
end
```

## Ternary Operator

Use ternary only for simple, single-condition assignments. If the condition is compound, use `if/else`.

```ruby
# Good — simple, readable
result = a > b ? "A is greater" : "B is greater"

# Bad — compound condition, unreadable on one line
result = logged_in? && admin? ? "Admin logged in" : "Not admin"

# Fix — use if/else
if logged_in? && admin?
  result = "Admin logged in"
else
  result = "Not admin"
end
```

## Double Negatives: Never

If your boolean reads as "not not X", the method name is wrong. Invert it.

```ruby
# Bad — double negative
if !library.is_not_found(book)
  puts "Book is in the library"
end

# Good — positive method name
if library.found?(book)
  puts "Book is in the library"
end
```

## Truthy / Falsy

Ruby only has two falsy values: `nil` and `false`. Everything else is truthy (including `0`, `""`, `[]`).

Leverage this — don't write explicit comparisons to `true`/`false`/`nil` unless type matters.

```ruby
# Unnecessary
if name == true
if name != nil

# Idiomatic
if name
unless name
```

## `&&` vs `&`

- `&&` short-circuits: if the left side is false, the right side is never evaluated
- `&` evaluates both sides regardless

**Always use `&&`** unless you explicitly need both sides to execute (rare).

```ruby
# Dangerous — & evaluates second_user.type even when second_user is nil
if first_user.type == :admin & second_user.type == :admin

# Safe — && skips right side if left side is false
if first_user.type == :admin && second_user.type == :admin
```

## Safe Navigation (`&.`)

When chaining on a potentially nil object, use safe navigation instead of nil checks.

```ruby
# Verbose
if user && user.profile && user.profile.avatar
  # ...
end

# Clean
if user&.profile&.avatar
  # ...
end
```

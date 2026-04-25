# Refactoring Patterns — Clean Ruby

## Mindset: No Change Too Small

Any improvement, no matter how small, leaves the code better than you found it. A renamed variable today compounds into a readable codebase over months. Don't wait for a "big refactor" — make incremental changes on every touch.

## The Refactoring Sequence

Apply these steps in order. Stop at any point — partial improvement is still improvement.

### 1. Rename Variables
Expand abbreviations. Replace single letters. Make names describe data, not type.

```ruby
# Before
a1 = Address.new("123 Street", 12345)
s_list = prep([a1, a2])

# After
address1 = Address.new("123 Street", 12345)
addresses = prepare_addresses([address1, address2])
```

### 2. Rename Methods
Replace abbreviations with full verbs. Append the domain noun if the method name is too generic.

```ruby
# Before
def prep(a_list); end

# After
def prepare_addresses(addresses); end
```

### 3. Extract Methods
Turn each distinct operation into a named method. Remove comments that described what the code did — the method name now serves that purpose.

```ruby
# Before
def prepare_addresses(addresses)
  # remove addresses with no zip
  addresses.reject! { |address| address.zip.nil? }
  # sort addresses by zip
  addresses.sort_by { |address| address.zip }
end

# After
def prepare_addresses(addresses)
  remove_nil_zips(addresses)
  sort_by_zip(addresses)
end

def remove_nil_zips(addresses)
  addresses.reject! { |address| address.zip.nil? }
end

def sort_by_zip(addresses)
  addresses.sort_by { |address| address.zip }
end
```

### 4. Extract to a Class
When a group of methods share a common purpose and operate on the same data, wrap them in a class.

```ruby
class AddressCleaner
  def initialize(addresses)
    @addresses = addresses
  end

  def clean
    remove_nil_zips
    sort_by_zip
  end

  private

  def remove_nil_zips
    @addresses.reject! { |address| address.zip.nil? }
  end

  def sort_by_zip
    @addresses.sort_by { |address| address.zip }
  end
end

cleaner = AddressCleaner.new([address1, address2])
addresses = cleaner.clean
```

## SRP Violations — How to Spot and Fix

### Spot
- Class name includes "and" in its description
- Class has methods for unrelated responsibilities
- Changing one feature requires editing a class that "shouldn't" be involved
- Model classes growing beyond validations/scopes/associations

### Fix
Extract the second responsibility into its own class. The original class delegates to or consumes the new one.

```ruby
# Before — User handles licensing
class User < ApplicationRecord
  def trial_user?
    trial_end_date <= Date.today
  end
end

# After — License is its own concept
class License
  def initialize(user)
    @user = user
  end

  def trial?
    @user.trial_end_date <= Date.today
  end
end
```

## Common Refactoring Moves

### Replace Conditional Chain with Lookup/Polymorphism

```ruby
# Before — fragile, grows with each new level
def log(message, level)
  if level.to_s == 'warning'
    puts "WARN: #{message}"
  elsif level.to_s == 'error'
    puts "ERROR: #{message}"
  end
end

# After — extensible, zero changes for new levels
def log(message, level)
  puts "#{level.to_s.upcase}: #{message}"
end
```

### Replace Comment with Method

Every comment that describes *what* code does is a refactoring opportunity. The method name becomes the documentation.

### Flatten Nested Conditionals

Use guard clauses to eliminate nesting. Each guard handles one edge case and exits early.

### Consolidate Duplicate Code

If the same 3+ lines appear in multiple places, extract a method. If the same method appears in multiple classes, extract a module or shared class.

### Reduce Parameter Count

When a method accumulates params, group related ones into a parameter object (see methods.md).

## When NOT to Refactor

- In the middle of a production incident — fix first, refactor later
- When there are no tests covering the code — write tests first
- When the refactoring scope keeps growing — timebox it, submit what you have
- When the team hasn't agreed on the target pattern — align first

## Technical Debt Triage

Not all debt is equal. Prioritize refactoring code that:
1. Changes frequently (high churn)
2. Has known bugs
3. Blocks new feature development
4. Is untested

Leave stable, rarely-touched code alone even if it's ugly — the risk of breaking it outweighs the benefit of cleaning it.

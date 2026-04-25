# Method Design — Clean Ruby

## Parameters

### Fewer is Better
Each parameter multiplies the complexity of a method. Interactions between parameters create hidden edge cases.

**Target**: 0–2 params ideal, 3 max for public methods.

```ruby
# Bad — 5 params with hidden interactions
def start_game(num_players, start_score, number_of_rounds, score_to_win, network_game)
end

# Good — wrap in a config object
class GameConfig
  attr_reader :num_players, :start_score, :number_of_rounds, :score_to_win, :network_game

  def initialize(num_players:, start_score:, number_of_rounds:, score_to_win:, network_game:)
    @num_players = num_players
    @start_score = start_score
    @number_of_rounds = number_of_rounds
    @score_to_win = score_to_win
    @network_game = network_game
  end
end

def start_game(config)
  # single param, validated elsewhere
end
```

### Parameter Order
Required params first, optional params last. Use keyword arguments for 2+ params to make call sites self-documenting.

```ruby
# Good — keyword args, clear at call site
def create_order(user:, items:, discount: 0)
end

create_order(user: current_user, items: cart_items, discount: 10)
```

### Handle Unexpected Input
When a parameter could be nil or wrong type, handle it early. Don't let bad data propagate.

```ruby
def greeting(name)
  "Hello #{name.to_s.split.first}".rstrip
end
```

## Return Values

### Leverage Implicit Return
Ruby returns the last expression. Don't create unnecessary intermediate variables.

```ruby
# Bad — unnecessary variable
def sum(a, b)
  c = a + b
  return c
end

# Good — implicit return
def sum(a, b)
  a + b
end
```

### Consistent Return Types
A method should always return the same type. Don't return a string sometimes and nil other times without good reason.

## Guard Clauses

Use guard clauses to handle edge cases at the top, keeping the main logic path unindented.

```ruby
# Bad — nested conditionals
def send_promo_email(user)
  if user.email.present?
    if user.promos_sent < MAX_PROMO_RATE
      UserMailer.promo_email(user).deliver
    end
  end
end

# Good — guard clause + extracted predicate
def send_promo_email(user)
  return unless can_send_promo?(user)

  UserMailer.promo_email(user).deliver
end

def can_send_promo?(user)
  user.email.present? && user.promos_sent < MAX_PROMO_RATE
end
```

## Length

### Target: 5–10 lines
A method doing one thing well rarely exceeds 10 lines. If it does, extract sub-operations.

### But Not Too Short
Don't extract single-line methods unless they add naming value. A method that wraps `a + b` with no added meaning is noise.

### How to Shorten
1. Identify distinct operations within the method
2. Extract each to a private method with a descriptive name
3. The parent method becomes a sequence of named steps

```ruby
# Before — one method doing three things
def import_accounts(file_path)
  file = File.new(file_path)
  lines = file.readlines
  lines.collect do |line|
    parts = line.split(',')
    Account.create(name: parts[0], email: parts[1])
  end
end

# After — each step is a named method
def import_accounts(file_path)
  lines = read_file(file_path)
  create_accounts(lines)
end

private

def read_file(file_path)
  File.new(file_path).readlines
end

def create_accounts(lines)
  lines.collect { |line| create_account_from(line) }
end

def create_account_from(line)
  params = parse_account_line(line)
  Account.create(params)
end

def parse_account_line(line)
  info = line.split(',')
  { name: info[0], email: info[1] }
end
```

## Comments

### Quality Comments Explain *Why*, Never *What*
If a comment describes what code does, the code is not self-documenting. Extract a named method instead.

```ruby
# Bad — comment describes the what
# Remove addresses with no zip
addresses.reject! { |a| a.zip.nil? }

# Good — method name IS the documentation
remove_nil_zips(addresses)
```

### Stale Comments Are Worse Than No Comments
Comments drift from code over time. A wrong comment is actively harmful. Prefer self-documenting code.

### When Comments Are Valid
- Explaining a non-obvious business rule
- Documenting external system quirks
- Linking to a ticket or spec for context
- Warning about performance implications

## Limit Nesting

Nested conditionals > 2 levels deep signal a method that does too much.

```ruby
# Bad — wave-shaped nesting
def process(user, order)
  if user.active?
    if order.valid?
      if order.items.any?
        # actual work buried 3 levels deep
      end
    end
  end
end

# Good — guard clauses flatten the structure
def process(user, order)
  return unless user.active?
  return unless order.valid?
  return unless order.items.any?

  # actual work at top level
end
```

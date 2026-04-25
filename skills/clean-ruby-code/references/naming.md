# Naming Rules — Clean Ruby

## Variables

### Convention: snake_case (always)
Ruby variables use snake_case. Never camelCase, never Hungarian notation.
The extra cognitive load of non-standard conventions compounds across thousands of lines.

### Describe the Data, Not the Type
The name should tell the reader what the variable *represents*, not what it *is*.

```ruby
# Bad — name describes the container, not the content
user = 'bob'
start_data = { players: 4, score_to_win: 5 }

# Good — name describes the meaning
first_name = 'bob'
game_config = { players: 4, score_to_win: 5 }
```

### Length: Short but Complete
Remove words that don't add information. If context (class/method name) already provides meaning, the variable can be shorter.

```ruby
# Bad — redundant words
final_purchase_total_amount = 100

# Good — context provides the rest
total_amount = 100
```

### No Crutch Words
These words are vague enough to mean anything, which means they communicate nothing:
- `Manager`, `Data`, `Info`, `List`

```ruby
# Bad — "Manager" hides the actual responsibility
class PlayerManager; end

# Good — states exactly what it does
class PlayerSpawner; end
```

### No Conjunctions
If a variable name contains "and" or "or", it holds data for multiple purposes. Split it.

```ruby
# Bad
score_and_player_count = { score: 100, player_count: 2 }

# Good
score = 100
player_count = 2
```

### No Numeric Characters (unless versioning)
A name like `year_1985` describes the data value, not what it represents. If the value changes, the name becomes a lie.

```ruby
# Bad
year_1985 = '1985'

# Good
start_of_grunge = '1985'
```

## Methods

### Always Use Verbs
Methods perform actions. Their names should read as verb phrases.

```ruby
# Bad — noun, unclear what it does
def money(amount); end

# Good — verb phrase, action is clear
def pay_bill(amount); end
```

### Boolean Returns: Use `?` Suffix
Ruby convention: methods returning true/false end with `?`.

```ruby
def equal?(a, b)
  a == b
end

# Usage reads like English
if equal?('test', 'test')
  puts 'Match'
end
```

### Destructive Methods: Use `!` Suffix
Methods that mutate the receiver's state get `!` to warn the caller.

```ruby
class User
  attr_accessor :friends

  def remove_friend!(friend)
    @friends.delete(friend)
  end
end
```

## Classes

### Name by Purpose
Identify the core responsibility, then name the class after it.

```ruby
# Two loose methods with repeated "new_user_" prefix → class candidate
class UserSetup
  def initialize(user)
    @user = user
  end

  def execute
    add_coins
    send_welcome
  end

  private

  def add_coins; end
  def send_welcome; end
end
```

### Name by Role (when applicable)
Suffix with the architectural role: `Query`, `Presenter`, `Service`, `Policy`.

```ruby
class InActiveUserQuery
  def initialize(relation = User)
    @relation = relation
  end

  def all
    @relation.where(last_login: 6.months.ago, paid_account: false)
  end
end
```

## Modules

Name for the concept the module groups. If you can't describe it in one word/phrase, the module is doing too much — split it.

```ruby
module Calculable
  def add(a, b)
    a + b
  end

  def subtract(a, b)
    a - b
  end
end
```

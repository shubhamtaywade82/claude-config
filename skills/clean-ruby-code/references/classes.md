# Class Architecture — Clean Ruby

## Initialize: Keep It Simple

The `initialize` method should only perform assignments. No external API calls, no database queries, no file I/O. These operations are slow, error-prone, and surprise the caller.

```ruby
# Bad — initialize has side effects
class BankAccount
  def initialize(number)
    @number = number
    external = ExternalBankAccount.new
    external.load_balances(@number)      # slow, error-prone
    external.sync_transactions           # surprise side effect
  end
end

# Good — assignment only, explicit setup method
class BankAccount
  def initialize(number)
    @number = number
  end

  def load_external_data
    external = ExternalBankAccount.new
    external.load_balances(@number)
    external.sync_transactions
  end
end

account = BankAccount.new("1234")
account.load_external_data  # caller controls when this happens
```

### When Errors in Initialize Are OK
Raise `ArgumentError` if the object would be unusable without valid input. Fail fast on truly invalid state.

```ruby
class BankAccount
  def initialize(number)
    raise ArgumentError, "Account number required" if number.nil?
    @number = number
  end
end
```

## Too Many Parameters

Same rule as methods: max 3 params. Extract a parameter object.

```ruby
# Bad — 5 positional args, order is impossible to remember
class Property
  def initialize(street, street2, city, state, zipcode)
    @street = street
    @street2 = street2
    @city = city
    @state = state
    @zipcode = zipcode
  end
end

# Good — extract Address, Property takes one object
class Address
  attr_reader :street, :street2, :city, :state, :zipcode

  def initialize(street:, city:, state:, zipcode:, street2: nil)
    @street = street
    @street2 = street2
    @city = city
    @state = state
    @zipcode = zipcode
  end
end

class Property
  def initialize(address)
    @address = address
  end
end
```

## Class Methods vs Instance Methods

If a method doesn't need instance state, make it a class method. If it creates instances of the class, it belongs as a class method (factory pattern).

```ruby
class Car
  attr_reader :year, :make, :model

  def initialize(year, make, model)
    @year = year
    @make = make
    @model = model
  end

  def self.current_year(make, model)
    new(Time.now.year, make, model)
  end
end

car = Car.current_year('Nissan', 'Altima')
```

## Instance Variables

Prefer `attr_reader` / `attr_accessor` over directly referencing `@variables` in method bodies. Accessor methods can be overridden, memoized, or decorated. Direct `@var` access bypasses all of that.

```ruby
# Prefer
class User
  attr_reader :name, :email

  def initialize(name:, email:)
    @name = name
    @email = email
  end

  def display_name
    name.titleize  # uses attr_reader, not @name
  end
end
```

## Private Methods

### Placement
All private methods below the `private` keyword, ordered by call sequence (first called → first listed).

### When to Extract
- The public method is getting long
- A block of code has a distinct sub-purpose
- The same logic appears in multiple methods

### When to Move to a Module
If private methods are generic utilities (math, string formatting, date helpers) that have no coupling to the class's domain, extract them to a module.

```ruby
module Calculable
  def add(a, b)
    a + b
  end

  def multiply(a, b)
    a * b
  end
end

class BankAccount
  include Calculable

  def initialize(balance, interest_rate)
    @balance = balance
    @interest_rate = interest_rate
  end

  def add_to_balance(amount)
    @balance = add(@balance, amount)
  end

  def calculate_interest
    multiply(@balance, @interest_rate)
  end
end
```

## Method Order Within a Class

Follow this order for predictable navigation:

1. Constants
2. `attr_*` declarations
3. `initialize`
4. Class methods (`self.xxx`)
5. Public instance methods
6. `private` keyword
7. Private instance methods (in call order)

## Limiting Inheritance

**Max 3 levels deep.** Beyond that:
- Finding code becomes a scavenger hunt
- Class count explodes
- Coupling becomes invisible

### Composition Over Inheritance

Instead of "what a class IS" (inheritance), think "what a class HAS" (composition).

```ruby
# Inheritance approach — fragile, deep hierarchy
class Business; end
class RetailBusiness < Business; end
class SuperMarket < RetailBusiness; end

# Composition approach — flexible, explicit
class Accountant
  def file_taxes(entity)
    # tax logic
  end
end

class SuperMarket
  def initialize(accountant)
    @accountant = accountant
  end
end

accountant = Accountant.new
store = SuperMarket.new(accountant)
```

## Single Responsibility Principle (SRP)

A class should have one reason to change. If you can describe a class's purpose with "and" (it manages users AND handles licensing), split it.

```ruby
# Bad — User model handles licensing
class User < ApplicationRecord
  def trial_user?
    trial_end_date <= Date.today
  end
end

# Good — licensing extracted to its own class
class License
  def initialize(user)
    @user = user
  end

  def trial?
    @user.trial_end_date <= Date.today
  end
end
```

Benefits: `License` can evolve independently, is testable without DB, and can be reattached to `Company` later without touching `User`.

## Rails-Specific Class Patterns

### Models: Thin
Only validations, scopes, associations, and simple attribute-derived methods.

### Controllers: Thin
Delegate to domain objects. One public action = one clear intent.

### Query Objects
Extract complex `where` chains out of controllers and models.

```ruby
class ActiveSubscriberQuery
  def initialize(relation = User)
    @relation = relation
  end

  def call
    @relation.where(subscribed: true).where('last_active_at > ?', 30.days.ago)
  end
end
```

### Service Objects (use sparingly)
Only for orchestrating multiple domain objects or external system calls. Not for wrapping single model operations.

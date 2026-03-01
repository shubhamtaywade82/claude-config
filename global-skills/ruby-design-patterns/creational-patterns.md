# Ruby Design Patterns — Creational (1–5)

Creational patterns provide object creation mechanisms that increase flexibility and reuse.

---

### 1. Abstract Factory
**Intent:** Create families of related objects without specifying their concrete classes. Ensures products within a family are always compatible.

**When to use:**
- System needs to work with multiple families of products
- You want to enforce compatibility constraints between related objects
- You want to swap entire product families at runtime

**Rails use:** Swap between real broker API clients and mock/test doubles; swap notification providers (email vs SMS vs push).

```ruby
class AbstractFactory
  def create_product_a = raise NotImplementedError
  def create_product_b = raise NotImplementedError
end

class ConcreteFactory1 < AbstractFactory
  def create_product_a = ConcreteProductA1.new
  def create_product_b = ConcreteProductB1.new
end

class ConcreteFactory2 < AbstractFactory
  def create_product_a = ConcreteProductA2.new
  def create_product_b = ConcreteProductB2.new
end

class AbstractProductA
  def useful_function_a = raise NotImplementedError
end

class ConcreteProductA1 < AbstractProductA
  def useful_function_a = 'Result of product A1'
end

class ConcreteProductA2 < AbstractProductA
  def useful_function_a = 'Result of product A2'
end

class AbstractProductB
  def useful_function_b = raise NotImplementedError
  def another_useful_function_b(collaborator) = raise NotImplementedError
end

class ConcreteProductB1 < AbstractProductB
  def useful_function_b = 'Result of product B1'
  def another_useful_function_b(collaborator)
    "B1 collaborating with (#{collaborator.useful_function_a})"
  end
end

def client_code(factory)
  product_a = factory.create_product_a
  product_b = factory.create_product_b
  puts product_b.useful_function_b
  puts product_b.another_useful_function_b(product_a)
end

client_code(ConcreteFactory1.new)
client_code(ConcreteFactory2.new)
```

---

### 2. Builder
**Intent:** Construct complex objects step by step. Allows producing different types and representations using the same construction process.

**When to use:**
- Object construction requires many steps or configuration options
- You want to construct different representations using the same process
- Avoid a "telescoping constructor" with many optional parameters

**Rails use:** Building complex query objects, constructing API request payloads, test factories.

```ruby
class Director
  attr_writer :builder

  def build_minimal_viable_product
    @builder.produce_part_a
  end

  def build_full_featured_product
    @builder.produce_part_a
    @builder.produce_part_b
    @builder.produce_part_c
  end
end

class Builder
  def produce_part_a = raise NotImplementedError
  def produce_part_b = raise NotImplementedError
  def produce_part_c = raise NotImplementedError
end

class ConcreteBuilder1 < Builder
  def initialize = reset
  def reset = @product = Product1.new

  def produce_part_a = @product.add('PartA1')
  def produce_part_b = @product.add('PartB1')
  def produce_part_c = @product.add('PartC1')

  def product
    result = @product
    reset
    result
  end
end

class Product1
  def initialize = @parts = []
  def add(part) = @parts << part
  def list_parts = "Product parts: #{@parts.join(', ')}"
end

director = Director.new
builder = ConcreteBuilder1.new
director.builder = builder

director.build_minimal_viable_product
puts builder.product.list_parts

director.build_full_featured_product
puts builder.product.list_parts
```

---

### 3. Factory Method
**Intent:** Define an interface for creating an object, but let subclasses decide which class to instantiate.

**When to use:**
- A class cannot anticipate the type of objects it must create
- Subclasses should control the objects they create
- Encapsulate object creation logic to reduce coupling

**Rails use:** `ApplicationRecord` subclasses; service object factories; payment gateway adapters.

```ruby
class Creator
  def factory_method
    raise NotImplementedError, "#{self.class} must implement factory_method"
  end

  def some_operation
    product = factory_method
    "Creator: #{product.operation}"
  end
end

class ConcreteCreator1 < Creator
  def factory_method = ConcreteProduct1.new
end

class ConcreteCreator2 < Creator
  def factory_method = ConcreteProduct2.new
end

class Product
  def operation = raise NotImplementedError
end

class ConcreteProduct1 < Product
  def operation = '{Result of ConcreteProduct1}'
end

class ConcreteProduct2 < Product
  def operation = '{Result of ConcreteProduct2}'
end

def client_code(creator)
  puts "Client: #{creator.some_operation}"
end

client_code(ConcreteCreator1.new)
client_code(ConcreteCreator2.new)
```

---

### 4. Prototype
**Intent:** Copy existing objects without making code dependent on their classes. Clone objects including private fields.

**When to use:**
- Object initialization is expensive and you need many similar objects
- You want copies of objects without coupling to their concrete classes
- The number of classes you need is unknown at runtime

**Rails use:** Duplicating ActiveRecord objects with `dup`; cloning strategy configurations; prefilling forms from existing records.

```ruby
class Prototype
  attr_accessor :primitive, :component, :circular_reference

  def initialize
    @primitive = nil
    @component = nil
    @circular_reference = nil
  end

  def clone
    @component = deep_copy(@component)
    @circular_reference = deep_copy(@circular_reference)
    @circular_reference.prototype = self
    super
  end

  private

  def deep_copy(object)
    Marshal.load(Marshal.dump(object))
  end
end

class ComponentWithBackReference
  attr_accessor :prototype

  def initialize(prototype)
    @prototype = prototype
  end
end

prototype = Prototype.new
prototype.primitive = 245
prototype.component = Time.now
prototype.circular_reference = ComponentWithBackReference.new(prototype)

clone = prototype.clone

puts prototype.primitive == clone.primitive             # true
puts prototype.component.equal?(clone.component)       # false (deep copy)
puts clone.circular_reference.prototype.equal?(clone)  # true (back ref updated)
```

---

### 5. Singleton
**Intent:** Ensure a class has only one instance and provide global access to it.

**When to use:**
- Exactly one object needed to coordinate actions (config, connection pool, logger)
- Global access point required but with controlled instantiation

**Rails use:** Configuration objects, connection pools, feature flag registries. Note: in Rails, prefer dependency injection over Singleton for testability.

```ruby
require 'singleton'

class Logger
  include Singleton

  attr_reader :log

  def initialize
    @log = []
  end

  def add_log(msg)
    @log << msg
  end
end

# Usage
logger1 = Logger.instance
logger2 = Logger.instance
puts logger1.equal?(logger2)  # true — same instance

logger1.add_log('First message')
puts logger2.log              # ["First message"]

# Ruby also supports module-level Singleton via class methods:
module Config
  @settings = {}

  class << self
    def set(key, value) = @settings[key] = value
    def get(key) = @settings[key]
  end
end
```

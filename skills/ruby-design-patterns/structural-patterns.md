# Ruby Design Patterns — Structural (6–12)

Structural patterns explain how to assemble objects and classes into larger structures while keeping them flexible and efficient.

---

### 6. Adapter
**Intent:** Allow objects with incompatible interfaces to collaborate by wrapping one interface to match another.

**When to use:**
- You want to use an existing class but its interface doesn't match what you need
- Integrate third-party or legacy code without modifying it
- Create a reusable class that cooperates with classes that have incompatible interfaces

**Rails use:** Wrapping DhanHQ/Delta Exchange API clients behind a common broker interface; adapting third-party gems to your internal service interface.

```ruby
class Target
  def request = 'Target: default behavior'
end

class Adaptee
  def specific_request = '.eetpadA eht fo roivaheb laicepS'
end

class Adapter < Target
  def initialize(adaptee)
    @adaptee = adaptee
    super()
  end

  def request
    "Adapter: (TRANSLATED) #{@adaptee.specific_request.reverse}"
  end
end

def client_code(target)
  puts target.request
end

client_code(Target.new)
client_code(Adapter.new(Adaptee.new))
```

---

### 7. Bridge
**Intent:** Split a large class into two separate hierarchies (abstraction and implementation) that can be developed independently.

**When to use:**
- You want to divide a monolithic class with several variants
- Both abstraction and implementation should be extensible via subclassing
- Changes in implementation should not affect client code

**Rails use:** Separating report format (PDF, CSV, HTML) from report content (orders, positions, trades); separating notification channel from notification content.

```ruby
class Abstraction
  def initialize(implementation)
    @implementation = implementation
  end

  def operation
    "Abstraction: Base with:\n#{@implementation.operation_implementation}"
  end
end

class ExtendedAbstraction < Abstraction
  def operation
    "ExtendedAbstraction: Extended with:\n#{@implementation.operation_implementation}"
  end
end

class Implementation
  def operation_implementation = raise NotImplementedError
end

class ConcreteImplementationA < Implementation
  def operation_implementation = 'ConcreteImplementationA: result'
end

class ConcreteImplementationB < Implementation
  def operation_implementation = 'ConcreteImplementationB: result'
end

def client_code(abstraction)
  puts abstraction.operation
end

client_code(Abstraction.new(ConcreteImplementationA.new))
client_code(ExtendedAbstraction.new(ConcreteImplementationB.new))
```

---

### 8. Composite
**Intent:** Compose objects into tree structures and work with them as if they were individual objects.

**When to use:**
- You need to implement a tree-like object structure
- You want client code to treat simple and complex elements uniformly

**Rails use:** Menu/navigation trees; category hierarchies; building composite trading rules (e.g. AND/OR conditions for strategy entry).

```ruby
class Component
  attr_accessor :parent

  def add(component) = raise NotImplementedError
  def remove(component) = raise NotImplementedError
  def composite? = false
  def operation = raise NotImplementedError
end

class Leaf < Component
  def operation = 'Leaf'
end

class Composite < Component
  def initialize = @children = []

  def add(component)
    @children << component
    component.parent = self
  end

  def remove(component)
    @children.delete(component)
    component.parent = nil
  end

  def composite? = true

  def operation
    results = @children.map(&:operation)
    "Branch(#{results.join('+')})"
  end
end

def client_code(component)
  puts "Result: #{component.operation}"
end

tree = Composite.new
branch1 = Composite.new
branch1.add(Leaf.new)
branch1.add(Leaf.new)
branch2 = Composite.new
branch2.add(Leaf.new)
tree.add(branch1)
tree.add(branch2)

client_code(tree)
client_code(Leaf.new)
```

---

### 9. Decorator
**Intent:** Attach new behaviors to objects by wrapping them in decorator objects. Flexible alternative to subclassing.

**When to use:**
- Add responsibilities to individual objects without affecting others
- Responsibilities can be withdrawn
- Extension by subclassing is impractical

**Rails use:** Draper decorators for view logic; wrapping service objects with logging, caching, or retry behavior; middleware chains.

```ruby
class Component
  def operation = raise NotImplementedError
end

class ConcreteComponent < Component
  def operation = 'ConcreteComponent'
end

class Decorator < Component
  def initialize(component)
    @component = component
  end

  def operation = @component.operation
end

class ConcreteDecoratorA < Decorator
  def operation = "ConcreteDecoratorA(#{@component.operation})"
end

class ConcreteDecoratorB < Decorator
  def operation = "ConcreteDecoratorB(#{@component.operation})"
end

def client_code(component)
  puts "Result: #{component.operation}"
end

simple = ConcreteComponent.new
client_code(simple)

decorator1 = ConcreteDecoratorA.new(simple)
decorator2 = ConcreteDecoratorB.new(decorator1)
client_code(decorator2)
# Result: ConcreteDecoratorB(ConcreteDecoratorA(ConcreteComponent))
```

---

### 10. Facade
**Intent:** Provide a simplified interface to a complex subsystem (library, framework, or set of classes).

**When to use:**
- You need a simple interface to a complex subsystem
- Decouple clients from subsystem internals
- Layer your subsystem — facades define entry points to each layer

**Rails use:** Service objects that wrap multiple API calls; `ApplicationRecord` is a facade over ActiveRecord internals; wrapping complex broker SDK interactions.

```ruby
class Facade
  def initialize(subsystem1 = nil, subsystem2 = nil)
    @subsystem1 = subsystem1 || Subsystem1.new
    @subsystem2 = subsystem2 || Subsystem2.new
  end

  def operation
    results = ['Facade initializes subsystems:']
    results << @subsystem1.operation1
    results << @subsystem2.operation1
    results << 'Facade orders subsystems to perform the action:'
    results << @subsystem1.operation_n
    results << @subsystem2.operation_z
    results.join("\n")
  end
end

class Subsystem1
  def operation1 = 'Subsystem1: Ready!'
  def operation_n = 'Subsystem1: Go!'
end

class Subsystem2
  def operation1 = 'Subsystem2: Get ready!'
  def operation_z = 'Subsystem2: Fire!'
end

def client_code(facade)
  puts facade.operation
end

client_code(Facade.new)
```

---

### 11. Flyweight
**Intent:** Fit more objects into RAM by sharing common state (intrinsic) between multiple objects instead of storing it in each.

**When to use:**
- Program must support a huge number of objects that barely fit into RAM
- Objects contain duplicate state that can be extracted and shared
- Many groups of objects can be replaced by few shared objects once extrinsic state is removed

**Rails use:** Caching shared market instrument data (tick size, lot size, exchange segment) across thousands of order objects; sharing static config across request objects.

```ruby
class Flyweight
  def initialize(shared_state)
    @shared_state = shared_state
  end

  def operation(unique_state)
    s = @shared_state.join(', ')
    u = unique_state.join(', ')
    puts "Flyweight: Displaying shared (#{s}) and unique (#{u}) state."
  end
end

class FlyweightFactory
  def initialize(initial_flyweights)
    @flyweights = {}
    initial_flyweights.each do |state|
      @flyweights[get_key(state)] = Flyweight.new(state)
    end
  end

  def get_flyweight(shared_state)
    key = get_key(shared_state)
    unless @flyweights.key?(key)
      puts 'FlyweightFactory: Creating new flyweight.'
      @flyweights[key] = Flyweight.new(shared_state)
    end
    @flyweights[key]
  end

  def list_flyweights
    puts "FlyweightFactory: #{@flyweights.size} flyweights"
    puts @flyweights.keys.join("\n")
  end

  private

  def get_key(state) = state.join('_')
end

factory = FlyweightFactory.new([
  %w[Chevrolet Camaro2018 pink],
  %w[Mercedes C300 black],
  %w[Mercedes C500 red]
])

factory.list_flyweights

def add_car_to_police_database(factory, plates, owner, brand, model, color)
  flyweight = factory.get_flyweight([brand, model, color])
  flyweight.operation([plates, owner])
end

add_car_to_police_database(factory, 'CL234IR', 'James', 'BMW', 'M5', 'red')
add_car_to_police_database(factory, 'CL234IR', 'James', 'BMW', 'X1', 'red')
```

---

### 12. Proxy
**Intent:** Provide a substitute/placeholder for another object to control access to it.

**When to use:**
- Lazy initialization (virtual proxy) — defer expensive object creation until needed
- Access control (protection proxy) — only certain clients can use the service
- Logging, caching, or monitoring (smart reference proxy)
- Remote proxy — local representative for a remote service

**Rails use:** Lazy-loading associations in ActiveRecord; caching proxy for expensive API calls; authorization checks before service object execution.

```ruby
class Subject
  def request = raise NotImplementedError
end

class RealSubject < Subject
  def request = puts 'RealSubject: Handling request.'
end

class Proxy < Subject
  def initialize(real_subject)
    @real_subject = real_subject
  end

  def request
    if check_access
      @real_subject.request
      log_access
    end
  end

  private

  def check_access
    puts 'Proxy: Checking access prior to firing a real request.'
    true
  end

  def log_access = puts 'Proxy: Logging the time of request.'
end

def client_code(subject)
  subject.request
end

client_code(RealSubject.new)
puts '---'
client_code(Proxy.new(RealSubject.new))
```

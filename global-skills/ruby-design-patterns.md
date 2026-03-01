---
name: ruby-design-patterns
description: All 23 GoF design patterns with Ruby implementations from refactoring.guru. Use when designing or refactoring Ruby/Rails code and you need to apply or recognize a design pattern. Covers Creational (5), Structural (7), and Behavioral (11) patterns with Ruby code examples and Rails-specific applications.
---

# Ruby Design Patterns — Complete Reference

Source: https://refactoring.guru/design-patterns/ruby

> Don't force patterns. Let them emerge from refactoring. Apply when you recognize the problem, not speculatively.

---

## CREATIONAL PATTERNS

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

---

## STRUCTURAL PATTERNS

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

---

## BEHAVIORAL PATTERNS

Behavioral patterns are concerned with algorithms and the assignment of responsibilities between objects.

---

### 13. Chain of Responsibility
**Intent:** Pass requests along a chain of handlers. Each handler decides to process the request or pass it to the next handler.

**When to use:**
- More than one object may handle a request, and the handler isn't known a priori
- You want to issue a request to one of several objects without specifying the receiver explicitly
- The set of objects that can handle a request should be specified dynamically

**Rails use:** Middleware stack; before_action filter chains; trading signal validation pipelines (regime check → entry check → risk check → execution).

```ruby
class Handler
  attr_writer :next_handler

  def next_handler(handler)
    @next_handler = handler
    handler  # return handler to allow chaining
  end

  def handle(request)
    @next_handler&.handle(request)
  end
end

class MonkeyHandler < Handler
  def handle(request)
    if request == 'Banana'
      puts "Monkey: I'll eat the #{request}"
    else
      super
    end
  end
end

class SquirrelHandler < Handler
  def handle(request)
    if request == 'Nut'
      puts "Squirrel: I'll eat the #{request}"
    else
      super
    end
  end
end

class DogHandler < Handler
  def handle(request)
    if request == 'MeatBall'
      puts "Dog: I'll eat the #{request}"
    else
      super
    end
  end
end

monkey = MonkeyHandler.new
squirrel = SquirrelHandler.new
dog = DogHandler.new
monkey.next_handler(squirrel).next_handler(dog)

%w[Nut Banana Cup MeatBall].each do |food|
  print "Client: Who wants a #{food}? "
  result = monkey.handle(food)
  puts "#{food} was left untouched." unless result
end
```

---

### 14. Command
**Intent:** Turn a request into a stand-alone object that contains all information about the request. Enables queuing, logging, and undoable operations.

**When to use:**
- Parameterize objects with operations
- Queue, schedule, or execute operations remotely
- Implement reversible (undoable) operations

**Rails use:** Background job objects (Sidekiq jobs are Commands); order placement commands with undo/cancel; audit log of actions.

```ruby
class Command
  def execute = raise NotImplementedError
end

class SimpleCommand < Command
  def initialize(payload)
    @payload = payload
  end

  def execute = puts "SimpleCommand: #{@payload}"
end

class ComplexCommand < Command
  def initialize(receiver, a, b)
    @receiver = receiver
    @a = a
    @b = b
  end

  def execute
    print 'ComplexCommand: delegating to Receiver. '
    @receiver.do_something(@a)
    @receiver.do_something_else(@b)
  end
end

class Receiver
  def do_something(a) = print "Receiver: working on (#{a}). "
  def do_something_else(b) = puts "Receiver: also working on (#{b})."
end

class Invoker
  def on_start=(command) = @on_start = command
  def on_finish=(command) = @on_finish = command

  def do_something_important
    @on_start&.execute
    puts 'Invoker: doing something important'
    @on_finish&.execute
  end
end

invoker = Invoker.new
invoker.on_start = SimpleCommand.new('Say Hi!')
receiver = Receiver.new
invoker.on_finish = ComplexCommand.new(receiver, 'Send email', 'Save report')
invoker.do_something_important
```

---

### 15. Iterator
**Intent:** Traverse elements of a collection without exposing its underlying representation.

**When to use:**
- You want a standard way to traverse different collection types
- Reduce duplication of traversal code across the app
- Allow multiple simultaneous traversals of a collection

**Rails use:** Custom `each`/`Enumerable` on domain collections; iterating through trade history with filtering; paginated API result iterators. Ruby's `Enumerable` module implements this natively.

```ruby
class WordsCollection
  include Comparable

  def initialize = @collection = []

  def collection = @collection

  def add_item(item) = @collection << item

  # Forward iterator
  def each(&block) = @collection.each(&block)

  # Reverse iterator
  def each_reversed(&block) = @collection.reverse_each(&block)

  # Ruby Enumerable gives you map, select, find, etc. for free
  include Enumerable
  def each_with_index_reversed
    @collection.reverse_each.with_index
  end
end

collection = WordsCollection.new
collection.add_item('First')
collection.add_item('Second')
collection.add_item('Third')

puts 'Straight traversal:'
collection.each { |item| puts item }

puts 'Reverse traversal:'
collection.each_reversed { |item| puts item }

# With Enumerable:
puts collection.map(&:upcase).inspect
puts collection.select { |w| w.length > 5 }.inspect
```

---

### 16. Mediator
**Intent:** Reduce chaotic dependencies between objects by making them communicate only via a mediator object.

**When to use:**
- Many objects communicate in complex ways, causing tight coupling
- A component can't be reused because it's coupled to others
- You're creating a lot of subclasses to customize behavior across related components

**Rails use:** Event bus / pub-sub systems; coordinating between multiple trading subsystems (feed → strategy → risk → execution) without direct coupling.

```ruby
class Mediator
  def notify(sender, event) = raise NotImplementedError
end

class ConcreteMediator < Mediator
  def initialize(component1, component2)
    @component1 = component1
    @component1.mediator = self
    @component2 = component2
    @component2.mediator = self
  end

  def notify(sender, event)
    if event == 'A'
      puts 'Mediator reacts on A and triggers B:'
      @component2.do_b
    elsif event == 'D'
      puts 'Mediator reacts on D and triggers B and C:'
      @component1.do_b
      @component2.do_c
    end
  end
end

class BaseComponent
  attr_accessor :mediator

  def initialize(mediator = nil)
    @mediator = mediator
  end
end

class Component1 < BaseComponent
  def do_a
    puts 'Component 1 does A.'
    @mediator&.notify(self, 'A')
  end

  def do_b = puts 'Component 1 does B.'
end

class Component2 < BaseComponent
  def do_c = puts 'Component 2 does C.'

  def do_d
    puts 'Component 2 does D.'
    @mediator&.notify(self, 'D')
  end
end

c1 = Component1.new
c2 = Component2.new
ConcreteMediator.new(c1, c2)

puts 'Client triggers operation A:'
c1.do_a

puts "\nClient triggers operation D:"
c2.do_d
```

---

### 17. Memento
**Intent:** Save and restore previous state of an object without revealing the details of its implementation.

**When to use:**
- You need to produce snapshots of an object's state to be able to restore a previous state
- Direct access to object's fields/getters/setters violates encapsulation

**Rails use:** Undo/redo for strategy configuration; snapshotting order state before modification; versioning position records.

```ruby
class Originator
  attr_writer :state

  def initialize(state)
    @state = state
    puts "Originator: initial state: #{@state}"
  end

  def do_something
    puts 'Originator: doing something important.'
    @state = generate_random_string(30)
    puts "Originator: state changed to: #{@state}"
  end

  def save = ConcreteMemento.new(@state)

  def restore(memento)
    @state = memento.state
    puts "Originator: state restored to: #{@state}"
  end

  private

  def generate_random_string(length = 10)
    (('a'..'z').to_a + ('A'..'Z').to_a).sample(length).join
  end
end

class ConcreteMemento
  attr_reader :state, :date

  def initialize(state)
    @state = state
    @date = Time.now.strftime('%F %T')
  end

  def name = "#{@date} / #{@state[0, 9]}..."
end

class Caretaker
  def initialize(originator)
    @mementos = []
    @originator = originator
  end

  def backup
    puts "\nCaretaker: saving state..."
    @mementos << @originator.save
  end

  def undo
    return puts 'Caretaker: no mementos.' if @mementos.empty?
    memento = @mementos.pop
    puts "Caretaker: restoring to: #{memento.name}"
    @originator.restore(memento)
  end

  def show_history = @mementos.each { |m| puts m.name }
end

originator = Originator.new('Super-duper-super-puper-super.')
caretaker = Caretaker.new(originator)

caretaker.backup
originator.do_something
caretaker.backup
originator.do_something
caretaker.undo
caretaker.undo
```

---

### 18. Observer
**Intent:** Define a subscription mechanism so multiple objects are notified of events in the object they're observing.

**When to use:**
- Changes to one object require updating others, and you don't know how many
- An object should notify other objects without making assumptions about who they are

**Rails use:** ActiveSupport::Notifications; after_commit callbacks; market data feed distributing ticks to multiple strategy listeners; `ActiveRecord::Callbacks` are observer-like.

```ruby
class EventManager
  def initialize(*operations)
    @listeners = operations.each_with_object({}) { |op, h| h[op] = [] }
  end

  def subscribe(event_type, listener)
    @listeners[event_type] << listener
  end

  def unsubscribe(event_type, listener)
    @listeners[event_type].delete(listener)
  end

  def notify(event_type, data)
    @listeners[event_type]&.each { |listener| listener.update(event_type, data) }
  end
end

class Publisher
  attr_reader :events

  def initialize
    @events = EventManager.new(:open, :close, :tick)
  end

  def open_file(path)
    puts "Publisher: opened #{path}"
    @events.notify(:open, path)
  end

  def close_file(path)
    puts "Publisher: closed #{path}"
    @events.notify(:close, path)
  end
end

module Listener
  def update(event_type, data) = raise NotImplementedError
end

class LoggingListener
  include Listener

  def initialize(log, message)
    @log = log
    @message = message
  end

  def update(event_type, data)
    puts "#{@message}: #{data} (event: #{event_type})"
  end
end

publisher = Publisher.new
logger1 = LoggingListener.new('/path/to/log', 'Log: file opened')
logger2 = LoggingListener.new('/path/to/log', 'Log: file closed')

publisher.events.subscribe(:open, logger1)
publisher.events.subscribe(:close, logger2)

publisher.open_file('test.txt')
publisher.close_file('test.txt')
```

---

### 19. State
**Intent:** Let an object alter its behavior when its internal state changes. The object will appear to change its class.

**When to use:**
- Object behavior depends on its state and must change at runtime
- Operations have large multipart conditionals that depend on object state

**Rails use:** Order state machines (`pending → submitted → filled → cancelled`); AASM/state_machine gems implement this; trade lifecycle management.

```ruby
class Context
  attr_accessor :state

  def initialize(state)
    transition_to(state)
  end

  def transition_to(state)
    puts "Context: transitioning to #{state.class}"
    @state = state
    @state.context = self
  end

  def request1 = @state.handle1
  def request2 = @state.handle2
end

class State
  attr_writer :context

  def handle1 = raise NotImplementedError
  def handle2 = raise NotImplementedError
end

class ConcreteStateA < State
  def handle1
    puts 'ConcreteStateA handles request1, switching to B.'
    @context.transition_to(ConcreteStateB.new)
  end

  def handle2 = puts 'ConcreteStateA handles request2.'
end

class ConcreteStateB < State
  def handle1 = puts 'ConcreteStateB handles request1.'

  def handle2
    puts 'ConcreteStateB handles request2, switching back to A.'
    @context.transition_to(ConcreteStateA.new)
  end
end

context = Context.new(ConcreteStateA.new)
context.request1
context.request2
context.request1
context.request2
```

---

### 20. Strategy
**Intent:** Define a family of algorithms, encapsulate each one, and make them interchangeable. Let the algorithm vary independently from the clients that use it.

**When to use:**
- You want to swap algorithms used inside an object at runtime
- You have many similar classes that differ only in execution behavior
- Isolate business logic from implementation details

**Rails use:** Sorting/filtering strategies; payment processing strategies; trading entry strategies (momentum vs mean-reversion vs breakout); broker routing strategies.

```ruby
class Context
  attr_writer :strategy

  def initialize(strategy)
    @strategy = strategy
  end

  def do_some_business_logic
    puts 'Context: sorting data using strategy'
    result = @strategy.do_algorithm(%w[a b c d e])
    puts result.join(',')
  end
end

class Strategy
  def do_algorithm(data) = raise NotImplementedError
end

class ConcreteStrategyA < Strategy
  def do_algorithm(data) = data.sort
end

class ConcreteStrategyB < Strategy
  def do_algorithm(data) = data.sort.reverse
end

context = Context.new(ConcreteStrategyA.new)
puts 'Client: normal sorting strategy'
context.do_some_business_logic

puts "\nClient: reverse sorting strategy"
context.strategy = ConcreteStrategyB.new
context.do_some_business_logic
```

---

### 21. Template Method
**Intent:** Define the skeleton of an algorithm in the superclass, deferring some steps to subclasses without changing the algorithm's structure.

**When to use:**
- You want clients to extend only specific steps of an algorithm, not its structure
- Several classes with almost identical algorithms that differ in minor steps

**Rails use:** `ApplicationController` before/after action hooks; base service objects with `call` template; base strategy classes with hook methods for entry/exit logic.

```ruby
class AbstractClass
  def template_method
    base_operation1
    required_operation1
    base_operation2
    hook1
    required_operation2
    base_operation3
    hook2
  end

  def base_operation1 = puts 'AbstractClass: base_operation1'
  def base_operation2 = puts 'AbstractClass: base_operation2'
  def base_operation3 = puts 'AbstractClass: base_operation3'

  def required_operation1 = raise NotImplementedError
  def required_operation2 = raise NotImplementedError

  # Hooks — optional, subclasses may override
  def hook1; end
  def hook2; end
end

class ConcreteClass1 < AbstractClass
  def required_operation1 = puts 'ConcreteClass1: required_operation1'
  def required_operation2 = puts 'ConcreteClass1: required_operation2'
end

class ConcreteClass2 < AbstractClass
  def required_operation1 = puts 'ConcreteClass2: required_operation1'
  def required_operation2 = puts 'ConcreteClass2: required_operation2'
  def hook1 = puts 'ConcreteClass2: overridden hook1'
end

def client_code(abstract_class)
  abstract_class.template_method
end

client_code(ConcreteClass1.new)
puts '---'
client_code(ConcreteClass2.new)
```

---

### 22. Visitor
**Intent:** Separate algorithms from the objects on which they operate. Add new operations to existing classes without modifying them.

**When to use:**
- You need to perform many distinct and unrelated operations on an object structure without polluting their classes
- Object structure classes rarely change but you often add new operations
- An operation needs to work across objects of different classes

**Rails use:** Exporting trade data in multiple formats (JSON, CSV, XML) without adding export methods to models; calculating different metrics across a portfolio of positions.

```ruby
class Component
  def accept(visitor) = raise NotImplementedError
end

class ConcreteComponentA < Component
  def accept(visitor) = visitor.visit_concrete_component_a(self)
  def exclusive_method_of_concrete_component_a = 'a'
end

class ConcreteComponentB < Component
  def accept(visitor) = visitor.visit_concrete_component_b(self)
  def special_method_of_concrete_component_b = 'b'
end

class Visitor
  def visit_concrete_component_a(element) = raise NotImplementedError
  def visit_concrete_component_b(element) = raise NotImplementedError
end

class ConcreteVisitor1 < Visitor
  def visit_concrete_component_a(element)
    puts "#{element.exclusive_method_of_concrete_component_a} + ConcreteVisitor1"
  end

  def visit_concrete_component_b(element)
    puts "#{element.special_method_of_concrete_component_b} + ConcreteVisitor1"
  end
end

class ConcreteVisitor2 < Visitor
  def visit_concrete_component_a(element)
    puts "#{element.exclusive_method_of_concrete_component_a} + ConcreteVisitor2"
  end

  def visit_concrete_component_b(element)
    puts "#{element.special_method_of_concrete_component_b} + ConcreteVisitor2"
  end
end

def client_code(components, visitor)
  components.each { |c| c.accept(visitor) }
end

components = [ConcreteComponentA.new, ConcreteComponentB.new]
visitor1 = ConcreteVisitor1.new
client_code(components, visitor1)

visitor2 = ConcreteVisitor2.new
client_code(components, visitor2)
```

---

## Quick Reference

### By Problem

| Problem | Pattern |
|---|---|
| Creating families of compatible objects | Abstract Factory |
| Building complex objects step by step | Builder |
| Subclass decides which object to create | Factory Method |
| Clone objects without coupling to class | Prototype |
| One instance globally | Singleton |
| Incompatible interfaces must work together | Adapter |
| Split abstraction from implementation | Bridge |
| Tree structures, treat parts and wholes uniformly | Composite |
| Add behavior without subclassing | Decorator |
| Simplify a complex subsystem | Facade |
| Share common state across many objects | Flyweight |
| Control access to an object | Proxy |
| Pass request through a handler chain | Chain of Responsibility |
| Encapsulate a request as an object | Command |
| Traverse a collection without exposing it | Iterator |
| Decouple communicating objects | Mediator |
| Save and restore object state | Memento |
| Notify many objects about events | Observer |
| Alter behavior when state changes | State |
| Swap algorithms at runtime | Strategy |
| Define algorithm skeleton, defer steps | Template Method |
| Add operations without modifying classes | Visitor |

### Ruby-native pattern support

| Pattern | Ruby built-in |
|---|---|
| Iterator | `Enumerable`, `Enumerator` |
| Observer | `Observable` module (stdlib) |
| Singleton | `Singleton` module (stdlib) |
| Decorator | Modules + `prepend` / `extend` |
| Strategy | Blocks / Procs / lambdas |
| Template Method | Inheritance + hook methods |
| Command | Proc / Method objects |

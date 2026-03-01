# Ruby Design Patterns — Behavioral (13–22)

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

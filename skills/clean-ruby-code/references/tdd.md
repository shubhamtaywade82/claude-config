# Test-Driven Development — Clean Ruby

## The TDD Cycle

1. **Red** — Write a failing test that describes the desired behavior
2. **Green** — Write the minimum code to make the test pass
3. **Refactor** — Clean up both production and test code, keeping tests green

Only write code required to make the current test pass. This prevents speculative code and ensures 100% test coverage by construction.

## RSpec Structure

### Describe / Context / It

```ruby
RSpec.describe Calculator do
  context '#add' do
    it 'returns the sum of two positive integers' do
      expected = 4
      actual = subject.add(2, 2)
      expect(actual).to eq(expected)
    end

    it 'returns 0 when both values are nil' do
      expected = 0
      actual = subject.add(nil, nil)
      expect(actual).to eq(expected)
    end
  end

  context '#subtract' do
    it 'returns the difference of two values' do
      expected = 3
      actual = subject.subtract(5, 2)
      expect(actual).to eq(expected)
    end
  end
end
```

### Rules
- `describe` wraps the class under test
- `context` groups tests for a specific method or scenario (prefix method name with `#` for instance, `.` for class methods)
- `it` describes the expected behavior in plain English: "returns X when Y"
- Separate `expected` and `actual` variables for readability — don't inline both into `expect`

## Use RSpec Helpers

### `subject`
Implicit instance of the described class. Use it instead of creating instances manually.

### `let` / `let!`
Lazy (or eager) setup for test data. Avoids repetition across `it` blocks.

```ruby
RSpec.describe License do
  let(:user) { build(:user, trial_end_date: Date.yesterday) }
  subject { described_class.new(user) }

  context '#trial?' do
    it 'returns true when trial has expired' do
      expect(subject.trial?).to be true
    end
  end
end
```

### `before`
Shared setup that applies to all tests in a context.

```ruby
context 'when user is inactive' do
  before { user.update(last_login: 7.months.ago) }

  it 'includes user in inactive query' do
    expect(InActiveUserQuery.new.all).to include(user)
  end
end
```

## What to Test

### Happy Path
The expected, normal-use scenario. Always test this first.

### Nil / Empty Input
What happens when a parameter is nil, an empty string, an empty array? Decide the behavior, then test it.

```ruby
it 'returns 0 when both values are nil' do
  expect(subject.add(nil, nil)).to eq(0)
end
```

### Edge Cases
- Boundary values (0, -1, MAX_INT)
- Single-element collections
- Duplicate entries
- Unicode / special characters in strings

### Error Conditions
- Invalid input types
- Missing required parameters
- External service failures (use mocks/stubs)

```ruby
context 'when external service is unavailable' do
  before { allow(ExternalApi).to receive(:fetch).and_raise(Timeout::Error) }

  it 'raises a ServiceUnavailableError' do
    expect { subject.sync }.to raise_error(ServiceUnavailableError)
  end
end
```

## Clean Test Code

Tests are production code. Apply the same naming, structure, and readability standards.

### Bad Test
```ruby
it "returns added value" do
  c = Calculator.new
  expect(c.add(2, 2)).to eq(4)
end
```

Problems:
- Vague description
- Single-letter variable
- Inlined expected value — unclear what 4 represents
- Not using `subject`

### Good Test
```ruby
context '#add' do
  it 'returns the sum of two positive integers' do
    expected = 4
    actual = subject.add(2, 2)
    expect(actual).to eq(expected)
  end
end
```

Improvements:
- Context scopes to the method
- Description states the specific behavior
- Expected/actual separated for clarity
- Uses implicit `subject`

## Testing Anti-Patterns to Avoid

| Anti-Pattern | Fix |
|---|---|
| Test depends on execution order | Use `let` / `before` for isolated setup |
| Test hits real database/API | Use factories, mocks, stubs |
| Multiple assertions testing different behaviors | One `it` block per behavior |
| Shared mutable state between tests | Use `let` (lazy) not instance variables |
| Testing private methods directly | Test through public interface |
| Brittle string matching | Use `include`, `match`, or structured matchers |
| No test for the sad path | Always test error/nil/edge cases |

## Test Organization

```
spec/
├── models/
│   └── user_spec.rb
├── services/
│   └── order_processor_spec.rb
├── queries/
│   └── active_subscriber_query_spec.rb
├── lib/
│   └── calculable_spec.rb
└── support/
    ├── factories/
    └── shared_examples/
```

Mirror the app directory structure. One spec file per class. Shared behaviors go in `shared_examples`.

---
name: rspec-generator
description: Generate RSpec test coverage for trading workspace code. Covers happy path, edge cases, state transitions, risk determinism, and handler idempotency.
disable-model-invocation: true
argument-hint: [file-or-directory]
allowed-tools: Read, Glob, Grep, Write
---

# Skill: RSpec Generator

Generate RSpec test coverage for trading workspace code.

## Rules

- Use `described_class` not hardcoded class names
- Use `let` blocks for shared setup
- Test happy path, edge cases, and error conditions
- For order execution: test each state transition separately
- For risk logic: test determinism (same input = same output)
- For feed handlers: test idempotency

## Output

- Complete spec file at `spec/<path>/<file>_spec.rb`
- Factory stubs if ActiveRecord models are involved
- Coverage of at minimum: success path, invalid input, boundary conditions

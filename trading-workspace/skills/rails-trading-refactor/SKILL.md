---
name: rails-trading-refactor
description: Review trading workspace Rails code for architecture violations and refactor accordingly. Enforces service objects, broker abstraction, pure risk functions, and idempotent event handlers.
disable-model-invocation: true
argument-hint: [file-or-directory]
allowed-tools: Read, Glob, Grep, Edit, Write
---

# Skill: Rails Trading Refactor

Review the target code for trading workspace architecture violations and refactor accordingly.

## Rules

1. No business logic in controllers — extract to service objects
2. Order execution must log every state transition
3. Strategy logic must remain broker-agnostic — no raw DhanHQ calls outside `dhanhq-client`
4. Risk calculations must be pure functions (no side effects, no DB writes)
5. WebSocket event handlers must be idempotent

## Output

- Refactored code with service objects
- List of violations found and how each was resolved
- RSpec test stubs for each new service object

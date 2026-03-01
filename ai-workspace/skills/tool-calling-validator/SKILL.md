---
name: tool-calling-validator
description: Validate agent tool call definitions and runtime behavior for correctness. Checks JSON Schema validity, required fields, output shape, hallucinated fields, name uniqueness, and side-effect safety.
disable-model-invocation: true
argument-hint: [file-or-directory]
allowed-tools: Read, Glob, Grep
---

# Skill: Tool Calling Validator

Validate agent tool call definitions and runtime behavior for correctness.

## Checks

1. Tool schema must be valid JSON Schema (draft-07 or later)
2. Required fields must be present in all example calls
3. Tool output shape must match what the agent expects to consume
4. No hallucinated field names — every field in a call must exist in the schema
5. Tool names must be unique within an agent's tool registry
6. Side-effecting tools must have `confirmation_required: true` if destructive

## Output

- Schema validation result per tool
- List of hallucinated or mismatched fields
- Verdict: VALID / INVALID with specific errors

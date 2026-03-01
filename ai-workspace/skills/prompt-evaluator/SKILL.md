---
name: prompt-evaluator
description: Evaluate agent prompts and system instructions for quality and safety. Scores clarity, scope, tool grounding, hallucination risk, determinism, and safety. Returns PRODUCTION READY / NEEDS REVISION / UNSAFE.
disable-model-invocation: true
argument-hint: [prompt-text-or-file]
---

# Skill: Prompt Evaluator

Evaluate agent prompts and system instructions for quality and safety.

## Evaluation Criteria

1. **Clarity** — Is the task unambiguous? Could the model interpret it multiple ways?
2. **Scope** — Is the scope bounded? Open-ended prompts cause drift.
3. **Tool grounding** — Are tool calls grounded in schema, not assumed?
4. **Hallucination risk** — Does the prompt invite fabrication (e.g., "list all X")?
5. **Determinism** — Given the same prompt + seed, will output be stable?
6. **Safety** — Does the prompt guard against harmful completions?

## Output

- Score per criterion (1-5)
- Overall verdict: PRODUCTION READY / NEEDS REVISION / UNSAFE
- Specific rewrites for failing sections

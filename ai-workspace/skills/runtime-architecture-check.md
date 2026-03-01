# Skill: Runtime Architecture Check

Review agent runtime code for architectural violations and separation of concerns.

## Rules

1. Inference layer (`ollama-client`) must not contain orchestration logic
2. Orchestration layer (`agent-orchestrator`) must not call inference directly — go through `agent-runtime`
3. `ares` is the reference framework — custom agents must extend it, not reimplement primitives
4. No hardcoded model names — all model references must be runtime configuration
5. Agent state must be serializable (no closures or open file handles in state)
6. Skills must be stateless — they take input, return output, no globals

## Output

- List of layer boundary violations with file:line
- Dependency graph of actual vs intended architecture
- Verdict: CLEAN / VIOLATIONS FOUND

# AI Workspace

This workspace contains all AI infrastructure — model runtimes, agent orchestration, tool calling, prompt engineering, and UI layers.

## Repos

| Repo | Role |
|---|---|
| `ollama-client` | Client SDK for Ollama model inference |
| `ollama-agent-examples` | Reference agent implementations |
| `ollama_ui` | UI frontend for Ollama interactions |
| `agent-runtime` | Core agent execution runtime |
| `agent_runtime` | Agent runtime (alternate implementation) |
| `agent-orchestrator` | Multi-agent coordination layer |
| `ares` | Primary agent framework |
| `ai_playground` | Experimental AI features |
| `coding-agent` | Specialized coding agent |
| `devagent-ui` | Developer agent UI |
| `omni_pulse` | Unified agent pulse/monitoring |
| `ta-agent` | Technical analysis agent |
| `open-webui` | Docker deployment bundle for Open WebUI fronting Ollama |
| `repocontext` | Sinatra app — codebase Q&A and agentic code reviewer via Ollama |
| `solid-skills` | Agent skills library — SOLID, TDD, clean code for AI coding agents |

## Principles

- Agent execution must be deterministic given the same input + seed
- Tool calls must be validated before execution — no hallucinated tool output
- No side effects from prompt evaluation — inference is read-only
- Modular skill architecture — skills are composable, not monolithic
- All agent actions must be loggable and replayable

## Architecture Rules

- Strict separation: inference layer ↔ orchestration layer ↔ UI layer
- Tool calling schemas must be versioned
- `ares` is the reference agent framework — other agents should extend or wrap it
- `agent-runtime` owns execution lifecycle; orchestration lives in `agent-orchestrator`
- No hardcoded model names — model selection is runtime configuration

## Cross-Repo Dependencies

```
ollama-client       →  agent-runtime
ollama-client       →  ares
agent-runtime       →  agent-orchestrator
ares                →  coding-agent / ta-agent
agent-orchestrator  →  devagent-ui / omni_pulse
```

## Running Context

- Primary languages: Ruby, Python, TypeScript
- Inference backend: Ollama (local), Claude API (remote)
- Agent framework: ares
- Tool calling: JSON schema validated

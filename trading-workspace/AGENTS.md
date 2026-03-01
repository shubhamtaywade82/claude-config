# Trading Workspace

This workspace contains all trading infrastructure — split across two distinct market domains with **strictly separate broker APIs**.

---

## ⚠️ Critical API Boundary

| Domain | Exchange | Broker API | Active repos |
|---|---|---|---|
| Indian Markets (NSE/BSE) | NSE, BSE | **DhanHQ v2 API only** | `dhanhq-client`, `dhanhq-mcp`, `algo_trading_api`, `algo_scalper_api`, `dhan_trader_bot`, `market-data-service`, `swing_long_trader`, `vyapari` |
| Crypto | Delta Exchange India | **Delta Exchange API only** | `crypto_bot_api` (+ `ares` in ai-workspace) |

**NEVER cross these boundaries:**
- Indian market repos must NOT reference Delta Exchange APIs
- Crypto repos must NOT reference DhanHQ APIs
- No shared order execution layer between domains
- No shared position tracking between domains

**Intentional exceptions (cross-domain allowed):**
- `trading_playground` — cross-broker strategy research, both APIs permitted
- `pinescript-agents` — broker-agnostic authoring tool, both APIs permitted

Risk models and utility logic may be shared only if they are **fully broker-agnostic** (pure math, no API calls).

---

## Active Repos

### Indian Markets — DhanHQ v2

| Repo | Role |
|---|---|
| `dhanhq-client` | **Canonical DhanHQ v2 gem** — all repos use this |
| `dhanhq-mcp` | MCP server with order execution tools (Ruby gem, HTTP + stdio) |
| `dhan_mcp_server` | MCP server, read-only (Python, Claude Desktop) |
| `algo_trading_api` | **Primary signal/webhook API** — TradingView alerts, options signals, swing picks |
| `algo_scalper_api` | **Primary live scalper** — WebSocket feed, SMC entry engine, risk, exit engine |
| `dhan_trader_bot` | Strategy pattern bot (gem/CLI, Strategy/Factory/Observer/Builder) |
| `market-data-service` | Read-only market data aggregation (Python FastAPI) |
| `swing_long_trader` | Swing/long-term equity system with SMC, backtesting, Telegram |
| `vyapari` | AI options trading agent — Ollama LLM + DhanHQ |

### Crypto — Delta Exchange India

| Repo | Role |
|---|---|
| `crypto_bot_api` | Rails API layer for crypto trading |
| `ares` _(ai-workspace)_ | **Primary live crypto scalper** — TypeScript, WebSocket-first |

### Cross-Domain (intentional exceptions)

| Repo | Note |
|---|---|
| `trading_playground` | PCR Trend Reversal research — both APIs by design |
| `pinescript-agents` | Pine Script authoring — broker-agnostic |

### Deprecated (archived — do not modify)

| Repo | Replaced by |
|---|---|
| `dhanhq` | `dhanhq-client` |
| `algo_trader_bot` | `algo_scalper_api` |
| `dhan_scalper` | `algo_scalper_api` |
| `dhan_trader` | `algo_trading_api` |
| `crypto-bot` | `ares` |

---

## Invariants

### Shared
- Risk logic must be deterministic — no randomness, no side effects
- Order execution paths must be auditable (log every state transition)
- All refactors require test coverage before merge
- WebSocket feeds must not drop events under normal network conditions

### Indian Markets (DhanHQ)
- All broker calls go through `dhanhq-client` — no raw HTTP to DhanHQ elsewhere
- No breaking changes to `dhanhq-client` public API without version bump

### Crypto (Delta Exchange)
- All broker calls for crypto go through `ares` (execution) or `crypto_bot_api` (API layer)
- Delta Exchange credentials must never appear in Indian market repos

---

## Architecture Rules

- Service objects own all trading logic — no business logic in controllers
- Event-driven exit management — positions close via signals, not polling
- No coupling between feed processing and order execution layers

---

## Cross-Repo Dependencies

### Indian Markets
```
dhanhq-client  →  algo_trading_api
dhanhq-client  →  algo_scalper_api
dhanhq-client  →  dhanhq-mcp
dhanhq-client  →  dhan_mcp_server (Python SDK)
dhanhq-client  →  dhan_trader_bot
dhanhq-client  →  swing_long_trader
dhanhq-client  →  vyapari
```

### Crypto
```
ares (ai-workspace)  →  Delta Exchange WebSocket + REST (direct)
crypto_bot_api       →  Delta Exchange REST (direct)
```

### Cross-domain (intentional)
```
trading_playground  →  dhanhq-client + Delta Exchange  (both, by design)
```

---

## Running Context

- Primary languages: Ruby (Indian markets), TypeScript (crypto)
- Framework: Rails 8 API mode (Indian), pure TypeScript (crypto)
- Testing: RSpec (Ruby), Jest (TypeScript)
- Indian Markets Broker: DhanHQ v2
- Crypto Broker: Delta Exchange India

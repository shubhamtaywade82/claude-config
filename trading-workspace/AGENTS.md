# Trading Workspace

This workspace contains all trading infrastructure — split across two distinct market domains with **strictly separate broker APIs**.

---

## ⚠️ Critical API Boundary

| Domain | Exchange | Broker API | Repos |
|---|---|---|---|
| Indian Markets (NSE/BSE) | NSE, BSE | **DhanHQ v2 API only** | `dhanhq-*`, `algo_*`, `dhan_*`, `market-data-service`, `swing_long_trader` |
| Crypto | Delta Exchange India | **Delta Exchange API only** | `crypto-bot`, `crypto_bot_api` |

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

## Repos

### Indian Markets — DhanHQ v2

| Repo | Role |
|---|---|
| `dhanhq-client` | Broker SDK — DhanHQ v2 API wrapper |
| `dhanhq` | Core DhanHQ integration |
| `dhanhq-mcp` | DhanHQ MCP server |
| `dhan_mcp_server` | DhanHQ v2 MCP server — read-only broker data (portfolio, orders, market data) |
| `algo_trading_api` | Primary strategy engine (NSE/BSE) |
| `algo_scalper_api` | Low-latency execution engine (NSE/BSE) |
| `algo_trader_bot` | Automated trading bot (NSE/BSE) |
| `dhan_live_feed_ruby` | Real-time NSE/BSE market data feed |
| `dhan_scalper` | Scalper strategy layer (NSE/BSE) |
| `dhan_trader` | Core trader logic (NSE/BSE) |
| `dhan_trader_bot` | Trader bot runtime (NSE/BSE) |
| `market-data-service` | Market data aggregation (NSE/BSE) |
| `swing_long_trader` | Swing/long position strategies (NSE/BSE) |
| `vyapari` | AI-powered options trading agent — Ollama LLM + DhanHQ (NSE/BSE) |

### Crypto — Delta Exchange India

| Repo | Role |
|---|---|
| `crypto-bot` | Crypto trading bot (Delta Exchange India) |
| `crypto_bot_api` | Crypto API layer (Delta Exchange India) |

### Cross-Domain (intentional exceptions)

| Repo | Role | Note |
|---|---|---|
| `trading_playground` | Strategy research scripts — NIFTY/SENSEX options (PCR Trend Reversal) | **May reference both DhanHQ and Delta Exchange APIs** — cross-broker comparison is intentional here |
| `pinescript-agents` | Pine Script / TradingView indicator development assistant | **May reference both APIs** — broker-agnostic strategy authoring tool |

---

## Invariants

### Shared
- Risk logic must be deterministic — no randomness, no side effects
- Order execution paths must be auditable (log every state transition)
- All refactors require test coverage before merge
- WebSocket feeds must not drop events under normal network conditions

### Indian Markets (DhanHQ)
- No breaking changes to `dhanhq-client` public API without version bump
- All broker calls go through `dhanhq-client` — no raw HTTP to DhanHQ elsewhere

### Crypto (Delta Exchange)
- All broker calls go through `crypto_bot_api` — no raw HTTP to Delta Exchange in `crypto-bot`
- Delta Exchange API credentials must never appear in Indian market repos and vice versa

---

## Architecture Rules

- Service objects own all trading logic — no business logic in controllers
- Event-driven exit management — positions close via signals, not polling
- Strategy DSL must remain broker-agnostic where possible
- No coupling between feed processing and order execution layers

---

## Cross-Repo Dependencies

### Indian Markets
```
dhan_live_feed_ruby  →  algo_trading_api  →  algo_scalper_api
dhanhq-client        →  algo_trading_api
dhanhq-client        →  dhan_scalper
dhanhq-client        →  dhan_trader / dhan_trader_bot
```

### Crypto
```
crypto_bot_api  →  crypto-bot
```

### Cross-domain (intentional)
```
trading_playground  →  dhanhq-client + crypto_bot_api  (both, by design)
pinescript-agents   →  dhanhq-client + crypto_bot_api  (both, by design)
```

---

## Running Context

- Primary languages: Ruby, Node.js
- Framework: Rails (API mode), Express/Node (crypto-bot)
- Testing: RSpec (Ruby), Jest/Mocha (Node)
- Indian Markets Broker: DhanHQ v2
- Crypto Broker: Delta Exchange India

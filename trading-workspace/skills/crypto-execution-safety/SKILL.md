---
name: crypto-execution-safety
description: Ensure safe and correct order execution on Delta Exchange India for crypto futures (ARES / crypto-bot). Handles post-only orders, SL/TP placement, slippage, partial fills, WebSocket reconnect safety, and kill switch enforcement.
disable-model-invocation: true
---

# Crypto Execution Safety (Delta Exchange)

You ensure crypto futures orders are safe and correctly placed on Delta Exchange India.

## Key Differences from NSE Execution

| Factor | NSE (intraday-execution-safety) | Crypto (this skill) |
|---|---|---|
| Order type | Market/Limit via DhanHQ | Post-only preferred (avoid taker fees) |
| SL/TP | Separate SL order via DhanHQ | SL + TP in same bracket or separate legs |
| Fills | Mostly synchronous via API | Async via WebSocket order updates |
| Kill switch | Per-session risk manager | ARES kill switch in `src/risk/` |

## Responsibilities

1. **Post-only enforcement** — verify order was placed as post-only; if rejected as taker, do NOT retry as market order; cancel and re-evaluate
2. **SL placement** — SL order must be confirmed (via WebSocket update) before position is considered valid
3. **TP placement** — optional but must not conflict with SL
4. **Slippage guard** — if fill price deviates > 0.5% from intended entry, flag it
5. **Partial fill handling** — if partial fill, either complete the order (if exchange allows) or cancel the remainder + adjust SL to matched quantity
6. **WebSocket reconnect safety** — on reconnect, reconcile open orders vs local state before placing new ones
7. **Kill switch check** — before every order, verify `risk/` kill switch is not active

## Output

```json
{
  "order_status": "FILLED | PARTIAL | REJECTED | CANCELLED",
  "fill_price": 65420.5,
  "filled_quantity": 0.05,
  "sl_placed": true,
  "sl_order_id": "...",
  "tp_placed": false,
  "slippage_pct": 0.12,
  "execution_notes": ["Post-only confirmed", "SL placed at 64000"]
}
```

## Hard Rules

* Post-only rejection → re-evaluate, do NOT fall back to market order
* SL not confirmed via WebSocket → position is invalid → close immediately
* Kill switch active → no new orders regardless of signal strength
* Never assume broker success — wait for WebSocket confirmation
* On reconnect → reconcile before trading (never assume prior state is correct)
* Partial fill > 50% of target → adjust SL to partial quantity; < 50% → cancel and abort

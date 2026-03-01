---
name: intraday-pipeline
description: Run the full 7-step intraday NSE/BSE options trading pipeline in sequence. Chains market-regime → strike-selection → entry-validation → risk-sizing → execution-safety → exit-management → post-trade-intel. Use when evaluating or implementing a complete trade from pre-market to post-trade.
disable-model-invocation: true
---

# Intraday Options Pipeline — Full Orchestrator

Run all 7 pipeline steps in order. Each step must pass before proceeding to the next. A failure at any step aborts the pipeline and returns a `REJECTED` verdict with the reason.

## Pipeline Sequence

```
Step 1: Market Regime        → options_buying_allowed? → if false: STOP
Step 2: Strike Selection     → strike valid + liquid?   → if false: STOP
Step 3: Entry Validation     → all confirmations met?   → if false: STOP
Step 4: Risk Sizing          → quantity + risk defined?  → if false: STOP
Step 5: Execution Safety     → SL placed + confirmed?   → if false: STOP
Step 6: Exit Management      → (runs during position)
Step 7: Post-Trade Intel     → (runs after close)
```

## Step 1 — Market Regime

See [intraday-market-regime](../intraday-market-regime/SKILL.md).

Required output before proceeding:
```json
{ "options_buying_allowed": true, "preferred_side": "CALL_ONLY | PUT_ONLY" }
```

**Gate:** `options_buying_allowed: false` → pipeline STOPS. Do not proceed.

---

## Step 2 — Strike Selection

See [intraday-strike-selection](../intraday-strike-selection/SKILL.md).

Input: `preferred_side` from Step 1.

Required output:
```json
{ "symbol": "NIFTY", "strike": 22650, "type": "CE | PE" }
```

**Gate:** illiquid, deep ITM/OTM, or IV Rank ≥ 60 → pipeline STOPS.

---

## Step 3 — Entry Validation

See [intraday-entry-validation](../intraday-entry-validation/SKILL.md).

Input: `symbol`, `strike`, `type` from Step 2.

Required output:
```json
{ "entry_allowed": true, "entry_price": 185.4 }
```

**Gate:** Any missing confirmation, cooldown active, or max entries hit → pipeline STOPS.

---

## Step 4 — Risk Sizing

See [intraday-risk-sizing](../intraday-risk-sizing/SKILL.md).

Input: `entry_price` from Step 3, `account_capital`, `daily_loss_remaining`.

Required output:
```json
{ "quantity": 75, "risk_rupees": 1200, "max_daily_loss_remaining": 1800 }
```

**Gate:** Risk per trade > 1% or daily loss limit hit → pipeline STOPS.

---

## Step 5 — Execution Safety

See [intraday-execution-safety](../intraday-execution-safety/SKILL.md).

Input: all of Steps 2–4.

Required output:
```json
{ "order_status": "FILLED", "sl_placed": true }
```

**Gate:** SL not confirmed → position is invalid → pipeline STOPS, do not hold.

---

## Step 6 — Exit Management (during position)

See [intraday-exit-management](../intraday-exit-management/SKILL.md).

Run continuously while position is open. Outputs `exit_reason` and `pnl` when triggered.

---

## Step 7 — Post-Trade Intelligence (after close)

See [intraday-post-trade-intel](../intraday-post-trade-intel/SKILL.md).

Run after every trade closes. Evaluates whether trading should continue.

**Gate:** `trading_allowed: false` → halt for the session.

---

## Pipeline Output

```json
{
  "pipeline_result": "EXECUTED | REJECTED | HALTED",
  "rejection_step": "REGIME | STRIKE | ENTRY | RISK | EXECUTION | POST_TRADE",
  "rejection_reason": "...",
  "trade": {
    "symbol": "NIFTY",
    "strike": 22650,
    "type": "CE",
    "entry_price": 185.4,
    "quantity": 75,
    "sl_placed": true,
    "pnl": null
  }
}
```

## Hard Rules (apply at every step)

- A failed gate is never overridden — not even once
- Each step's output is the only valid input for the next step
- No step skips are allowed regardless of "obvious" market conditions
- Pipeline abort is not a failure — it is the risk system working correctly

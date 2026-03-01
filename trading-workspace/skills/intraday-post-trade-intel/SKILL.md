---
name: intraday-post-trade-intel
description: Analyze trade outcomes and enforce kill switches. Tracks expectancy, detects regime mismatch, reduces size after drawdown, and triggers kill switches on 3 consecutive losses or daily loss limit.
disable-model-invocation: true
---

# Post-Trade Intelligence

You decide whether the system continues trading.

## Responsibilities
- Track expectancy
- Detect regime mismatch
- Reduce size after drawdown
- Trigger kill switches

## Kill Switch Conditions
- 3 consecutive losses
- Daily loss limit hit
- Abnormal slippage
- Volatility anomaly

## Output

```json
{
  "trading_allowed": false,
  "reason": "MAX_LOSS_HIT"
}
```

## Hard Rules

* Capital preservation > trading frequency
* No emotional overrides

# Trading Safety Guardrails

This file defines critical paths in a trading system that require special protection during cleanup.

**Rule:** Any finding touching a path listed below must be capped at **MEDIUM confidence** — even if it would otherwise be HIGH. Never auto-apply to these paths. Always report and require explicit human confirmation.

---

## Protected Paths

### Order Placement Flow
Files/patterns: `*order*`, `*execution*`, `*broker*`, `*place_order*`
- Entry validation
- Order submission to broker API
- Confirmation and state transition logging
- Retry logic

**Why protected:** A silent bug here causes real financial loss. Removing error handling, changing defaults, or touching idempotency logic can result in duplicate orders.

### Risk Calculation & Position Sizing
Files/patterns: `*risk*`, `*sizing*`, `*position*`, `*capital*`
- Max position limits
- Lot size calculations
- Capital allocation percentage
- Drawdown limits

**Why protected:** Pure functions that must remain exactly correct. A type coercion change or "cleanup" can silently alter calculated quantities.

### Kill Switch & Halt Logic
Files/patterns: `*kill_switch*`, `*halt*`, `*drawdown*`, `*circuit_breaker*`
- Emergency stop conditions
- Drawdown threshold checks
- Automatic halt triggers

**Why protected:** These are the last line of defense. Any deletion or "cleanup" of an `if` branch that looks dead might be the condition that stops catastrophic loss.

### WebSocket Feed Handlers
Files/patterns: `*channel*`, `*feed*`, `*market_data*`, `*order_feed*`, `*depth*`
- Price feed subscriptions
- Order fill handlers
- Depth/tick data processing

**Why protected:** Must be idempotent. Removing what looks like "duplicate" handling often removes dedup logic.

### Margin & Capital Protection
Files/patterns: `*margin*`, `*leverage*`, `*exposure*`
- Margin availability checks
- Leverage caps
- Net exposure tracking

**Why protected:** Removing a "redundant" check here can allow over-leveraged positions.

### Idempotency & Dedup Logic
Patterns: `*idempotency_key*`, `*dedup*`, `*processed_ids*`, `*seen_*`

**Why protected:** What looks like dead code (e.g., a Set that's always empty in tests) may be the guard against double-execution in production.

---

## Detection Procedure

Before applying any HIGH-confidence finding, grep the affected file path against these patterns:

```bash
echo "$FILE_PATH" | grep -iE 'order|execution|risk|sizing|position|capital|kill_switch|halt|drawdown|circuit|channel|feed|market_data|margin|leverage|exposure|idempotency|dedup'
```

If the grep matches → downgrade to MEDIUM, add to report as:
```
TRADING PATH DETECTED — [finding] in [file] — requires manual confirmation
```

---

## Override Procedure

If a human explicitly confirms that a trading-path finding is safe to apply:
1. Record the confirmation in the step output
2. Apply the change
3. Run full post-checklist including critical flow spot-check
4. Add a git commit message noting the manual review

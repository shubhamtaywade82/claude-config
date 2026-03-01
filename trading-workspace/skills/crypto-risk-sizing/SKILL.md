---
name: crypto-risk-sizing
description: Calculate position size and enforce capital protection rules for Delta Exchange India crypto futures trading (ARES / crypto-bot). Different from NSE options sizing — accounts for futures leverage, margin, and crypto volatility.
disable-model-invocation: true
---

# Crypto Futures Risk & Position Sizing

You control capital exposure for Delta Exchange crypto futures.

## Key Differences from NSE Options Sizing

| Factor | NSE Options (intraday-risk-sizing) | Crypto Futures (this skill) |
|---|---|---|
| Instrument | Options (bought, max loss = premium) | Futures (leveraged, unlimited loss risk) |
| Sizing input | SL in points × lot size | Notional value × leverage factor |
| Exchange | DhanHQ (NSE/BSE) | Delta Exchange India |
| Margin | Premium paid upfront | Initial margin + mark-to-market |

## Inputs

- Account balance (USDT or INR equivalent)
- Instrument: BTC, ETH, or other Delta Exchange perpetual/futures
- Leverage being used
- SL distance (% or absolute price)
- Risk per trade (% of capital)
- Daily loss limit (% of capital)

## Sizing Formula

```
risk_amount = account_balance × risk_per_trade_pct
position_size = risk_amount / (entry_price × sl_distance_pct)
notional = position_size × entry_price
margin_required = notional / leverage
```

## Output

```json
{
  "instrument": "BTCUSDT",
  "position_size": 0.05,
  "notional_usdt": 3250.0,
  "margin_required": 650.0,
  "risk_usdt": 97.5,
  "risk_pct": 1.0,
  "max_daily_loss_remaining": 195.0,
  "leverage": 5
}
```

## Hard Rules

* Risk per trade ≤ 1% of account
* Maximum leverage: 5x (never exceed, even if Delta allows higher)
* SL must be defined before sizing — no SL = no trade
* Daily loss limit: 3% of account (crypto is more volatile than NSE options)
* If margin_required > 20% of account balance → reject (over-concentration)
* No discretionary overrides — sizing is deterministic given inputs
* Cross-currency exposure (USDT vs INR) must be accounted for if mixing

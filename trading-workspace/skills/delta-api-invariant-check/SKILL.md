---
name: delta-api-invariant-check
description: Audit crypto code for Delta Exchange API contract violations and cross-domain API leakage. Use when reviewing crypto-bot or crypto_bot_api code.
disable-model-invocation: true
argument-hint: [file-or-directory]
allowed-tools: Read, Glob, Grep
---

# Skill: Delta Exchange API Invariant Check

Audit crypto code for Delta Exchange API contract violations and cross-domain API leakage.

## Checks

1. Delta Exchange client method signatures — flag any removed or renamed methods
2. Response schema assumptions — flag if code assumes fields that may not exist
3. Auth/API key handling — must use env vars, never hardcoded
4. Rate limit awareness — flag tight loops calling Delta Exchange endpoints
5. Order ID and margin assumptions specific to Delta Exchange contracts

## Cross-Domain Boundary Check (Critical)

6. Flag any reference to DhanHQ APIs inside crypto repos (`crypto-bot`, `crypto_bot_api`)
7. Flag any DhanHQ credentials, endpoints, or client classes appearing in crypto repos
8. Flag any attempt to share positions, orders, or risk state with Indian market repos

## Output

- List of invariant violations with file:line references
- List of cross-domain boundary violations (if any)
- Suggested fix for each violation
- Verdict: SAFE TO SHIP / NEEDS FIXES

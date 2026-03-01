---
name: dhan-api-invariant-check
description: Audit Indian market code for DhanHQ API contract violations and cross-domain API leakage. Use when reviewing dhanhq-*, algo_*, dhan_*, market-data-service, or swing_long_trader code.
disable-model-invocation: true
argument-hint: [file-or-directory]
allowed-tools: Read, Glob, Grep
---

# Skill: DhanHQ API Invariant Check

Audit Indian market code for DhanHQ API contract violations and cross-domain API leakage.

## Checks

1. `dhanhq-client` public method signatures — flag any removed or renamed methods
2. Response schema assumptions — flag if code assumes fields that may not exist
3. Auth token handling — must use env vars, never hardcoded
4. Rate limit awareness — flag tight loops calling DhanHQ endpoints
5. Order ID uniqueness assumptions — DhanHQ IDs are not sequential, do not sort by them

## Cross-Domain Boundary Check (Critical)

6. Flag any reference to Delta Exchange APIs inside Indian market repos (`dhanhq-*`, `algo_*`, `dhan_*`, `market-data-service`, `swing_long_trader`)
7. Flag any Delta Exchange credentials, endpoints, or client classes appearing in DhanHQ repos
8. Flag any shared order/position state between the two domains

## Output

- List of invariant violations with file:line references
- List of cross-domain boundary violations (if any)
- Suggested fix for each violation
- Verdict: SAFE TO SHIP / NEEDS FIXES

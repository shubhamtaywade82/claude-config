# Claude Config

Portable Claude TUI skills, workspace AGENTS.md files, and setup scripts.

## Structure

Skills use the [Agent Skills](https://agentskills.io) directory format — each skill is a directory
containing a `SKILL.md` entrypoint plus optional supporting files loaded on demand.

```
claude-config/
├── install.sh                    ← run on a new machine to set everything up
├── sync.sh                       ← run before committing to pull latest from machine
│
├── global-skills/                ← copied to ~/.claude/skills/
│   ├── code-review/              ← SKILL.md + project-pattern-detection.md
│   ├── rails-best-practices/     ← SKILL.md + controllers-models.md + active-record.md + security-timeouts.md
│   ├── rails-style/              ← SKILL.md
│   ├── rspec/                    ← SKILL.md
│   ├── ruby-design-patterns/     ← SKILL.md + creational-patterns.md + structural-patterns.md + behavioral-patterns.md
│   ├── ruby-style/               ← SKILL.md
│   ├── safe-codebase-cleanup/    ← SKILL.md + 7 runners + checks + scripts + CI gate
│   ├── solid/                    ← SKILL.md + references/ (9 files)
│   └── solid-ruby/               ← SKILL.md + references/ (9 files)
│
├── trading-workspace/            ← copied to ~/project/trading-workspace/
│   ├── AGENTS.md
│   └── skills/                  ← copied to .claude/skills/
│       ├── rails-trading-refactor/
│       ├── rspec-generator/
│       ├── dhan-api-invariant-check/
│       ├── delta-api-invariant-check/
│       ├── intraday-pipeline/
│       ├── intraday-*/ (7 skills)
│       ├── crypto-risk-sizing/
│       └── crypto-execution-safety/
│
└── ai-workspace/                 ← copied to ~/project/ai-workspace/
    ├── AGENTS.md
    └── skills/
        ├── tool-calling-validator/
        ├── prompt-evaluator/
        └── runtime-architecture-check/
```

## New Machine Setup

```bash
git clone <this-repo> ~/project/claude-config
cd ~/project/claude-config

# Full install
./install.sh

# Preview without writing (dry run)
./install.sh --dry-run

# Global skills only
./install.sh --global-only

# Workspace skills + AGENTS.md only (if repos already cloned)
./install.sh --workspace-only

# Custom workspace root (if your projects live elsewhere)
WORKSPACE_ROOT=~/dev ./install.sh
```

## Keeping It Updated

When you add or modify skills on your machine, sync them back:

```bash
cd ~/project/claude-config
./sync.sh
git add -A
git commit -m "Update skills"
git push
```

## Skills Reference

### Global (available in every Claude TUI session)

| Skill | Invoke | Purpose |
|---|---|---|
| `code-review` | `/code-review` | Full code review — detects file type, scans project patterns, applies all rules |
| `rails-best-practices` | `/rails-best-practices` | Rails antipatterns, AR query mistakes, timeouts, security |
| `rails-style` | `/rails-style` | Rails Style Guide conventions |
| `rspec` | `/rspec` | RSpec Style Guide + Better Specs |
| `ruby-design-patterns` | `/ruby-design-patterns` | All 23 GoF patterns with Ruby examples |
| `ruby-style` | `/ruby-style` | Ruby Style Guide conventions |
| `safe-codebase-cleanup` | `/safe-codebase-cleanup` | 7-pass safe cleanup — dedup, types, dead code, circular deps, type strengthening, error handling, AI artifacts. HIGH-confidence only. Rails-aware + trading guardrails + CI gate |
| `solid` | `/solid` | SOLID principles (TypeScript/general) |
| `solid-ruby` | `/solid-ruby` | SOLID + TDD + clean code (Ruby) |

### Trading Workspace

| Skill | Purpose |
|---|---|
| `rails-trading-refactor` | Refactor trading code to service objects |
| `rspec-generator` | Generate RSpec coverage for trading code |
| `dhan-api-invariant-check` | Audit DhanHQ API contract + cross-domain boundary |
| `delta-api-invariant-check` | Audit Delta Exchange API contract + cross-domain boundary |
| `intraday-market-regime` | Classify market before trading (TRENDING/RANGE/CHOPPY) |
| `intraday-strike-selection` | Select optimal options contract |
| `intraday-entry-validation` | Validate entry timing |
| `intraday-risk-sizing` | Position size + capital protection |
| `intraday-execution-safety` | Safe order placement |
| `intraday-exit-management` | SL, trailing, time exits |
| `intraday-post-trade-intel` | Kill switches, drawdown tracking |
| `intraday-pipeline` | Full 7-step pipeline orchestrator (regime → post-trade) |
| `crypto-risk-sizing` | Position sizing for Delta Exchange futures |
| `crypto-execution-safety` | Safe execution for Delta Exchange crypto futures |

### AI Workspace

| Skill | Purpose |
|---|---|
| `tool-calling-validator` | Validate agent tool schemas |
| `prompt-evaluator` | Evaluate prompt quality and safety |
| `runtime-architecture-check` | Check agent layer boundary violations |

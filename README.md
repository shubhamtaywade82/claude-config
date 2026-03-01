# Claude Config

Portable Claude TUI skills, workspace AGENTS.md files, and setup scripts.

## Structure

```
claude-config/
├── install.sh                    ← run on a new machine to set everything up
├── sync.sh                       ← run before committing to pull latest from machine
│
├── global-skills/                ← copied to ~/.claude/skills/
│   ├── code-review.md
│   ├── rails-best-practices.md
│   ├── rails-style.md
│   ├── rspec.md
│   ├── ruby-design-patterns.md
│   ├── ruby-style.md
│   ├── solid.md
│   ├── solid-ruby.md
│   └── solid-references/
│
├── trading-workspace/            ← copied to ~/project/trading-workspace/
│   ├── AGENTS.md
│   └── skills/                  ← copied to .claude/skills/
│       ├── rails-trading-refactor.md
│       ├── rspec-generator.md
│       ├── dhan-api-invariant-check.md
│       ├── delta-api-invariant-check.md
│       └── intraday-*.md (7 skills)
│
└── ai-workspace/                 ← copied to ~/project/ai-workspace/
    ├── AGENTS.md
    └── skills/
        ├── tool-calling-validator.md
        ├── prompt-evaluator.md
        └── runtime-architecture-check.md
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

### AI Workspace

| Skill | Purpose |
|---|---|
| `tool-calling-validator` | Validate agent tool schemas |
| `prompt-evaluator` | Evaluate prompt quality and safety |
| `runtime-architecture-check` | Check agent layer boundary violations |

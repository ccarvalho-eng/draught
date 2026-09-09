# Tool Catalog — Command Reference

Routing-oriented catalog of core plugin commands, skills, and agents for `/skill elixir-phoenix-help`.

## Workflow Commands (the main cycle)

These commands form a connected pipeline — each reads the previous phase's output.

### `/skill elixir-phoenix-brainstorm <topic>` — Adaptive requirements gathering

- **When**: Vague idea, unclear scope, want to explore before planning
- **Input**: Topic or feature idea (can be very rough)
- **Output**: `.draught/plans/{slug}/interview.md` with structured requirements
- **Next step**: `/skill elixir-phoenix-plan` (detects interview.md, skips clarification)
- **Agents used**: phoenix-patterns-analyst, web-researcher (research phase only)

**When to use brainstorm vs plan:**

| Signal | Use |
|--------|-----|
| Clear feature, know what you want | `/skill elixir-phoenix-plan` directly |
| Vague idea, exploring options | `/skill elixir-phoenix-brainstorm` |
| Multiple possible approaches | `/skill elixir-phoenix-brainstorm` (research phase) |
| Requirements unclear, need to discuss | `/skill elixir-phoenix-brainstorm` |

### `/skill elixir-phoenix-plan <description>` — Create implementation plan

- **When**: New feature, multi-file change, anything needing structure
- **Input**: Feature description in natural language (or brainstorm interview.md)
- **Output**: `.draught/plans/{slug}/plan.md` with checkboxed tasks
- **Flags**: `--depth quick|standard|deep`, `--existing` (enhance existing plan)
- **Next step**: `/skill elixir-phoenix-work .draught/plans/{slug}/plan.md`
- **Agents used**: planning-orchestrator, research agents

### `/skill elixir-phoenix-brief <plan-path>` — Interactive plan walkthrough

- **When**: Want to understand a plan before working on it
- **Input**: Path to a plan.md file
- **Output**: Ephemeral (conversation only, no files)
- **Next step**: `/skill elixir-phoenix-work` or `/skill elixir-phoenix-plan --existing` to enhance

### `/skill elixir-phoenix-work <plan-path>` — Execute plan tasks

- **When**: Ready to implement a plan
- **Input**: Path to plan.md with checkboxed tasks
- **Output**: Code changes, updated checkboxes, `progress.md`
- **Flags**: `--continue` (resume from last checkpoint)
- **Next step**: `/skill elixir-phoenix-review`

### `/skill elixir-phoenix-review` — Parallel code review

- **When**: Implementation done, want quality check before merging
- **Input**: Git diff (changed files)
- **Output**: `.draught/plans/{slug}/reviews/{feature}-review.md`
- **Agents used**: 3-5 specialist reviewers in parallel
- **Next step**: Fix issues, then `/skill elixir-phoenix-compound` for lessons learned

### `/skill elixir-phoenix-triage` — Interactive review triage

- **When**: Review has many findings, need to prioritize
- **Input**: Review file from `/skill elixir-phoenix-review`
- **Output**: Prioritized action list

### `/skill elixir-phoenix-compound` — Capture solved problem

- **When**: Just solved a tricky bug or pattern worth remembering
- **Input**: Description of what was solved
- **Output**: `.draught/solutions/{category}/{fix}.md`
- **Why**: Builds searchable knowledge base for future sessions

### `/skill elixir-phoenix-full <description>` — Autonomous full cycle

- **When**: Large feature, want plan→work→verify→review in one shot
- **Input**: Feature description
- **Output**: All workflow artifacts
- **Caution**: Best for well-defined features; complex ones benefit from manual phase control

## Standalone Commands

### `/skill elixir-phoenix-quick <description>` — Fast implementation

- **When**: Small change (<50 lines), single file, clear scope
- **Input**: What to change
- **Output**: Direct code changes (no plan artifacts)
- **Examples**: "Add phone field to User schema", "Fix pagination bug in index"

### `/skill elixir-phoenix-investigate` — Bug investigation

- **When**: Error, crash, unexpected behavior, failing test
- **Input**: Bug description or stack trace
- **Output**: Root cause analysis, fix suggestion
- **Agents used**: deep-bug-investigator (for complex bugs)
- **Checks**: `.draught/solutions/` first for known fixes

### `/skill elixir-phoenix-verify` — Run all checks

- **When**: Before PR, before deploy, after large changes
- **Runs**: `mix compile --warnings-as-errors`, `mix format`, `mix credo`, `mix test`
- **Output**: Pass/fail report

### `/skill elixir-phoenix-hex-publish` — Publish a Hex release

- **When**: Releasing a new package version to Hex.pm
- **Input**: Intended version bump (explicit or inferred)
- **Output**: Release prep, tag/release commands, publish status

### `/skill elixir-phoenix-research <topic>` — Research with parallel workers

- **When**: "How to implement X", "Best practices for Y", "What library for Z"
- **Flags**: `--library <name>` (evaluate a specific Hex package)
- **Output**: Research summary with sources
- **Agents used**: 1-3 web-researcher agents in parallel

### `/skill elixir-phoenix-pr-review` — Address PR review comments

- **When**: Got review comments on a PR, need to address them
- **Input**: PR number or URL
- **Output**: Code changes addressing each comment

### `/skill elixir-phoenix-intro` — Interactive plugin tutorial

- **When**: New to the plugin, want to learn what's available
- **Flags**: `--section N` (jump to section 1-6)

### `/skill elixir-phoenix-init` — Project setup

- **When**: Setting up plugin rules for a new project
- **Output**: Injects rules into project AGENTS.md

### `/skill elixir-phoenix-permissions` — Permission analyzer

- **When**: Too many "allow?" prompts, permission fatigue, after 5+ prompts in a session
- **Input**: Optional `--days=N` (default: 14), `--dry-run`
- **Output**: Scans session JSONL files for uncovered Bash commands, recommends `settings.json` changes
- **Triage**: Interactive GREEN/YELLOW/RED triage with ask the user in chat

- **When**: "Fix all credo issues", "improve coverage", "reduce warnings", measurable metric
- **Input**: Target metric and optional strategy
- **Output**: Iterative improvement loop with automatic rollback on failure

### `/skill elixir-phoenix-challenge` — Rigorous review mode

- **When**: "Grill me", "challenge this", want thorough scrutiny before merging
- **Input**: Changed files (like review)
- **Output**: Aggressive questioning of Ecto changes, LiveView events, PR readiness

### `/skill elixir-phoenix-document` — Documentation generator

- **When**: Need @moduledoc, @doc annotations, or README updates
- **Input**: Modules or contexts to document
- **Output**: Inline documentation in source files

### `/skill elixir-phoenix-examples` — Pattern walkthroughs

- **When**: "How do I...", "show me an example of...", learning patterns
- **Input**: Pattern or topic description
- **Output**: Practical examples with working code

### `/skill elixir-phoenix-ecto-constraint-debug` — Constraint violation debugger

- **When**: unique_constraint, foreign_key_constraint, or check_constraint errors
- **Input**: Error message or constraint name
- **Output**: Traces triggers, checks migrations, finds duplicate data

### `/skill elixir-phoenix-migrations` — Migration safety planning

- **When**: Schema changes, backfills, zero-downtime rollout planning
- **Input**: Requested DB/schema change
- **Output**: Phased migration plan, risk notes, rollback path

### `/skill elixir-phoenix-upgrade` — Dependency/framework upgrade workflow

- **When**: Upgrading Elixir/OTP/Phoenix/Ecto/LiveView dependencies
- **Input**: Target versions or upgrade scope
- **Output**: Phased upgrade plan, compatibility checks, validation results

### `/skill elixir-phoenix-liveview-debug` — LiveView bug workflow

- **When**: Event/state drift, reconnect bugs, stream/assign lifecycle issues
- **Input**: Reproduction timeline, failing flow, or stack traces
- **Output**: Callback-state root cause and regression fix strategy

### `/skill elixir-phoenix-incident-response` — Production incident triage

- **When**: Outage, elevated error rates, or critical path degradation
- **Input**: Symptoms, timeline, and recent deploy/config context
- **Output**: Stabilization actions, likely causes, hotfix/rollback recommendation

## Analysis Commands

### `/skill elixir-phoenix-perf` — Performance analysis

- **When**: "App is slow", "queries are slow", "LiveView is laggy"
- **Covers**: Ecto queries, LiveView renders, OTP bottlenecks

### `/skill elixir-phoenix-observability` — Metrics, traces, and logs

- **When**: Instrumentation gaps or weak production visibility
- **Covers**: Telemetry events, traces, structured logging, actionable alerts

### `/skill elixir-phoenix-n1-check` — N+1 query detection

- **When**: Suspect N+1 queries, list pages are slow
- **Output**: Found N+1 patterns with fix suggestions

### `/skill elixir-phoenix-assigns-audit` — LiveView memory audit

- **When**: LiveView processes using too much memory, large assigns
- **Output**: Assigns size analysis, stream conversion suggestions

### `/skill elixir-phoenix-audit` — Project health audit

- **When**: Want overall project quality assessment
- **Agents used**: 5 specialist agents in parallel
- **Output**: `.draught/audit/reports/` with findings per area

### `/skill elixir-phoenix-techdebt` — Technical debt analysis

- **When**: Want to identify and track technical debt
- **Output**: Categorized debt items with severity

### `/skill elixir-phoenix-boundaries` — Context boundary violations

- **When**: Suspect cross-context coupling, unclear module boundaries
- **Output**: Boundary violation report

### `/skill elixir-phoenix-call-tracing <function>` — Call chain tracing

- **When**: Need to understand how a function is called and what it calls
- **Agents used**: call-tracer, xref-analyzer

## Decision Helpers

### When to use `/skill elixir-phoenix-plan` vs `/skill elixir-phoenix-quick`

| Signal | Use |
|--------|-----|
| 1-2 files, clear change | `/skill elixir-phoenix-quick` |
| 3+ files or unclear scope | `/skill elixir-phoenix-plan` |
| New domain concept | `/skill elixir-phoenix-plan` |
| "Add field to schema" | `/skill elixir-phoenix-quick` |
| "Add notification system" | `/skill elixir-phoenix-plan` |

### When to use `/skill elixir-phoenix-investigate` vs just fixing

| Signal | Use |
|--------|-----|
| Know the cause, small fix | Fix directly |
| Stack trace, unknown cause | `/skill elixir-phoenix-investigate` |
| Intermittent / race condition | `/skill elixir-phoenix-investigate` |
| Test failing, obvious assertion | Fix directly |

### When to use `/skill elixir-phoenix-full` vs manual phases

| Signal | Use |
|--------|-----|
| Well-defined feature, clear scope | `/skill elixir-phoenix-full` |
| Exploratory, may pivot | `/skill elixir-phoenix-plan` then decide |
| Want control between phases | Manual: plan → work → review |
| Large feature, new domain | `/skill elixir-phoenix-full` (handles complexity) |

### When to use `/skill elixir-phoenix-review` vs `/skill elixir-phoenix-verify`

| Signal | Use |
|--------|-----|
| Want compile/test/format pass | `/skill elixir-phoenix-verify` |
| Want architectural feedback | `/skill elixir-phoenix-review` |
| Pre-PR checklist | Both: `/skill elixir-phoenix-verify` then `/skill elixir-phoenix-review` |

## Reference Skills (auto-loaded, not invoked directly)

These load automatically when you edit matching files:

| Skill | Triggers on |
|-------|-------------|
| `liveview-patterns` | `*_live.ex`, `*_component.ex`, `*.sface` |
| `ecto-patterns` | Migrations, schemas, changesets, `from(` |
| `phoenix-contexts` | Context modules, router, controllers |
| `security` | Auth files, session, password |
| `testing` | `*_test.exs`, factories, fixtures |
| `oban` | Workers, `use Oban.Worker` |
| `elixir-idioms` | GenServer, mix tasks, general `.ex` |
| `deploy` | Dockerfile, fly.toml, runtime.exs |

## Workflow Cheat Sheet

```text
New feature:     /skill elixir-phoenix-plan → /skill elixir-phoenix-work → /skill elixir-phoenix-review → /skill elixir-phoenix-compound
Quick fix:       /skill elixir-phoenix-quick
Bug:             /skill elixir-phoenix-investigate
Full auto:       /skill elixir-phoenix-full
Pre-PR:          /skill elixir-phoenix-verify → /skill elixir-phoenix-review
Research:        /skill elixir-phoenix-research [topic]
Evaluate lib:    /skill elixir-phoenix-research --library [name]
Resume work:     /skill elixir-phoenix-work --continue
Release:         /skill elixir-phoenix-hex-publish
Post-fix lesson: /skill elixir-phoenix-compound
Permissions:     /skill elixir-phoenix-permissions
```

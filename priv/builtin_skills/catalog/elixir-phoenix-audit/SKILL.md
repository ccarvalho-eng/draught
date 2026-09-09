---
name: elixir-phoenix-audit
description: 'Audit project health across architecture, security, performance, tests, and deps.'
metadata:
  short-description: 'Audit Phoenix project health'
---

# Project Health Audit

Comprehensive project-wide health assessment using 5 parallel specialist subagents.

## Usage

```bash
`elixir-phoenix-audit`              # Full audit (default)
`elixir-phoenix-audit` --quick      # 2-3 minute pulse check
`elixir-phoenix-audit` --focus=security   # Deep dive single area
`elixir-phoenix-audit` --focus=performance
`elixir-phoenix-audit` --since abc123   # Incremental audit since commit
`elixir-phoenix-audit` --since HEAD~10  # Audit last 10 commits
```

## When to Use

- **Quarterly** health checks
- **Before major releases**
- **After large refactors**
- **New team member onboarding** (understand codebase health)

## Iron Laws

1. **Wait for ALL agents before synthesizing** — Partial results create misleading health scores because cross-category correlations get missed
2. **Scope agent prompts to specific directories** — Vague prompts like "analyze the codebase" produce generic findings that waste tokens and miss real issues
3. **Never compare scores across projects** — Scoring methodology depends on project size and maturity; only track trends within the same project
4. **Quick mode before full mode** — Run `--quick` first to catch compile/test failures before spending tokens on 5 parallel agents

## Subagent Architecture

Spawn 5 specialists in parallel using agent tools when explicitly requested by the user:

| Subagent | Focus | Output File |
|----------|-------|-------------|
| Architecture Reviewer | Structure quality, coupling, cohesion | `arch-review.md` |
| Performance Auditor | N+1, indexes, bottlenecks, scalability | `perf-audit.md` |
| Security Auditor | OWASP scan, auth patterns, secrets | `security-audit.md` |
| Test Health Auditor | Coverage, quality, flaky tests | `test-audit.md` |
| Dependency Auditor | Vulnerabilities, outdated, unused | `deps-audit.md` |

## Workflow

### Step 1: Create Task List and Run 5 Auditors

Create progress tasks for each audit area and mark them in progress as each auditor starts.

Authoritative behavior:
- If the user explicitly requests delegation, launch all five auditors in parallel using Draught agents.
- If delegation is not requested, run the five audit areas sequentially in the main thread and keep the same progress tasks.

**Agent prompts must be FOCUSED.** Scope each prompt to the
relevant directories and patterns. Do NOT give vague prompts
like "analyze the codebase."

**Output efficiency**: Tell each agent: "Report ONLY issues found.
Do NOT list clean checks, passing categories, or 'What's Good'.
One summary line per clean area suffices."

### Step 2: Collect Results

Wait for ALL auditors to complete. Mark each auditor's task as
`completed` in the progress tracker as it finishes. NEVER proceed while
any auditor is still running.

Read reports from `.draught/audit/reports/`.

### Step 3: Compress Findings

After all five auditors complete, run a consolidation pass to compress findings from
`.draught/audit/reports/` into `.draught/audit/summaries/`, focusing on category scores,
critical findings only, cross-category correlations, and deduplicated issues.

Read `.draught/audit/summaries/consolidated.md` for synthesis.

### Step 4: Calculate Health Score

Each category scores 0-100. See `references/scoring-methodology.md`.

### Step 5: Generate Report

Write to `.draught/audit/summaries/project-health-{date}.md`.

## Output Format

Report includes: Executive summary with health score (A-F, numeric/100),
per-category score table (Architecture, Performance, Security, Tests, Dependencies),
critical issues, top recommendations, and action plan (Immediate/Short-term/Long-term).

## Quick Mode (`--quick`)

Only run essential checks (~2-3 minutes):

Run `mix compile --warnings-as-errors`, then `mix hex.audit && mix deps.audit`,
then `mix xref graph --format stats`, then `mix test --trace 2>&1 | tail -20`.

Skip: Full security scan, N+1 analysis, test quality metrics, architecture deep dive.

## Focus Mode (`--focus=area`)

Deep dive single area with full specialist resources:

| Focus | Subagent | Extra Checks |
|-------|----------|--------------|
| `security` | security-analyzer | Full OWASP, sobelow, manual patterns |
| `performance` | (performance subagent) | Profile-level analysis, query explain |
| `architecture` | (arch subagent) | Full xref, coupling matrix, cohesion |
| `tests` | testing-reviewer | Coverage by context, quality metrics |
| `deps` | (deps subagent) | License audit, maintenance status |

## Incremental Mode (`--since <commit>`)

Analyze only changes since a specific commit. Useful for pre-merge checks:

Run `git diff --name-only <commit>...HEAD` to identify changed files, then run targeted audits on changed files only (skips full project scan).

Combines with other flags: ``elixir-phoenix-audit` --since HEAD~5 --focus=security`

## Relationship to Other Commands

| Command | Scope | Frequency |
|---------|-------|-----------|
| ``elixir-phoenix-review`` | Changed files (diff) | Every PR |
| ``elixir-phoenix-audit`` | Entire project | Quarterly |
| ``elixir-phoenix-boundaries`` | Context structure | On-demand |
| ``elixir-phoenix-verify`` | Compile/test pass | Anytime |

## References

- `references/scoring-methodology.md` - How scores are calculated
- `references/architecture-checks.md` - Detailed architecture criteria

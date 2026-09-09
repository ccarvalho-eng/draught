---
name: elixir-phoenix-review
description: 'Review Phoenix changes with parallel specialists before commit or PR.'
metadata:
  short-description: 'Review Phoenix changes in parallel'
---

# Review Elixir/Phoenix Code

Review code by spawning parallel specialist agents. Find and
explain issues — do NOT create tasks or fix anything.

## Usage

```
`elixir-phoenix-review`                          # Review all changed files
`elixir-phoenix-review` test                     # Review test files only
`elixir-phoenix-review` security                 # Run security audit only
`elixir-phoenix-review` oban                     # Review Oban workers only
`elixir-phoenix-review` deploy                   # Validate deployment config
`elixir-phoenix-review` iron-laws                # Check Iron Law violations only
`elixir-phoenix-review` .draught/plans/auth/plan.md    # Review implementation of plan
```

## Arguments

`$ARGUMENTS` = Focus area or path to plan file.

## Workflow

### Step 1: Identify Changed Files and Prepare Directories

**CRITICAL**: Create output dirs BEFORE spawning agents — agents
cannot create directories and will fail repeatedly on writes.

Determine SLUG from the most recent plan directory (use `rg --files` on `.draught/plans/*/`), default to `"review"`.
Run `mkdir -p ".draught/plans/${SLUG}/reviews" ".draught/plans/${SLUG}/summaries"` and `mkdir -p .draught/reviews`.

Then run `git diff --name-only HEAD~5` and `git diff --name-only main` to identify changed files. Save the diff base for pre-existing detection in Step 3b.

### Step 1b: Load Plan Context (Scratchpad)

If reviewing a plan, read `.draught/plans/${SLUG}/scratchpad.md` for
planning decisions, rationale, and handoff notes. Include relevant
decisions in each agent's prompt so they have context about WHY
code was written a certain way. This eliminates session archaeology.

### Step 1c: Check Prior Reviews

If `.draught/plans/${SLUG}/reviews/` has prior output, include consolidated
summary in each agent's prompt as "PRIOR FINDINGS" with instruction:
"Focus on NEW issues. Mark still-present issues as PERSISTENT."

### Step 2: Create Task List and Spawn Review Agents (MANDATORY)

**NEVER spawn the same agent role twice in one review.** If reviewing
a plan, scope ALL agents to the plan's changed files in a single pass.
Do NOT run a scoped review followed by a broader review — one pass per role.

**Create a Draught task per agent** (update_plan + update_plan to in_progress) BEFORE spawning.
Spawn agents using the agent tools when explicitly requested by the user — do NOT analyze code yourself.

**For ``elixir-phoenix-review`` or ``elixir-phoenix-review` all` — select agents dynamically
based on the diff, then spawn selected agents in ONE message (parallel):**

| Agent | subagent_type | When to spawn |
|-------|---------------|---------------|
| Elixir Reviewer | `elixir-phoenix:elixir-reviewer` | **Always** |
| Iron Law Judge | `elixir-phoenix:iron-law-judge` | Only if >200 lines changed AND auth/LiveView/Oban files in diff. **Skip** if PostToolUse hooks already verified all files (hooks check Iron Laws on every Edit/Write) |
| Verification Runner | `elixir-phoenix:verification-runner` | Only if `mix test` has NOT been run in this session. **Skip** if ``elixir-phoenix-work`` just passed all verification tiers |
| Security Analyzer | `elixir-phoenix:security-analyzer` | Auth/session/password/token files changed |
| Testing Reviewer | `elixir-phoenix:testing-reviewer` | Test files changed OR new public functions |
| Oban Specialist | `elixir-phoenix:oban-specialist` | Worker files changed (*_worker.ex) |
| Deploy Validator | `elixir-phoenix:deployment-validator` | Dockerfile/fly.toml/runtime.exs changed |

**Agent count**: Min 1, max 5. For <200 lines changed: spawn only
elixir-reviewer + security-analyzer (if auth files). Log selection
rationale in review output.
Spawn using default `spawn_agent` settings in this environment (set `agent_type`,
leave other options unset unless the task explicitly requires additional context).

**For focused reviews — spawn the specified agent only:**

| Argument | subagent_type |
|----------|---------------|
| `test` | `elixir-phoenix:testing-reviewer` |
| `security` | `elixir-phoenix:security-analyzer` |
| `oban` | `elixir-phoenix:oban-specialist` |
| `deploy` | `elixir-phoenix:deployment-validator` |
| `iron-laws` | `elixir-phoenix:iron-law-judge` |

Zero agents spawned = skill failure.

### Step 2b: Scope Agents to the Diff (MANDATORY)

Include `git diff --name-only` in each agent's prompt. Add instruction:
"Focus on NEW code from the diff. Pre-existing issues get one line:
'Pre-existing: {file}:{line} — {brief}'. Do NOT deep-analyze unchanged files."

### Step 3: Collect and Compress Findings

Wait for ALL agents to FULLY complete. **Do NOT report status
until every agent completes.** Mark each agent's Draught task
as `completed` via `update_plan` as it finishes.

**Verification-runner fallback**: If it fails/times out, run directly:
`mix compile --warnings-as-errors && mix format --check-formatted $(git diff --name-only HEAD~5 | grep '\.exs\?$' | tr '\n' ' ') && mix credo --strict && mix test`

**For 4+ agents:** Spawn `elixir-phoenix:context-supervisor` to compress output:

```
Prompt: "Compress review agent output.
  input_dir: .draught/plans/{slug}/reviews
  output_dir: .draught/plans/{slug}/summaries
  output_file: review-consolidated.md
  priority_instructions: BLOCKERs and WARNINGs: KEEP ALL.
    SUGGESTIONs: COMPRESS similar ones into groups.
    Deconfliction: when iron-law-judge and elixir-reviewer
    flag same code, keep iron-law-judge finding."
```

**For focused reviews (1 agent):** Skip supervisor, read
agent output directly.

### Step 3b: Filter Findings (Anti-Noise)

Before writing the review, apply these overriding filters to each finding:

1. Would a senior Elixir dev dismiss this as noise?
2. Does the finding add complexity exceeding the problem's complexity?
3. Are any findings duplicates reworded by different agents?
4. Does the finding affect code actually changed in this diff?
5. Is the finding on unchanged code (not in diff)? → Mark PRE-EXISTING

Demote or remove findings that fail filters 1-4. Mark pre-existing per filter 5.

### Step 4: Generate Review Summary

Read consolidated/agent output. Write to `.draught/plans/{slug}/reviews/{feature}-review.md`
with verdict: PASS | PASS WITH WARNINGS | REQUIRES CHANGES | BLOCKED.

### Step 5: Present Findings and Ask User

**STOP and present the review.** Do NOT create tasks or fix
anything.

**On BLOCKED or REQUIRES CHANGES**: Show finding count by severity,
then offer via `ask the user in chat`: ``elixir-phoenix-triage`` (recommended), ``elixir-phoenix-plan``,
fix directly, or "I'll handle it myself".

**On PASS / PASS WITH WARNINGS**: Suggest ``elixir-phoenix-compound``, ``elixir-phoenix-learn-from-fix``.

**Convention extraction**: After presenting findings, offer: "Any findings
to suppress or enforce as conventions?" See `references/conventions.md`.

## Iron Laws

1. **Review is READ-ONLY** — Find and explain, never fix
2. **NEVER auto-fix after review** — Always ask the user first
3. **Always offer both paths**: ``elixir-phoenix-plan`` and ``elixir-phoenix-work``
4. **Research before claiming** — Agents MUST research before
   making claims about CI/CD or external services

## Integration

``elixir-phoenix-plan`` → ``elixir-phoenix-work`` → ``elixir-phoenix-review`` (YOU ARE HERE) → Blocked? ``elixir-phoenix-triage`` or ``elixir-phoenix-plan`` | Pass? ``elixir-phoenix-compound``

See: `references/review-template.md`, `references/example-review.md`, `references/blocker-handling.md`

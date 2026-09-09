---
name: elixir-phoenix-work
description: 'Execute a Phoenix plan step by step with progress tracking and verification.'
metadata:
  short-description: 'Execute Phoenix plans with verification'
---

# Work

Execute tasks from a plan file with checkpoint tracking and verification.

## Usage

```
`elixir-phoenix-work` .draught/plans/user-auth/plan.md
`elixir-phoenix-work` .draught/plans/user-auth/plan.md --from P2-T3
`elixir-phoenix-work` --skip-blockers
`elixir-phoenix-work`  # Resumes most recent plan
```

## Arguments

- `<plan-file>` -- Path to plan file (optional, auto-detects recent)
- `--from <task-id>` -- Resume from specific task (e.g., `P2-T3`)
- `--skip-blockers` -- Continue past blocked tasks
- `--continue` -- Resume IN_PROGRESS plan from checkboxes

## Iron Laws (NON-NEGOTIABLE)

1. **NEVER auto-proceed** to `elixir-phoenix-review` or any next workflow
   phase -- always ask the user what to do next
2. **AUTO-CONTINUE between plan phases** -- when Phase N completes,
   immediately start Phase N+1. Do NOT stop or ask for permission
   between phases. Only stop at BLOCKERS or when ALL phases are done.
3. **Plan checkboxes ARE the state** -- `[x]` = done, `[ ]` = pending.
   No separate JSON state files. Resume by reading the plan.
4. **Verify after EVERY task** -- never skip verification
5. **Max 3 retries then BLOCKER** -- don't keep retrying forever
6. **Stage specific files** -- never use `git add -A` or `git add .`
7. **Read scratchpad BEFORE implementing** -- scratchpad has dead-ends
   and decisions that prevent rework. Step 2 is not optional.
8. **Clarify ambiguous tasks** -- ask the user rather than guessing
   when a plan task's intent is unclear

## Step 1: Research Decision

Ask the user for plans with >3 tasks:

> This plan has {count} remaining tasks across {count} phases.
>
> 1. **Start working** -- Begin immediately (familiar patterns)
> 2. **Quick research** -- Read source files first (~10 min)
> 3. **Extensive research** -- Web search + docs (~30 min)

Skip for plans with 3 or fewer simple tasks -- just start.

> **Split warning**: Plans with >10 tasks risk 2-3 context
> compactions. Suggest splitting via ``elixir-phoenix-plan`` if not already.

## Step 2: Check Context (MANDATORY)

Read scratchpad and compound docs before writing any code.
Skipping this causes rework — scratchpad captures dead-ends
and decisions from planning that prevent taking wrong paths.

Read the scratchpad at `.draught/plans/{slug}/scratchpad.md` — it's short and has critical context.
Then search `.draught/solutions/` for relevant keywords using `rg` to find solved patterns.

Apply findings: skip dead-ends, follow decisions, reuse patterns.
Always ask the user when a task's intent is ambiguous —
never guess, corrections are expensive.

## Step 3: Load, Create Task List, and Resume

Read plan file, count `[x]` (completed) vs `[ ]` (remaining).
Find first unchecked task by `[Pn-Tm]` ID.

**Create Draught tasks** from ALL unchecked plan items using
`update_plan`. This gives real-time progress visibility in the UI:

For each unchecked `- [ ] [Pn-Tm] Description`, create a progress task with:
- title: `[Pn-Tm] Description`
- description: full task details from the plan
- active status text: `Implementing: Description`

Skip already-checked items (`[x]`) — don't create tasks for them.
Set up `blockedBy` dependencies between phases (Phase 2 tasks
blocked by Phase 1 tasks).

With `--from P2-T3`: Skip to that specific task.

See `references/resume-strategies.md` for all resume modes.

## Step 4: Execute Tasks

Execute each unchecked task (`- [ ] [Pn-Tm][agent] Description`):

1. **Start task**: mark the task as in progress in the progress tracker
2. **Route** by `[agent]` annotation (see `references/execution-guide.md`)
3. **Implement** the task
4. **Verify**: `mix format` + `mix compile --warnings-as-errors`
   (at phase end, also run `mix test <affected>` — see tiers below)
5. **Complete task**: Mark checkbox `[x]` on pass, **append
   implementation note** inline, and mark the task completed in the progress tracker. Example:
   `- [x] [P1-T3] Add user schema — citext for email, composite index on [user_id, status]`
   This survives context compaction; the plan is re-read on resume.
6. **On failure**: retry up to 3 times, then create BLOCKER
   and write DEAD-END to scratchpad (see error-recovery.md)

**Parallel groups**: Tasks under `### Parallel:` header spawn
as background subagents. See `references/execution-guide.md`
for spawning pattern, prompt template, and checkpoint flow.

**Verification tiers** (scoped to minimize redundant runs):

- Per-task: `mix compile --warnings-as-errors` only
  (format is checked by PostToolUse hook automatically)
- Per-phase: `mix compile --warnings-as-errors` + `mix test <affected_files>` + `mix credo --strict`
  (scope tests: `mix test test/path/to_affected_test.exs` — NOT full suite)
- Per-feature (Tidewave): behavioral smoke test via `project_eval`
  (create record, fetch, verify -- see execution-guide.md)
- Final gate: `mix test` (full suite — run ONCE at the end, not per-phase)

**Token efficiency**: Do NOT narrate each verification step. Execute
tool calls directly without "Let me now run..." preamble. Only narrate
when explaining a non-obvious decision or reporting a failure.

> **Linter note**: The PostToolUse hook checks formatting but does
> NOT modify files. Run `mix format` explicitly during verification
> steps or before committing.

## Step 5: Completion

Summarize results with `ask the user in chat`:

> Implementation complete! {done}/{total} tasks finished.
> {count} files modified across {count} phases.

Options: 1. **Run review** (``elixir-phoenix-review``) (Recommended),
2. **Get a briefing** (``elixir-phoenix-brief`` — understand what was built),
3. **Commit changes** (`/commit`), 4. **Continue manually**.

With blockers: list them, offer **Replan** (``elixir-phoenix-plan``),
**Review first** (``elixir-phoenix-review``), or **Handle myself**.

**If blockers remain**, auto-write HANDOFF to scratchpad:

```markdown
### [HH:MM] HANDOFF: {plan name}
Status: {done}/{total} tasks. Blockers: {list}.
Next: {first unchecked task ID and description}.
Key decisions: {brief list from this session}.
```

Include context beyond checkboxes for fresh session resume.

**NEVER** auto-start `elixir-phoenix-review` or any other phase.

## Step 6: Check for Additional Plans

Check for other pending plans after completion:

Search for other plan files matching `.draught/plans/*/plan.md`.

If pending plans exist, inform the user. Do NOT auto-start.

## Integration

```text
`elixir-phoenix-plan` → `elixir-phoenix-work` (YOU ARE HERE) → `elixir-phoenix-review` → `elixir-phoenix-compound`
                 ↑ ASK USER before each transition
```

## References

- `references/execution-guide.md` -- Task routing, parallel execution, verification
- `references/resume-strategies.md` -- Resume modes and state persistence
- `references/file-formats.md` -- Plan and progress file formats
- `references/error-recovery.md` -- Error handling and blockers
- `references/harness-patterns.md` -- Critic-refiner pattern for debugging loops

---
name: elixir-phoenix-help
description: 'Recommend the right `/skill elixir-phoenix-*` skill for the current task.'
metadata:
  short-description: 'Route to the right Phoenix skill'
---

# Plugin Help — Interactive Command Advisor

Helps users find the right command, skill, or agent for their situation.

## Usage

```
`/skill elixir-phoenix-help`                          # Analyze context, suggest commands
`/skill elixir-phoenix-help` how do I debug this?     # Route to `/skill elixir-phoenix-investigate`
`/skill elixir-phoenix-help` add a new feature        # Route to `/skill elixir-phoenix-plan` -> `/skill elixir-phoenix-work`
```

## Arguments

- `$ARGUMENTS` — optional description of what the user wants to do
- Empty = analyze current context (git status, existing plans, file patterns)

## Execution Flow

### Step 1: Gather Context

If `$ARGUMENTS` is non-empty, use it as primary signal.

Always gather ambient context (run in parallel):

1. Check for existing plans: use `rg --files` on `.draught/plans/*/plan.md` — active work in progress?
2. Check git status: uncommitted changes? which files?
3. Check for solution docs: use `rg --files` on `.draught/solutions/**/*.md` — prior knowledge?

### Step 2: Classify Intent

Read `references/tool-catalog.md` for the full routing table.

Map the user's situation to one of these categories:

| Category | Signals | Primary Commands |
|----------|---------|-----------------|
| **Starting out** | No plans, new to plugin | ``/skill elixir-phoenix-intro`` |
| **Ideation** | "explore", "brainstorm", "not sure", "how to approach", "vague idea" | ``/skill elixir-phoenix-brainstorm`` |
| **New feature** | "add", "build", "implement", multi-file | ``/skill elixir-phoenix-plan`` → ``/skill elixir-phoenix-work`` |
| **Quick change** | Single file, <50 lines, "fix typo" | ``/skill elixir-phoenix-quick`` |
| **Bug** | Error, stack trace, "broken", "failing" | ``/skill elixir-phoenix-investigate`` |
| **Review** | "check", "review", PR ready | ``/skill elixir-phoenix-review`` |
| **Runtime durability** | "race", "state machine", "retry semantics", "pause/resume", "restart safety", "durability", "Oban flow" | ``/skill elixir-phoenix-runtime-durability-review`` |
| **Performance** | "slow", "N+1", "memory" | ``/skill elixir-phoenix-perf``, ``/skill elixir-phoenix-n1-check``, ``/skill elixir-phoenix-assigns-audit`` |
| **Research** | "how to", "best practice", "evaluate lib" | ``/skill elixir-phoenix-research`` |
| **Resume work** | Existing plan with unchecked tasks | ``/skill elixir-phoenix-work` --continue` |
| **Post-fix** | "that worked", solved a hard bug | ``/skill elixir-phoenix-compound`` |
| **Full cycle** | Large feature, new domain area | ``/skill elixir-phoenix-full`` |
| **Project health** | "audit", "tech debt", "overall quality" | ``/skill elixir-phoenix-audit``, ``/skill elixir-phoenix-techdebt`` |
| **Deployment** | "deploy", "release", "production" | ``/skill elixir-phoenix-verify`` then deploy skill |
| **Permissions** | "too many prompts", "allow", "permission fatigue" | ``/skill elixir-phoenix-permissions`` |

### Step 3: Respond or Clarify

**If high confidence** (clear match to one category):
Present the recommendation with:

- The command to run (with exact syntax)
- One-line explanation of what it does
- What artifacts it creates (if any)
- Suggested next step after it completes

**If medium confidence** (2-3 possible matches):
Use `ask the user in chat` with the top options, each with a one-line explanation.

**If low confidence** (vague or no signal):
Ask ONE focused clarifying question. Examples:

- "Are you starting something new or continuing existing work?"
- "Is this a bug fix or a new feature?"
- "How many files do you expect to change?"

Then recommend based on the answer.

### Step 4: Offer Follow-up

After recommending, always add:

- "Run ``/skill elixir-phoenix-help`` anytime to get routing advice"
- If they seem new: "Try ``/skill elixir-phoenix-intro`` for a full plugin walkthrough"

## Iron Laws

1. **ONE recommendation** — don't dump the full catalog, pick the best match
2. **MAX ONE clarifying question** — don't interrogate, make your best guess
3. **Show exact syntax** — ``/skill elixir-phoenix-plan` Add user notifications` not just "use the plan command"
4. **Context over keywords** — existing plans + git state matter more than word matching
5. **Never block** — if user already knows what they want, don't redirect

## Integration

- Complements `intent-detection` (auto-trigger) with explicit invocation
- References same routing logic but adds interactive clarification
- Can recommend ``/skill elixir-phoenix-intro`` for onboarding

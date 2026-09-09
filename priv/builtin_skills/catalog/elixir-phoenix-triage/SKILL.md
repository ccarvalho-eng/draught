---
name: elixir-phoenix-triage
description: 'Triage review findings after `/skill elixir-phoenix-review` before fixing.'
metadata:
  short-description: 'Triage Phoenix review findings'
---

# Triage — Interactive Review Resolution

Walk through review findings one by one for human decision before
committing to fixes.

## Usage

```
`elixir-phoenix-triage` .draught/plans/user-auth/reviews/user-auth-review.md
`elixir-phoenix-triage`                  # Uses most recent review
```

## Why Triage

After ``elixir-phoenix-review`` produces findings, you have three options:

1. **Fix everything** — ``elixir-phoenix-plan` .draught/plans/{slug}/reviews/...`
2. **Triage first** — ``elixir-phoenix-triage`` (filter, then fix what matters)
3. **Handle manually** — Read review, pick what to fix yourself

Best when review has 5+ findings and you want to prioritize.

## Workflow

### Step 1: Load Review

Read the review file. Parse all findings with severity.

**Auto-approve Iron Law violations**: Findings matching the 13
Iron Laws are auto-approved as "Fix it" without asking. These
are non-negotiable in Elixir/Phoenix development.

### Step 2: Present ALL Findings for Batch Selection

Use `ask the user in chat` with `multiSelect: true`. Start with
severity shortcuts, then list individual findings:

```
ask the user in chat:
  question: "Which findings do you want to fix? (Iron Law violations auto-included)"
  header: "Triage"
  multiSelect: true
  options:
    - label: "All BLOCKERs ({count})"
      description: "Fix all critical issues"
    - label: "All WARNINGs ({count})"
      description: "Fix all should-fix issues"
    - label: "[BLOCKER] {title 1}"
      description: "{file}:{line} — {brief description}"
    - label: "[WARNING] {title 2}"
      description: "{file}:{line} — {brief description}"
```

If >4 options, batch into groups of 4 with severity shortcuts in
the first batch. Severity shortcuts select all findings of that
level — user can mix shortcuts with individual picks.

### Step 3: Gather Context on Selected Items

For selected items, ask ONE batch follow-up: "Any specific
approach for any of these?" If they say "just fix them", proceed.

### Step 4: Generate Triage Summary

Write to `.draught/plans/{slug}/reviews/{slug}-triage.md` with Fix Queue
(approved items with checkboxes), Skipped, and Deferred sections.

### Step 5: Present Next Steps

```
Triage complete: {n} to fix, {n} skipped, {n} deferred.

1. Plan fixes — `elixir-phoenix-plan` .draught/plans/{slug}/reviews/{slug}-triage.md
2. Fix directly — `elixir-phoenix-work` (for simple fixes)
3. Review deferred items later
4. Capture solutions — `elixir-phoenix-compound` (if patterns were solved)
```

## Iron Laws

1. **Batch selection over one-by-one** — Use multiSelect for efficiency
2. **User decides, not the agent** — Present facts, don't push
3. **BLOCKERs cannot be skipped silently** — Warn if user tries
4. **Capture user context** — Every "fix it" should include
   any user guidance for better fixes
5. **Suggest compound after triage** — If triage reveals solved patterns
   (root cause identified, fix known), mention ``elixir-phoenix-compound``
6. **NEVER auto-decide severity or auto-dismiss findings** — the human assigns final priority; present the agent's severity as a recommendation, not a verdict

## Integration with Workflow

```text
`elixir-phoenix-review`
       |
`elixir-phoenix-triage`  ← YOU ARE HERE (interactive filtering)
       |
`elixir-phoenix-plan` (with triage file) → `elixir-phoenix-work` → `elixir-phoenix-compound`
```

## References

- `references/triage-patterns.md` — Common triage decisions

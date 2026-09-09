---
name: elixir-phoenix-brainstorm
description: 'Brainstorm Phoenix features, tradeoffs, and requirements before planning.'
metadata:
  short-description: 'Brainstorm Phoenix features'
---

# Brainstorm — Adaptive Requirements Gathering

Interactive interview → research → synthesis loop. Produces structured
`interview.md` that ``elixir-phoenix-plan`` detects and consumes (skipping clarification).

## Usage

```text
`elixir-phoenix-brainstorm` Add some kind of notification system
`elixir-phoenix-brainstorm` Improve authentication security
`elixir-phoenix-brainstorm`                    # starts with open question
```

## Workflow

```
`elixir-phoenix-brainstorm` {topic}
    |
    v
[INTERVIEW] ←──────────────────┐
    |                           |
    v (sufficient OR user exit) |
[DECISION POINT]                |
    ├─ Research ──→ [RESEARCH] ─┘
    ├─ Continue interview ──────┘
    ├─ Make a plan ──→ STOP (suggest `elixir-phoenix-plan` {slug})
    ├─ Store & exit ──→ STOP (artifacts saved)
    └─ Discuss ──→ freeform ──→ [DECISION POINT]
```

## Phase 1: Adaptive Interview

Create `.draught/plans/{slug}/` directory. Start asking ONE question at a time.

### Coverage Dimensions

Track coverage across 6 dimensions (0=uncovered, 1=partial, 2=sufficient).
**Ask Scope early** — for "optimize X" topics, ask about boundaries (upstream
OK? Local-only? CI vs dev?) before research, not during.

| Dim | Target | Sufficient signal |
|-----|--------|-------------------|
| What | Specific behavior/features | Concrete verbs, not "some kind of" |
| Why | Problem solved, user need | Clear benefit stated |
| Scope | In/out boundaries | Explicit exclusions stated |
| Where | Modules, contexts, pages | File paths or context names mentioned |
| How | Approach, constraints | At least one concrete constraint |
| Edge | Error states, scale, auth | 2+ edge cases identified |

Interview is "sufficient" when total score >= 8 out of 12.

### Context-Aware Questioning

**Before each question**, run a brief codebase scan on topics the user mentioned:

1. User mentions a topic (e.g., "notifications") → run `rg` / `rg --files` for related patterns
2. Use scan results to ground your next question in what actually exists
3. Unknown/niche topic → suggest research pause before continuing

### Signal Detection

- **Vague answer** ("maybe", "not sure") → probe deeper on same dimension
- **Niche topic** mentioned → "This involves {X}. Want me to research it first?"
- **Detailed answer** covering 3+ dimensions → mark all covered, advance
- **No new coverage** for 2 consecutive questions → suggest moving to Decision Point

## Phase 2: Decision Point

**MANDATORY**: Write interview.md FIRST, then use ask the user in chat.
Never let the conversation flow past this point without a formal choice.

1. Write current state to `.draught/plans/{slug}/interview.md`
2. Show coverage summary: "Coverage: What 2/2 | Why 2/2 | Scope 1/2 | ..."
3. Use ask the user in chat with EXACTLY these options:

   - **Research** — search codebase + internet for approaches (2 agents)
   - **Continue interview** — ask more questions
   - **Make a plan** — I'll suggest: ``elixir-phoenix-plan` .draught/plans/{slug}/interview.md`
   - **Store & exit** — save everything, come back later
   - **Discuss** — freeform conversation about what we've gathered

4. Wait for user response. Do NOT proceed without explicit choice

## Phase 3: Research (Diverge → Evaluate → Converge)

**First cycle: MAX 2 agents** — keep it fast (~2-3 min). Spawn in one parallel batch:

- `phoenix-patterns-analyst`: "How does this codebase handle {topics}?"
  Write to `.draught/plans/{slug}/research/codebase-scan.md`
- `web-researcher`: "Elixir/Phoenix approaches to {topics}"
  Return 500-word summary

**Do NOT spawn additional specialist agents** in the first cycle.
If user wants deeper investigation, they pick "More research" at the
next Decision Point — then spawn focused agents for specific questions.

**Evaluate** — for each approach found:

- Thesis: why it works for THIS codebase
- Antithesis: why it might NOT work (scale, complexity, pattern conflicts)

**Converge** — present 2-3 approaches with honest trade-offs.
Do NOT recommend one. Return to Decision Point (ask the user in chat).

See `references/research-integration.md` for details.

## Iron Laws

1. **NEVER auto-transition** to ``elixir-phoenix-plan`` — always present as option, let user choose
2. **ONE question at a time** — never dump a question list
3. **Always write artifacts** — `interview.md` is the contract with ``elixir-phoenix-plan``
4. **Scan codebase between questions** — every question must be context-aware
5. **ask the user in chat at EVERY decision point** — never flow past without formal choice.
   This is the most critical law. After interview, after research, after discuss — ALWAYS
   present options via ask the user in chat. Never let conversation skip the checkpoint
6. **STOP after presenting options** — do not proceed without user input
7. **MAX 2 agents in first research cycle** — deeper dives are subsequent cycles.
   User picks "More research" to go deeper, not the skill

## Integration

```
`elixir-phoenix-brainstorm` ──→ interview.md ──→ `elixir-phoenix-plan` (skips clarification)
                                 ──→ `elixir-phoenix-plan` --existing (deepens)
                                 ──→ stored for later session
```

Position: optional upstream of ``elixir-phoenix-plan`` in workflow cycle.

## References

- `references/interview-techniques.md` — coverage scoring,
  question templates, scan patterns, signal detection, interview.md format
- `references/research-integration.md` — diverge-evaluate-converge,
  agent spawn templates, approach presentation format

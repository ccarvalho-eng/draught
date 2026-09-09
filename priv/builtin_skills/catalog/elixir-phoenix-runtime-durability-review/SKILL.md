---
name: elixir-phoenix-runtime-durability-review
description: 'Elixir/Phoenix: Review lifecycle, state-machine, Oban, persistence, pause/resume, retry, and restart-sensitive changes before commit, push, or PR. Use for concurrency-sensitive runtime work to produce explicit blocking vs optional findings, require durability checks, and verify smoke plus restart resilience when applicable.'
metadata:
  short-description: 'Elixir/Phoenix: Review lifecycle, state-machine, Oban, persistence, pause/resume, retry, and restart-sensitive changes before commit, push, or PR.'
---

# Runtime Durability Review

Use this skill for changes that touch state transitions, runtime orchestration, durable execution history, job dispatch, retries, manual intervention, or restart semantics.

## Required Output

- Produce an explicit findings list for the final diff, even if empty.
- Classify each finding as `blocking` or `optional`.
- Do not treat green tests as a substitute for the review.

## Review Checklist

### 1. Boundary Audit

- Confirm declarative workflow rules stay separate from runtime orchestration, persistence, and delivery adapters.
- Confirm side effects stay at boundaries and no new hidden coupling was introduced.
- Confirm public APIs return structured errors for stale, missing, or incompatible persisted state.

### 2. Concurrency And Locking

- Find every unlocked read that chooses a later mutation path.
- Eliminate it, revalidate it under the same lock, or prove it is safe by idempotent design.
- Check duplicate delivery, stale job, and terminal race behavior.
- Check `:noop` or already-terminal paths for stranded attempts, step runs, or partial state.

### 3. Atomic Progression

- Check whether update plus dispatch, update plus retry scheduling, and pause or resume flows are atomic where they need to be.
- Look for crash windows between durable state changes and enqueuing successor work.
- Verify dispatch-failure behavior preserves a coherent run and step history.

### 4. Persisted Data Drift

- Check whether paused, retrying, delayed, or replayable runs depend on the current code definition when they should depend on persisted decisions.
- Check renamed or removed modules, changed transitions, changed mappings, and older rows missing newer fields.
- Prefer durable metadata plus compatibility fallbacks over recomputing semantics from the live definition.

### 5. Telemetry And Audit Ordering

- Check ordering between step terminal events, run transitions, and successor dispatch or start.
- Check that every started step has a matching terminal audit or telemetry event.
- Check cancelled, retried, resumed, and dispatch-failure paths for symmetry.

### 6. Regression Expectations

- Add at least one regression per meaningful failure mode discovered in the review.
- Prefer direct regressions for stale-read races, terminal no-op cleanup, persisted-data drift, and dispatch atomicity.
- If a regression is not practical, write down why.

### 7. Executable Verification

- Run formatter and relevant automated tests.
- Run a real smoke path on the nearest executable integration surface.
- If the repo has a sample or host app, use it as the primary end-to-end path.
- If the feature changes restart or durability guarantees, run a restart or resilience verification path too.
- Only fall back to `iex` or a temporary `/tmp` harness when a real app surface is not practical.

## Minimum Questions To Answer

- Can a crash or restart leave durable state ahead of queued work?
- Can a stale caller or duplicate delivery corrupt history or context?
- Can deploy-time code changes alter the meaning of already-persisted runs?
- Are terminal and already-finalized paths cleaning up in-flight state correctly?
- Does the read model still tell the truth after retries, cancellation, pause, resume, and failure?

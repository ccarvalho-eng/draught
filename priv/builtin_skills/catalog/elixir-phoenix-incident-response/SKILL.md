---
name: elixir-phoenix-incident-response
description: 'Handle Phoenix production incidents: triage, stabilize, narrow root cause, hotfix safely.'
metadata:
  short-description: 'Handle Phoenix production incidents'
---

# Incident Response

Use when production is degraded, error rate spikes, or critical user flows fail.

## Primary Goal

Restore service safely first, then deepen diagnosis.

## Iron Laws

1. Stabilization first, optimization second.
2. Never apply irreversible changes without an explicit rollback option.
3. Keep a timestamped incident log of actions and outcomes.
4. One operator executes, one validates when possible.
5. Communicate status with clear ETAs and unknowns.

## Triage Flow

### Step 1: Confirm Scope

- What is broken (endpoint, job queue, LiveView path)?
- Severity (full outage, partial, degraded)?
- Start time and suspected trigger (deploy, migration, traffic spike)?

### Step 2: Stabilize

Pick the lowest-risk stabilization path:
- Roll back recent deploy
- Disable failing feature path
- Pause problematic jobs/queues
- Reduce blast radius using feature flags or routing controls

### Step 3: Narrow Root Cause

Gather:
- Error signatures and frequency
- Recent code/config changes
- Data-layer symptoms (timeouts, lock contention, deadlocks)
- Runtime symptoms (process crashes, mailbox growth, scheduler pressure)

### Step 4: Hotfix Decision

Ship a hotfix only if:
- Scope is confirmed
- Fix is minimal and reversible
- Validation target is explicit

## Output Expectations

Provide:
- Current severity and impacted surface
- Stabilization actions taken
- Most likely root-cause hypotheses
- Recommended next action (rollback, hotfix, deeper investigation)

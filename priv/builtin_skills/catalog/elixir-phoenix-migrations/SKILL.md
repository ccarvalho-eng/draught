---
name: elixir-phoenix-migrations
description: 'Plan Ecto and Postgres migrations with additive, backfill-safe rollouts.'
metadata:
  short-description: 'Plan safe Ecto/Postgres migrations'
---

# Ecto Migration Safety Workflow

Use when schema changes touch production data or availability. This skill optimizes for reversible, staged rollouts.

## When to Use

- Adding columns or indexes on large tables
- Renaming or changing field types
- Backfilling derived data
- Splitting one migration into deploy-safe phases
- Planning rollback behavior before release

## Iron Laws

1. Never ship destructive schema changes in the same release as new app code that depends on them.
2. Prefer additive migrations first, then code switch, then cleanup migration.
3. Every data backfill must be resumable and idempotent.
4. Validate expected locks and runtime impact before merge.
5. Define rollback/forward-fix strategy before running in production.

## Workflow

### Step 1: Classify the Change

Mark the request as:
- Additive: safe in one step (new nullable column, concurrent index)
- Transitional: requires staged deploy (rename/type change)
- Destructive: requires explicit cleanup phase and rollback plan

### Step 2: Generate Migration Plan

For transitional/destructive work, create a phased sequence:
1. Migration A: additive schema only
2. Application update: read/write both shapes when needed
3. Backfill job or migration-safe data movement
4. Migration B: constraints and cleanup after cutover

### Step 3: Validate SQL Risk

Check for:
- Full-table rewrites
- Blocking index operations (prefer concurrent when supported)
- Constraint validation timing
- Lock-sensitive operations during peak traffic

### Step 4: Define Runtime Execution

Specify:
- Order of deploy vs migration steps
- Backfill execution command and progress signal
- Rollback path (and whether rollback is data-safe)

## Output Expectations

Return:
- Exact migration sequence by phase
- Commands to run in each phase
- Risk notes and mitigations
- Rollback/forward-fix strategy

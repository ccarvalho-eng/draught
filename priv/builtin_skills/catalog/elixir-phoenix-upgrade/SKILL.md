---
name: elixir-phoenix-upgrade
description: 'Plan and execute Phoenix dependency upgrades safely.'
metadata:
  short-description: 'Plan safe Phoenix upgrades'
---

# Upgrade Workflow

Use when upgrading Elixir, OTP, Phoenix, Ecto, LiveView, or critical library dependencies.

## Iron Laws

1. Upgrade in small phases, not one giant jump.
2. Read official migration guides before changing code.
3. Separate dependency bump commits from behavior refactors.
4. Deprecation warnings are treated as required follow-up.
5. Keep a rollback point after each phase.

## Upgrade Sequence

### Step 1: Baseline

- Record current versions (`mix deps`, runtime versions, lockfile state)
- Run baseline verification (`mix compile`, tests, lints)
- Capture known failing checks before upgrades

### Step 2: Plan Phases

Order upgrades from foundation to framework:
1. Elixir/OTP runtime
2. Core framework libs (Phoenix/Ecto/LiveView)
3. Peripheral dependencies

### Step 3: Execute Per Phase

For each phase:
- Update version constraints
- Refresh dependencies
- Apply required migration guide changes
- Run compile and targeted tests
- Commit if green

### Step 4: Final Compatibility Pass

- Run full verification pipeline
- Address deprecations and behavior changes
- Confirm deployment/runtime config expectations

## Output Expectations

Provide:
- Upgrade phase plan
- Breaking changes and required code adjustments
- Verification status by phase
- Remaining risks and rollback guidance

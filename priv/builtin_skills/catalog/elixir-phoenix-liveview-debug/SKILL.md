---
name: elixir-phoenix-liveview-debug
description: 'Debug LiveView events, assigns, reconnects, and render behavior.'
metadata:
  short-description: 'Debug LiveView lifecycle issues'
---

# LiveView Debugging

Use for hard LiveView bugs: state drift, duplicate events, slow renders, reconnect inconsistencies, and stream misuse.

## Iron Laws

1. Reproduce first with exact event sequence and params.
2. Track assign ownership by callback boundary (`mount`, `handle_params`, `handle_event`, `handle_info`).
3. Verify streams for large collections before introducing list assigns.
4. Distinguish transport issues from domain-state issues.
5. Fix root cause, not only UI symptom.

## Debug Workflow

### Step 1: Build Reproduction Timeline

Capture:
- Initial mount conditions
- URL/param transitions
- User events and payloads
- Incoming PubSub/info messages
- Reconnect behavior

### Step 2: Verify State Transitions

Map each callback to:
- Inputs it consumes
- Assigns it mutates
- Side effects it triggers

Look for stale assigns, overwritten state, and event-order assumptions.

### Step 3: Collection and Render Checks

Audit:
- Large list assigns that should be streams
- Unbounded assign growth
- Repeated expensive computations on every render
- Temporary assigns where applicable

### Step 4: Resolution Pattern

Apply the smallest safe fix:
- Move state to the correct callback boundary
- Use streams for collection updates
- Isolate side effects from render flow
- Add regression test for the exact failure timeline

## Output Expectations

Return:
- Reproduction timeline
- Root-cause callback/state mismatch
- Concrete patch strategy
- Regression test scope

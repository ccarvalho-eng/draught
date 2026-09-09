---
name: elixir-phoenix-observability
description: 'Set up or review Phoenix telemetry, metrics, traces, logs, and alerts.'
metadata:
  short-description: 'Review Phoenix telemetry and alerts'
---

# Observability

Use when the user needs measurable system health and faster debugging in production.

## When to Use

- Adding or auditing Telemetry instrumentation
- Defining service-level indicators and alerts
- Wiring OpenTelemetry traces across Phoenix/Ecto/Oban
- Improving log correlation for incidents
- Building dashboards for latency, throughput, and errors

## Iron Laws

1. Instrument user-impacting flows before adding low-value metrics.
2. Every alert must map to an explicit operator action.
3. Logs must be structured and scrubbed for secrets.
4. Trace/span names must be stable and domain-oriented.
5. Prefer a small reliable metric set over noisy dashboards.

## Workflow

### Step 1: Define Signals

For each critical flow, define:
- Latency (p50/p95/p99)
- Throughput (requests/jobs per minute)
- Error rate (and top failure classes)
- Saturation indicators (DB pool, queue depth, scheduler pressure)

### Step 2: Instrument

Verify or add:
- Telemetry events at Phoenix and domain boundaries
- Ecto query timing visibility
- Oban queue and failure metrics
- End-to-end trace propagation where available

### Step 3: Correlate

Ensure shared IDs across logs/metrics/traces for the same request or job.

### Step 4: Alert and Dashboard

Create:
- Actionable alerts on user-facing SLO breaches
- Dashboard sections by surface (HTTP, LiveView, DB, jobs)
- Runbook pointers for each alert condition

## Output Expectations

Return:
- Missing instrumentation by flow
- Proposed metrics and alert thresholds
- Dashboard layout recommendation
- Explicit implementation order

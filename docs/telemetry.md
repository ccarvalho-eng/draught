# Telemetry

Draught emits lifecycle events through `:telemetry`. It does not configure a reporter, exporter, metrics backend, logger, dashboard, or alert.

## Event contract

All event names are available through `Draught.Telemetry.events/0`. A domain-specific subset is available through `Draught.Telemetry.events/1`.

| Domain | Start | Stop | Exception |
| --- | --- | --- | --- |
| Session turn | `[:draught, :session, :turn, :start]` | `[:draught, :session, :turn, :stop]` | `[:draught, :session, :turn, :exception]` |
| Provider request | `[:draught, :provider, :request, :start]` | `[:draught, :provider, :request, :stop]` | `[:draught, :provider, :request, :exception]` |
| Tool execution | `[:draught, :tool, :execution, :start]` | `[:draught, :tool, :execution, :stop]` | `[:draught, :tool, :execution, :exception]` |

Session spans begin after a turn is accepted. They stop after any configured terminal journal record is persisted and before the outcome is delivered to the subscriber. Cancellation, timeout, normalized failures, and unexpected runner termination stop the span with an error outcome. An abnormal session-process termination emits an exception event for an active span.

Provider spans cover capability discovery, completion, and streaming calls at the provider facade. Tool spans cover validation, authorization, and execution at the public tool facade. Unexpected throws, exits, and errors emit an exception event and are re-raised without alteration. Each span is monitored independently, so forcefully terminating its owner also produces one sanitized exception completion.

## Measurements

| Event suffix | Measurements |
| --- | --- |
| `:start` | `system_time` in the native system time unit |
| `:stop` | `duration` in the native monotonic time unit and `count: 1` |
| `:exception` | `duration` in the native monotonic time unit and `count: 1` |

Provider and session stop events also contain `input_tokens`, `output_tokens`, `total_tokens`, `cached_tokens`, and `reasoning_tokens`. Missing usage is represented by zeroes. Token and count values are capped at `Draught.Telemetry.maximum_count/0`. Durations are clamped to a non-negative value with a 24-hour upper bound.

## Metadata

Metadata is projected through a closed allowlist:

| Domain and suffix | Metadata |
| --- | --- |
| Provider start | `operation` |
| Provider stop | `operation`, `outcome`, `error_kind` |
| Provider exception | `operation`, `outcome`, `exception_kind` |
| Tool start | Empty map |
| Tool stop | `outcome`, `error_kind` |
| Tool exception | `outcome`, `exception_kind` |
| Session start | Empty map |
| Session stop | `outcome`, `error_kind` |
| Session exception | `outcome`, `exception_kind` |

`operation` is one of `:capabilities`, `:complete`, or `:stream`. `outcome` is `:ok`, `:error`, or `:exception`. `error_kind` is a canonical normalized-error category, `:validation`, or `nil`. `exception_kind` is `:error`, `:exit`, or `:throw`.

Prompts, responses, reasoning, file contents, command output, tool names, tool call identifiers, tool arguments, provider configuration, model identifiers, URLs, credentials, exception reasons, stack traces, and session identifiers are not telemetry measurements or metadata.

## Deterministic capture

`Draught.Telemetry.Capture` provides an isolated handler identifier and a stable message shape for tests:

```elixir
{:ok, token} =
  Draught.Telemetry.Capture.attach(
    self(),
    Draught.Telemetry.events(:provider)
  )

result = Draught.Provider.complete(provider, request)

assert_receive {
  Draught.Telemetry.Capture,
  ^token,
  [:draught, :provider, :request, :start],
  measurements,
  metadata
}

:ok = Draught.Telemetry.Capture.detach(token)
```

Telemetry handlers are global to the BEAM. Tests that capture broad event sets should avoid running concurrently with unrelated instrumented work.

## Consumer configuration

Consumers may attach any compatible reporter or OpenTelemetry bridge to the documented events. Reporter configuration belongs to the host application. Metadata values are intentionally low-cardinality; content-bearing correlation belongs in an explicitly protected application channel rather than metric tags.

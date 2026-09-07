# Draught

[![CI](https://github.com/ccarvalho-eng/draught/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/ccarvalho-eng/draught/actions/workflows/ci.yml)
[![License: Apache-2.0](https://img.shields.io/badge/license-Apache--2.0-blue.svg)](https://github.com/ccarvalho-eng/draught/blob/main/LICENSE)
[![Elixir: 1.18+](https://img.shields.io/badge/Elixir-1.18%2B-4B275F.svg)](mix.exs)
[![Project status: pre-alpha](https://img.shields.io/badge/status-pre--alpha-orange.svg)](https://github.com/ccarvalho-eng/draught/milestones)

Draught is a provider-neutral coding-agent runtime and CLI for Elixir and the BEAM.

The project is in pre-alpha development. Provider integrations, tool contracts, standard coding tools, approval policy, workspace confinement, bounded runner coordination, supervised session lifecycles, local journals, and sanitized telemetry are implemented. The remaining public-alpha scope includes the CLI, web access, and distribution.

## Design constraints

| Concern | Constraint |
| --- | --- |
| Setup | The first-run path must not require knowledge of OTP, provider internals, or system dependency management. |
| Provider integration | Providers and clients exchange Draught contracts instead of vendor payloads. |
| Runtime design | Domain values and transitions are pure. Processes are limited to state, concurrency, isolation, cancellation, or resource ownership. |
| Authorization | Tool access, web access, budgets, timeouts, and mutations are explicit capabilities enforced independently of model output. |
| Observability | Telemetry excludes credentials, message content, and raw provider values. Content-bearing events are handled by explicit CLI and journal policies. |

## Project status

| Area | Status |
| --- | --- |
| Project foundation and quality gates | Complete |
| Canonical provider-neutral contracts | Complete |
| OpenAI-compatible and Ollama providers | Complete |
| Tool registry, execution contract, and standard coding tools | Complete |
| Approval policy and workspace confinement | Complete |
| Bounded agent runner | Complete |
| Supervised session lifecycle | Complete |
| Versioned local journals and replay | Complete |
| Privacy-safe telemetry | Complete |
| Agentic CLI and one-command distribution | Planned |

The [GitHub milestones](https://github.com/ccarvalho-eng/draught/milestones) are the authoritative implementation roadmap. APIs may change before the first tagged alpha.

## Provider contracts

Draught keeps conversations and providers independent. Applications construct canonical messages and requests, then inject an adapter explicitly:

```elixir
{:ok, user} = Draught.Conversation.user("Explain this project")
{:ok, request} = Draught.Provider.Request.new(model: "local-model", messages: [user])
{:ok, assistant} = Draught.Conversation.assistant(content: "A provider-neutral agent runtime.")
{:ok, response} = Draught.Provider.Response.new(message: assistant, finish_reason: :stop)

{:ok, fake} =
  Draught.Provider.Fake.new(
    completions: [%{request: request, response: response}]
  )

Draught.Provider.complete({Draught.Provider.Fake, fake}, request)
# => {:ok, response}
```

The included fake is pure and route-based. It provides deterministic offline tests without processes, global configuration, or network access.

## Documentation

- [Architecture](docs/architecture.md)
  - [Internal layers](docs/architecture.md#internal-layers)
  - [Agent execution](docs/architecture.md#agent-execution)
  - [Provider boundary](docs/architecture.md#provider-boundary)
  - [Contracts and trust boundaries](docs/architecture.md#contracts-and-trust-boundaries)
  - [Web access and indirect prompt injection](docs/architecture.md#web-access-and-indirect-prompt-injection)
  - [State and durability](docs/architecture.md#state-and-durability)
  - [API and dependency rules](docs/architecture.md#api-and-dependency-rules)
  - [Delivery status](docs/architecture.md#delivery-status)
- [Ollama provider](docs/providers/ollama.md)
  - [Construction](docs/providers/ollama.md#construction)
  - [Configuration](docs/providers/ollama.md#configuration)
  - [Failures](docs/providers/ollama.md#failures)
  - [Manual smoke procedure](docs/providers/ollama.md#manual-smoke-procedure)
- [Tool execution](docs/tools.md)
  - [Definition and registry](docs/tools.md#definition-and-registry)
  - [Invocation](docs/tools.md#invocation)
  - [Standard tools](docs/tools.md#standard-tools)
  - [Command process boundary](docs/tools.md#command-process-boundary)
  - [Parameter schema subset](docs/tools.md#parameter-schema-subset)
  - [Executor boundary](docs/tools.md#executor-boundary)
- [Agent runner](docs/runner.md)
  - [Configuration](docs/runner.md#configuration)
  - [Execution sequence](docs/runner.md#execution-sequence)
  - [Limits and terminal conditions](docs/runner.md#limits-and-terminal-conditions)
  - [Events](docs/runner.md#events)
- [Session lifecycle](docs/sessions.md)
  - [Lifecycle API](docs/sessions.md#lifecycle-api)
  - [Events](docs/sessions.md#events)
  - [Cancellation and timeout rules](docs/sessions.md#cancellation-and-timeout-rules)
  - [Runtime sequence](docs/sessions.md#runtime-sequence)
- [Session journals](docs/session-journals.md)
  - [Record contract](docs/session-journals.md#record-contract)
  - [Replay](docs/session-journals.md#replay)
  - [Retention](docs/session-journals.md#retention)
  - [Checkpoints](docs/session-journals.md#checkpoints)
  - [Custom adapters](docs/session-journals.md#custom-adapters)
- [Telemetry](docs/telemetry.md)
  - [Event contract](docs/telemetry.md#event-contract)
  - [Measurements](docs/telemetry.md#measurements)
  - [Metadata](docs/telemetry.md#metadata)
  - [Deterministic capture](docs/telemetry.md#deterministic-capture)
  - [Consumer configuration](docs/telemetry.md#consumer-configuration)
- [Workspace confinement](docs/workspace-confinement.md)
  - [Resolution contract](docs/workspace-confinement.md#resolution-contract)
  - [Read and write paths](docs/workspace-confinement.md#read-and-write-paths)
  - [Managed names](docs/workspace-confinement.md#managed-names)

## Security

Draught treats model output and external content as untrusted. Provider responses do not grant tool permissions; every action remains subject to typed argument validation, capability checks, risk policy, budgets, timeouts, workspace rules, and user approval.

Web access will be disabled by default and explicitly configurable. Search results and fetched pages will retain provenance and remain untrusted data, with bounded content handling and network controls. See the [security policy](SECURITY.md) for the trust model and vulnerability reporting process.

## Development

Install dependencies:

```sh
mix setup
```

Run the development quality gate:

```sh
mix quality
```

Run the complete pre-commit gate:

```sh
mix precommit
```

The pre-commit gate runs formatting, warnings, dependency hygiene, compile-cycle detection, every compatible Credo and ExSlop check, zero-clone ExDNA analysis, strict Reach smells, tests and coverage, Dialyzer, documentation coverage, HexDocs generation, and package assembly.

## Contributing

Read [CONTRIBUTING.md](CONTRIBUTING.md) for the development workflow and enforced quality standards.

## License

Draught is available under the [Apache License 2.0](https://github.com/ccarvalho-eng/draught/blob/main/LICENSE).

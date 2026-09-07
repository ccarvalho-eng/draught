# Draught

[![CI](https://github.com/ccarvalho-eng/draught/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/ccarvalho-eng/draught/actions/workflows/ci.yml)
[![License: Apache-2.0](https://img.shields.io/badge/license-Apache--2.0-blue.svg)](https://github.com/ccarvalho-eng/draught/blob/main/LICENSE)
[![Elixir: 1.18+](https://img.shields.io/badge/Elixir-1.18%2B-4B275F.svg)](mix.exs)
[![Project status: pre-alpha](https://img.shields.io/badge/status-pre--alpha-orange.svg)](https://github.com/ccarvalho-eng/draught/milestones)

Draught is a provider-neutral coding-agent runtime and CLI for Elixir and the BEAM.

The project is in pre-alpha development. Provider integrations, tool contracts, standard coding tools, approval policy, workspace confinement, bounded runner coordination, and supervised session lifecycles are implemented. The remaining public-alpha scope includes journaling, telemetry, the CLI, web access, and distribution.

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
| Durable journals and telemetry | Planned |
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

The [Ollama provider guide](docs/providers/ollama.md) documents model selection, capability checks, configuration, failures, and the manual smoke procedure.

The [tool execution guide](docs/tools.md) documents the standard catalog, definitions, registry lookup, risk and approval policy, parameter schemas, mutation sequencing, command process controls, structured results, and the executor boundary.

The [agent runner guide](docs/runner.md) documents injected dependencies, pure state transitions, execution order, limits, recoverable tool results, terminal conditions, and synchronous events.

The [session lifecycle guide](docs/sessions.md) documents asynchronous turns, status, event delivery, cancellation semantics, timeouts, supervision, and stale-result handling.

The [workspace confinement guide](docs/workspace-confinement.md) documents lexical validation, symlink handling, read and write resolution, containment checks, and operating-system isolation boundaries.

See the [architecture guide](docs/architecture.md) for the internal layers, dependency rules, runtime flows, effect boundaries, and contract invariants.

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
